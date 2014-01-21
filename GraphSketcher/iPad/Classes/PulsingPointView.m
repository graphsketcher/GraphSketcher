// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/PulsingPointView.m 200244 2013-12-10 00:11:55Z correia $

#import "PulsingPointView.h"

#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSGraphElement-Rendering.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSVertex.h>
#import <OmniQuartz/OQColor.h>
#import "GraphView.h"
#import "Parameters.h"


@interface PulsingPointView (/*Private*/)
- (void)_pulseOut:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
- (void)_pulseIn:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
@end


@implementation PulsingPointView

#pragma mark -
#pragma mark Establishing a PulsingPointView

static PulsingPointView *_pulsingPointView = nil;
+ (PulsingPointView *)pulsingPointViewForView:(UIView *)view element:(RSVertex *)GE;
{
    if (!_pulsingPointView) {
        _pulsingPointView = [[PulsingPointView alloc] initWithFrame:CGRectZero];
    }
    
    [view addSubview:_pulsingPointView];
    [_pulsingPointView beginEffectForElement:GE];
    
    return _pulsingPointView;
}

- (void)beginEffectForElement:(RSVertex *)GE;
{
    self.vertex = GE;
    
    // If already pulsing, leave it be
    if (_isPulsing)
        return;
    
    _isPulsing = YES;
    
    self.frame = [self frameWithSizeDelta:1 - PULSE_EFFECT_WIDTH];
    self.alpha = 1;//0.62;
    
    [UIView beginAnimations:@"RSPulsingPointBeginEffectAnimation" context:NULL];
    {
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_beginEffectDidStop:finished:context:)];
        
        [UIView setAnimationDuration:PULSE_BEGIN_DELAY];
        self.frame = [self frameWithSizeDelta:10];
    }
    [UIView commitAnimations];
}

- (void)_beginEffectDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    // Start the pulsing
    [self _pulseOut:nil finished:nil context:NULL];
}

- (void)_pulseOut:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    if (!_isPulsing)
        return;
    
    [UIView beginAnimations:@"RSPulsingPointAnimation" context:NULL];
    {
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_pulseIn:finished:context:)];
        
        [UIView setAnimationDuration:PULSE_EFFECT_DELAY];
        self.frame = [self frameWithSizeDelta:PULSE_EFFECT_DELTA];
    }
    [UIView commitAnimations];
}

- (void)_pulseIn:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    if (!_isPulsing)
        return;
    
    OBASSERT(self.superview);
    
    [UIView beginAnimations:@"RSPulsingPointAnimation" context:NULL];
    {
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_pulseOut:finished:context:)];
        
        [UIView setAnimationDuration:PULSE_EFFECT_DELAY];
        self.frame = [self frameWithSizeDelta:-PULSE_EFFECT_DELTA];
    }
    [UIView commitAnimations];
}

- (void)endEffect;
{
    _isPulsing = NO;
    
    [UIView beginAnimations:@"RSPulsingPointAnimation" context:NULL];
    {
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_endEffectDidStop:finished:context:)];
        [UIView setAnimationBeginsFromCurrentState:YES];
        //[UIView setAnimationDuration:SELECTION_DELAY];
        
        //self.alpha = 0;
        self.frame = [self frameWithSizeDelta:PULSE_EFFECT_DELTA - PULSE_EFFECT_WIDTH];
        
    }
    [UIView commitAnimations];
}

- (void)_endEffectDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    // If someone started it pulsing again, keep it around
    if (_isPulsing)
        return;
    
    [self removeFromSuperview];
}

- (void)updateFrameWithDuration:(NSTimeInterval)duration;
{
    [UIView beginAnimations:@"RSPulsingPointUpdateAnimation" context:NULL];
    {
        [UIView setAnimationBeginsFromCurrentState:YES];  // Don't wait for animations currently in progress
        [UIView setAnimationDuration:duration];
        
        self.frame = [self frameWithSizeDelta:0];
    }
    [UIView commitAnimations];
}

#pragma mark -
#pragma mark Alloc/init

- (id)initWithFrame:(CGRect)aRect;
{
    if (!(self = [super initWithFrame:aRect]))
        return nil;
    
    self.userInteractionEnabled = NO;
    self.opaque = NO;
    
    _isPulsing = NO;
    
    return self;
}

- (void)dealloc;
{
    [_vertex release];
    [super dealloc];
}

@synthesize vertex = _vertex;
- (void)setVertex:(RSVertex *)newVertex;
{
    if (_vertex == newVertex)
        return;
    
    [_vertex release];
    _vertex = [newVertex retain];
    [self setNeedsDisplay];
}

- (CGRect)frameWithSizeDelta:(CGFloat)delta;
{
    GraphView *graphView = (GraphView *)[self superview];
    CGPoint center = [graphView.editor.mapper viewCenterOfElement:self.vertex];
    
    //CGSize size = self.vertex.size;
    CGSize size = CGSizeMake(PULSE_EFFECT_WIDTH, PULSE_EFFECT_WIDTH);
    CGSize targetSize = [self.vertex selectionSizeWithMinSize:CGSizeMake(size.width + delta, size.height + delta)];
    // Sanity check
    if (targetSize.width < 0)
        targetSize.width = 1;
    if (targetSize.height < 0)
        targetSize.height = 1;
    
    return [graphView viewRectWithCenter:center size:targetSize];
}

#pragma mark -
#pragma mark UIView

- (void)drawRect:(CGRect)rect;
{
    GraphView *graphView = (GraphView *)[self superview];
    
    CGRect bounds = self.bounds;
    
    [graphView establishTransformToRenderingSpace:UIGraphicsGetCurrentContext()];
    
    CGPoint p = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    
    p = [graphView convertPointFromRenderingSpace:p];
    
    CGSize size = bounds.size;
    // Don't clip the edges
    size.width *= 0.8;
    size.height *= 0.8;
    // Account for zooming
    size.width /= graphView.scale;
    size.height /= graphView.scale;
    
    CGFloat borderWidth = 5;
    borderWidth /= graphView.scale;
    
    //[self.vertex drawAtPoint:p size:size];
    [self.vertex drawSelectionAtPoint:p borderWidth:borderWidth color:[OQColor selectedTextBackgroundColor] minSize:size];
}

@end
