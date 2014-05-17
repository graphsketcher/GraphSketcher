// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSGraphElementView.h"

@interface PointCreationEffect : RSGraphElementView
{
@private
    //NSTimer *_timer;
}

// Convenience method
+ (void)pointCreationEffectWithElement:(RSGraphElement *)GE inView:(GraphView *)view;

- (void)startCreationEffect;

@end
