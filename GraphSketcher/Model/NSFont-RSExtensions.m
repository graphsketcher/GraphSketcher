// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/NSFont-RSExtensions.m 200244 2013-12-10 00:11:55Z correia $

#import "NSFont-RSExtensions.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/NSFont-RSExtensions.m 200244 2013-12-10 00:11:55Z correia $");

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE

@implementation NSFont (RSExtensions)

- (NSFont *)fontWithSize:(CGFloat)pointSize;
{
    NSFontDescriptor *descriptor = [self fontDescriptor];
    return [NSFont fontWithDescriptor:descriptor size:pointSize];
}

- (CGFloat)lineHeight;
{
    static NSLayoutManager *layoutManager = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        layoutManager = [[NSLayoutManager alloc] init];
    });
    
    return [layoutManager defaultLineHeightForFont:self];
}

@end

#endif
