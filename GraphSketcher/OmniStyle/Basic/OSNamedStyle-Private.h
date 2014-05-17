// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSNamedStyle.h"


@interface OSNamedStyle (/*Private*/)
// OSNamedStyle instances should only be created by OSNamedStyleList -- thus, these initializers are private.
- initWithContext:(OSStyleContext *)context identifier:(NSString *)identifier name:(NSString *)name;
- initFromXML:(OFXMLCursor *)cursor context:(OSStyleContext *)context identifier:(NSString *)identifier name:(NSString *)name;
@end
