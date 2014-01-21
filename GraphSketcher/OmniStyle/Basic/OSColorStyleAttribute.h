// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSColorStyleAttribute.h 200244 2013-12-10 00:11:55Z correia $

#import "OSStyleAttribute.h"

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE

@class NSColor;

#define OS_COLOR_CLASS NSColor
#define OS_COLOR_CLASS_FROM_PLATFORM_COLOR(color) (color)
#define OS_COLOR_CLASS_TO_PLATFORM_COLOR(color) (color)

#else //

@class OQColor;

#define OS_COLOR_CLASS OQColor
#define OS_COLOR_CLASS_FROM_PLATFORM_COLOR(color) ([OQColor colorWithPlatformColor:(color)])
#define OS_COLOR_CLASS_TO_PLATFORM_COLOR(color) ([(color) toColor])

#endif

@interface OSColorStyleAttribute : OSStyleAttribute <OSConcreteStyleAttribute>
@end
