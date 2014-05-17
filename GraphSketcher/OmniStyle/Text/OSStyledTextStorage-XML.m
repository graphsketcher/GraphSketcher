// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSStyledTextStorage-XML.h"

#import <OmniAppKit/NSAttributedString-OAExtensions.h>
#import <OmniAppKit/OATextAttributes.h>
#import <OmniFoundation/NSMutableAttributedString-OFExtensions.h>
#import <OmniFoundation/NSRegularExpression-OFExtensions.h>
#import <OmniFoundation/NSString-OFReplacement.h>
#import <OmniFoundation/OFRegularExpressionMatch.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/OFXMLQName.h>
#import <OmniFoundation/OFXMLReader.h>
#import <OmniFoundation/OFXMLString.h>
#import <OmniAppKit/OATextAttributes.h>

RCS_ID("$Header$");

NSString * const OSStyledTextStorageXMLElementName = @"text";

NSString * const OSStyledTextStorageParagraphXMLElementName = @"p";
NSString * const OSStyledTextStorageRunXMLElementName = @"run";
NSString * const OSStyledTextStorageLiteralStringXMLElementName = @"lit";

NSString * const OSStyleXMLElemementName = @"style";
NSString * const OSStyleAttributeValueXMLElemementName = @"value";
NSString * const OSStyleAttributeKeyXMLAttributeName = @"key";

#pragma mark - Text appending

static NSUInteger OSStyledTextStorageAppendRunWithApplier(OFXMLDocument *doc, NSString *string, OSStyledTextStorageAppendTextCallbacks callbacks,
                                                          id styleToWrite, NSRange effectiveRange, NSUInteger contentsEnd, id attachment,
                                                          void *context)
{
    
    // NOTE: This will end up writing cells in their own <run> -- we'd like to merge the <run> for a cell into its neighboring <run>s if possible.
    [doc pushElement:OSStyledTextStorageRunXMLElementName];
    OFXMLElement *runElement = [doc topElement];
    [runElement setIgnoreUnlessReferenced:YES];

    CFStringRef substring = NULL;
    do {
        // Don't write the string for the 'newline' portion, only the 'real' characters.
        NSRange stringRange = effectiveRange;
        if (stringRange.location + stringRange.length > contentsEnd)
            stringRange.length = contentsEnd - stringRange.location;
        if (stringRange.length) {
            // Avoid the autorelease since this happens a bunch
            substring = CFStringCreateWithSubstring(kCFAllocatorDefault, (CFStringRef)string, (CFRange){stringRange.location, stringRange.length});
        }

        if (styleToWrite) {
            // We no longer replace text ranges with links with attachments. So, for backwards compatibility, we have to check for links.
            // This means that the OO3 <text> element can't support a linked range that contains an image.
            // OmniFocus added a new style attribute "link", but OO3 doesn't understand that.
            // We allow appendRunStyle to return a flag saying that it handled everything. Our OSStyledTextStorage writer uses this to write a <cell> for the link.
            OSStyledTextStorageAppendRunStyleResult runStyleResult = callbacks.appendRunStyle(doc, styleToWrite, (NSString *)substring, (attachment != nil), context);
            [runElement markAsReferenced];
            
            if (runStyleResult == OSStyledTextStorageAppendRunStyleSkipWritingText)
                break;
        }
        
        OBASSERT(attachment == nil);
        if (substring) {
            [doc appendElement:OSStyledTextStorageLiteralStringXMLElementName containingString:(NSString *)substring];
            [runElement markAsReferenced];
        }
    } while (0);
    if (substring)
        CFRelease(substring);

    [doc popElement]; // <run>
    
    return effectiveRange.location + effectiveRange.length;
}

// Writes the styles and characters for a single paragraph of text.  See the DTD for some more comments on this, but care needs to be taken when dealing with the style of the area between paragraphs.  This style is important when editing the text  (since placing the cursor after the newline will take on the style of the newline, not the style of the previous character, I think) and for ensuring that we maintain full-range text attributes when they really are full-range.  Thus, we write an empty <style> for the break if it differs from the last character of the paragraph.
static void _appendRuns(OFXMLDocument *doc, NSString *string, NSUInteger lineStart, NSUInteger lineEnd, NSUInteger contentsEnd, OSStyledTextStorageAppendTextCallbacks callbacks, void *context)
{
    /*
     In <bug://bugs/42130> (Crash clipping from Mail when selection starts with a blank line), the input string was something
     like @"\r\r\nxxxx\n" with a two different styles across the 2nd newline (which is formed of two characters, a \r and \n).
     This meant we'd get an effective range for the \r and then one for the \n, but our code below to adjust to only write
     out the non-newline characters would then underflow the length to -1, causing a crash.
     
     So, we only loop until contentsEnd now, instead of lineEnd.  We may still need to do the range adjustment below
     since we pass lineEnd as the end of the inRange: parameter below, though we could maybe avoid the need for that
     by using contentsEnd there too.
     
     */
    
    NSUInteger location = lineStart;    
    while (location < contentsEnd) {
        // Fill with default values
        NSRange effectiveRange = NSMakeRange(location, contentsEnd - location);
        id attachment = nil;
        id styleToWrite = nil;
        
        if (callbacks.findStyleEffectiveRangeAtLocation)
            callbacks.findStyleEffectiveRangeAtLocation(doc, string, location, lineStart, lineEnd, contentsEnd, &effectiveRange, &styleToWrite, &attachment, context);

        location = OSStyledTextStorageAppendRunWithApplier(doc, string, callbacks,
                                                           styleToWrite, effectiveRange, contentsEnd, attachment,
                                                           context);
    }
    
}

void OSStyledTextStorageAppendTextWithApplier(OFXMLDocument *doc, NSString *string, OSStyledTextStorageAppendTextCallbacks callbacks, void *context)
{
    NSUInteger length = [string length];
    
    [doc pushElement:OSStyledTextStorageXMLElementName];
    {
        NSUInteger location = 0;
        
        // Break into paragraphs.  Line separators are considered separators between paragraphs.  This means that "" is a paragraph and "\n" is two paragraphs, for example.  See -[OSStyledTextStorageTests testParagraphBreaking] for some examples.
        while (YES) {
            NSUInteger lineStart, lineEnd, contentsEnd;
            
            if (location < length) {
                [string getLineStart:&lineStart end:&lineEnd contentsEnd:&contentsEnd forRange:(NSRange){location,1}];
            } else {
                // Handle the case where we ended in a line break.
                lineStart = location;
                lineEnd = location;
                contentsEnd = location;
            }
            
            [doc pushElement:OSStyledTextStorageParagraphXMLElementName]; {
                if (callbacks.beginParagraph)
                    callbacks.beginParagraph(doc, string, lineStart, lineEnd, contentsEnd, context);
                
                _appendRuns(doc, string, lineStart, lineEnd, contentsEnd, callbacks, context);
                
                if (callbacks.endParagraph)
                    callbacks.endParagraph(doc, string, lineStart, lineEnd, contentsEnd, context);
            } [doc popElement];
            
            if (contentsEnd == length)
                break;
            location = lineEnd;
        }
    }
    
    if (callbacks.textEndApplier)
        callbacks.textEndApplier(doc, string, context);
    
    [doc popElement];
}
