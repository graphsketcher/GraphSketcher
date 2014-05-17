// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <UIKit/UIView.h>

@class RSVertex;


@interface PulsingPointView : UIView
{
@private
    RSVertex *_vertex;
    BOOL _isPulsing;
}

+ (PulsingPointView *)pulsingPointViewForView:(UIView *)view element:(RSVertex *)GE;

@property (nonatomic, retain) RSVertex *vertex;
- (CGRect)frameWithSizeDelta:(CGFloat)delta;

- (void)beginEffectForElement:(RSVertex *)GE;
- (void)endEffect;
- (void)updateFrameWithDuration:(NSTimeInterval)duration;

@end
