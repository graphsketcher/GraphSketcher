// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/NSSegmentedControl-RSExtensions.m 200244 2013-12-10 00:11:55Z correia $

#import "NSSegmentedControl-RSExtensions.h"


@implementation NSSegmentedControl (RSExtensions)

- (void)deselectAllSegments;
{
    NSInteger segmentCount = [self segmentCount];
    
    for (NSInteger i=0; i<segmentCount; i++) {
	[self setSelected:NO forSegment:i];
    }
}

@end
