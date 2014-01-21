// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSNamedStyle-Private.h 200244 2013-12-10 00:11:55Z correia $

#import "OSNamedStyle.h"


@interface OSNamedStyle (/*Private*/)
// OSNamedStyle instances should only be created by OSNamedStyleList -- thus, these initializers are private.
- initWithContext:(OSStyleContext *)context identifier:(NSString *)identifier name:(NSString *)name;
- initFromXML:(OFXMLCursor *)cursor context:(OSStyleContext *)context identifier:(NSString *)identifier name:(NSString *)name;
@end
