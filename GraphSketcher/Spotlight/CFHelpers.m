// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Spotlight/CFHelpers.m 200244 2013-12-10 00:11:55Z correia $

#import "CFHelpers.h"

static const void *_retainCallBack(CFAllocatorRef allocator, const void *value)
{
    return CFRetain((CFTypeRef)value);
}

static void _releaseCallBack(CFAllocatorRef allocator, const void *value)
{
    CFRelease((CFTypeRef)value);
}

static CFStringRef _copyDescriptionCallBack(const void *value)
{
    return CFCopyDescription((CFTypeRef)value);
}

static Boolean _equalCallBack(const void *value1, const void *value2)
{
    return CFEqual((CFTypeRef)value1, (CFTypeRef)value2);
}

const CFArrayCallBacks OFCFTypeArrayCallbacks = {
    0, // version;
    _retainCallBack,
    _releaseCallBack,
    _copyDescriptionCallBack,
    _equalCallBack,
};
