// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSNumberStyleAttribute.h 200244 2013-12-10 00:11:55Z correia $

#import "OSStyleAttribute.h"

#import <OmniFoundation/OFExtent.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <Foundation/NSGeometry.h>
#else
#import <CoreGraphics/CGGeometry.h>
#endif

@interface OSNumberStyleAttribute : OSStyleAttribute <OSConcreteStyleAttribute>
{
@private
    OFExtent _valueExtent; // NSRange is integral and unsigned
    BOOL _integral;
}

- initWithKey:(NSString *)key defaultValue:(NSNumber *)defaultValue valueExtent:(OFExtent)valueExtent integral:(BOOL)integral;

@property(readonly,nonatomic) OFExtent valueExtent;
@property(readonly,nonatomic) BOOL integral;

@end
