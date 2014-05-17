// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSText.h"

@class OFXMLCursor, OFXMLDocument;
@class OSStyle;

@interface RSText (XML)
- initWithXML:(OFXMLCursor *)cursor baseStyle:(OSStyle *)baseStyle;
- (void)appendXML:(OFXMLDocument *)doc baseStyle:(OSStyle *)baseStyle;
@end
