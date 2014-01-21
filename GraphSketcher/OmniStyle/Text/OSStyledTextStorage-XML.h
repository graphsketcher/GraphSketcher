// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Text/OSStyledTextStorage-XML.h 200244 2013-12-10 00:11:55Z correia $

// Some basic utilities that don't require all of AppKit.  This can be used on the phone.
#import <OmniBase/objc.h>

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

@class OFXMLElement;

extern NSString * const OSStyledTextStorageXMLElementName;

extern NSString * const OSStyledTextStorageParagraphXMLElementName;
extern NSString * const OSStyledTextStorageRunXMLElementName;
extern NSString * const OSStyledTextStorageLiteralStringXMLElementName;

extern NSString * const OSStyleXMLElemementName;
extern NSString * const OSStyleAttributeValueXMLElemementName;
extern NSString * const OSStyleAttributeKeyXMLAttributeName;

@class OFXMLDocument, OFXMLElement;

typedef enum {
    OSStyledTextStorageAppendRunStyleContinue, // The text for the style should be written as normal
    OSStyledTextStorageAppendRunStyleSkipWritingText, // The style writing handled the text itself.
} OSStyledTextStorageAppendRunStyleResult;

typedef struct {
    void (*beginParagraph)(OFXMLDocument *doc, NSString *string, NSUInteger lineStart, NSUInteger lineEnd, NSUInteger contentsEnd, void *context);

    void (*findStyleEffectiveRangeAtLocation)(OFXMLDocument *doc, NSString *string, NSUInteger location, NSUInteger lineStart, NSUInteger lineEnd, NSUInteger contentsEnd,
                                                                          NSRange *outEffectiveRange, id *outStyleToWrite, id *outAttachment,
                                                                          void *context);
    
    OSStyledTextStorageAppendRunStyleResult (*appendRunStyle)(OFXMLDocument *doc, id style, NSString *forString, BOOL hasAttachment, void *context);
    void (*endParagraph)(OFXMLDocument *doc, NSString *string, NSUInteger lineStart, NSUInteger lineEnd, NSUInteger contentsEnd, void *context);
    void (*textEndApplier)(OFXMLDocument *doc, NSString *string, void *context);
} OSStyledTextStorageAppendTextCallbacks;
    
extern void OSStyledTextStorageAppendTextWithApplier(OFXMLDocument *doc, NSString *string, OSStyledTextStorageAppendTextCallbacks callbacks, void *context);
