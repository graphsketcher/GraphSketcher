// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

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
