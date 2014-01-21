// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSEnumStyleAttribute.h 200244 2013-12-10 00:11:55Z correia $

#import "OSStyleAttribute.h"

@class OFEnumNameTable;

@interface OSEnumStyleAttribute : OSStyleAttribute <OSConcreteStyleAttribute>
{
@private
    OFEnumNameTable *_enumTable;
}

- initWithKey:(NSString *)key enumTable:(OFEnumNameTable *)enumTable;

@property(readonly,nonatomic) OFEnumNameTable *enumTable;

@end
