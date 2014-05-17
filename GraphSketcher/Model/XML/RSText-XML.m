// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSText-XML.h"

RCS_ID("$Header$");

#import <OmniFoundation/OFXMLCursor.h>

#import "OSStyledTextStorage-XML.h"
#import "NSAttributedString-OSExtensions.h"

@implementation RSText (XML)

- initWithXML:(OFXMLCursor *)cursor baseStyle:(OSStyle *)baseStyle;
{
    self = [super init];
    if (!self)
        return nil;
    
    if ([cursor openNextChildElementNamed:OSStyledTextStorageXMLElementName]) {
	_attributedString = [[NSMutableAttributedString alloc] initFromXML:cursor baseStyle:baseStyle];
	OBASSERT(_attributedString);
	if (!_attributedString)
	    _attributedString = [[NSMutableAttributedString alloc] init];
        
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        // Hack to fix underline color (OmniStyle sets it to black)
        [_attributedString removeAttribute:NSUnderlineColorAttributeName range:NSMakeRange(0, [_attributedString length])];
#endif
	
	[cursor closeElement];
    }
    else {
	_attributedString = [[NSMutableAttributedString alloc] initWithString:@"[Unknown]"];
    }
    
    _cachedSize = CGSizeZero;
    
    return self;
}

- (void)appendXML:(OFXMLDocument *)doc baseStyle:(OSStyle *)baseStyle;
{
    [_attributedString appendXML:doc baseStyle:baseStyle ];
    
//    BOOL found = [[_attributedString description] rangeOfString:@"Georgia"].length > 0;
//    if (found) {
//        NSLog(@"baseStyle: %@", baseStyle);
//        NSLog(@"attributes: %@", [_attributedString attributesAtIndex:0 effectiveRange:NULL]);
//    }
}

@end
