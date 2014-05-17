// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "PointCreationEffect.h"

#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSGraphElement-Rendering.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <OmniQuartz/OQColor.h>

#import "GraphView.h"
#import "Parameters.h"


@implementation PointCreationEffect

//static PointCreationEffect *_sharedEffect = nil;

+ (void)pointCreationEffectWithElement:(RSGraphElement *)GE inView:(GraphView *)view;
{
    PointCreationEffect *effect = [[PointCreationEffect alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    [view addSubview:effect];
    [effect release];
    
    effect.graphElement = GE;
    [effect startCreationEffect];
}

- (void)startCreationEffect;
{
    [self updateFrame];
    
    CGFloat delta = RS_POINT_CREATION_EFFECT_EXPANSION * 2;
    CGRect newFrame = CGRectInset(self.frame, -delta, -delta);
    
    [UIView beginAnimations:@"RSPointCreationEffect" context:NULL];
    {
        [UIView setAnimationDuration:RS_POINT_CREATION_EFFECT_DURATION];
        self.frame = newFrame;
        self.alpha = 0;
        
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_creationEffectDidStop:finished:context:)];
    }
    [UIView commitAnimations];
}

- (void)_creationEffectDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    [self removeFromSuperview];
}

- (void)drawRect:(CGRect)rect;
{
    //NSLog(@"drawing GE View");
    
#ifdef DEBUG_robin
    CGRect bounds = self.bounds;
    [[UIColor colorWithRed:1 green:0 blue:0 alpha:0.2] set];
    UIBezierPath *P = [UIBezierPath bezierPathWithRect:bounds];
    //[P fill];
    [P setLineWidth:2];
    [P stroke];
#endif
    
    [self establishAllRenderingTransforms];
    
    //[self.renderer drawSelected:self.graphElement windowIsKey:YES];
    
    CGFloat borderWidth = RS_POINT_CREATION_EFFECT_EXPANSION;
    CGFloat minSize = RS_POINT_CREATION_EFFECT_EXPANSION;
    CGPoint p = [self.editor.mapper convertToViewCoords:[self.graphElement position]];
    [self.graphElement drawSelectionAtPoint:p borderWidth:borderWidth color:[OQColor selectedTextBackgroundColor] minSize:CGSizeMake(minSize, minSize)];
}

@end
