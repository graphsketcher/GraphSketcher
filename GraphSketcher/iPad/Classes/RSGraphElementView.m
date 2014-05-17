// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSGraphElementView.h"

#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSGraphElement-Rendering.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <OmniQuartz/OQColor.h>
#import "GraphView.h"
#import "Parameters.h"

RCS_ID("$Header$");

static NSString * const RSMakeNormalSizeAnimation = @"RSMakeNormalSizeAnimation";
static NSString * const RSMakeNormalSizeAndHideAnimation = @"RSMakeNormalSizeAndHideAnimation";


@interface RSGraphElementView (/*Private*/)
- (void)_makeNormalSizeEffectDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
@end


@implementation RSGraphElementView

- (id)initWithFrame:(CGRect)aRect;
{
    if (!(self = [super initWithFrame:aRect]))
        return nil;
    
    self.userInteractionEnabled = NO;
    self.opaque = NO;
    //self.contentMode = UIViewContentModeRedraw;
    //self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    //self.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.2];
    
    // Defaults
    _drawFingerSize = NO;
    _shouldHide = NO;
    _borderWidth = 8;
    _selectionDelay = SELECTION_DELAY;
    _fadeDuration = SELECTION_DELAY;
    
    [self addObserver:self forKeyPath:@"hidden" options:NSKeyValueObservingOptionNew context:NULL];
    
    return self;
}

- (void)dealloc;
{
    [self removeObserver:self forKeyPath:@"hidden"];
    
    [_graphElement release];
    [super dealloc];
}


#pragma mark -
#pragma mark Properties

@synthesize graphElement = _graphElement;
- (void)setGraphElement:(RSGraphElement *)graphElement;
{
    if (_graphElement == graphElement)
        return;
    
    [_graphElement release];
    _graphElement = [graphElement retain];
    
    _subpart = RSGraphElementSubpartWhole;  // reset the subpart
    
    [self updateFrame];
    [self setNeedsDisplay];
}

@synthesize subpart = _subpart;
- (void)setSubpart:(RSGraphElementSubpart)subpart;
{
    if (_subpart == subpart)
        return;
    
    _subpart = subpart;
    [self updateFrame];
    [self setNeedsDisplay];
}

@synthesize borderWidth = _borderWidth;
@synthesize selectionDelay = _selectionDelay;
@synthesize fadeDuration = _fadeDuration;


#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if (object == self && [keyPath isEqualToString:@"hidden"]) {
        
    }
}


#pragma mark -
#pragma mark Calculating frame sizes

- (CGRect)_viewportFrame;
{
    CGRect canvasRect = [self.graphView bounds];
//    return canvasRect;
    CGRect superRect = [self.graphView.superview bounds];
    return CGRectIntersection(superRect, canvasRect);
}

- (CGRect)_selectionFrame;
{
    CGRect viewRect = [self.graphElement selectionViewRectWithMapper:self.graphView.editor.mapper];
    
    CGRect rect;
    if (CGRectEqualToRect(viewRect, CGRectZero)) {
        // When view size is unknown, revert to filling the whole window.
        rect = [self _viewportFrame];
    }
    else {
        rect = CGRectIntegral([self.graphView convertRectToRenderingSpace:viewRect]);
        rect = CGRectIntersection(rect, [self _viewportFrame]);
    }
    
    return rect;
}

- (CGRect)_fingerStartFrame;
{
    CGPoint center = [self.editor.mapper viewCenterOfElement:self.graphElement];
    
    CGSize startSize = [self.graphElement selectionSize];
    startSize.width += self.borderWidth;
    startSize.width *= 2;
    startSize.height += self.borderWidth;
    startSize.height *= 2;
    CGRect startFrame = [self.graphView viewRectWithCenter:center size:startSize];
    
    return startFrame;
}

- (CGRect)_fingerEndFrame;
{
    CGPoint center = [self.editor.mapper viewCenterOfElement:self.graphElement];
    
    CGSize endSize = [self.graphElement selectionSizeWithMinSize:CGSizeMake(RS_FINGER_WIDTH, RS_FINGER_WIDTH)];
    endSize.width *= 2;
    endSize.height *= 2;
    CGRect endFrame = [self.graphView viewRectWithCenter:center size:endSize];
    
    return endFrame;
}

- (void)updateFrame;
{
    //NSLog(@"updateFrame");
    
    CGRect rect = CGRectZero;
    if (!self.graphElement) {
        rect = CGRectZero;//[self _viewportFrame];
    }
    else if (_drawFingerSize) {
        rect = [self _fingerEndFrame];
    }
    else {
        rect = [self _selectionFrame];
    }
    
    //NSLog(@"Updating frame to: %@", NSStringFromCGRect(rect));
    if (!CGRectEqualToRect(self.frame, rect)) {
        self.frame = rect;
    }
    
#ifdef DEBUG_robin
    if (!CGRectEqualToRect(self.frame, CGRectZero) && !CGRectEqualToRect(CGRectUnion(self.frame, [self _viewportFrame]), [self _viewportFrame])) {
        NSLog(@"selection frame is too big: %@", NSStringFromCGRect(self.frame));
    }
#endif
}

- (CGAffineTransform)transformToLayerSpace;
{
    CGRect frame = self.frame;
    //NSLog(@"frame: %@", NSStringFromCGRect(frame));
    
    CGAffineTransform xform = CGAffineTransformIdentity;
    xform = CGAffineTransformTranslate(xform, -frame.origin.x, -frame.origin.y);
    
    return xform;
}

- (void)establishTransformToLayerSpace;
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(ctx, [self transformToLayerSpace]);
}

- (void)establishAllRenderingTransforms;
{
    [self establishTransformToLayerSpace];
    
    [self.graphView establishTransformToRenderingSpace:UIGraphicsGetCurrentContext()];
}

- (GraphView *)graphView;
{
    GraphView *view = (GraphView *)[self superview];
    OBASSERT([view isKindOfClass:[GraphView class]]);
    return view;
}

- (RSGraphEditor *)editor;
{
    return self.graphView.editor;
}


#pragma mark -
#pragma mark Animations

- (void)hideAnimated:(BOOL)animated;
{
    GEVLog(@"RSGEV hide");
    _shouldHide = YES;
    
    if (self.hidden)
        return;
    
    if (!animated) {
        self.hidden = YES;
        return;
    }
    
    [UIView beginAnimations:@"RSHideAnimation" context:NULL];
    {
        [UIView setAnimationDuration:self.fadeDuration];
        self.alpha = 0;
        
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_hideEffectDidStop:finished:context:)];
    }
    [UIView commitAnimations];
}

- (void)_hideEffectDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    if (!_shouldHide) {
        self.alpha = 1;
        return;
    }
    
    self.hidden = YES;
    self.alpha = 1;
}

- (void)showAnimated:(BOOL)animated;
{
    GEVLog(@"RSGEV show");
    _shouldHide = NO;
    
    if (!animated) {
        self.hidden = NO;
        return;
    }
    
    self.alpha = 0;
    self.hidden = NO;
    
    [UIView beginAnimations:@"RSShowAnimation" context:NULL];
    {
        [UIView setAnimationDuration:self.selectionDelay];
        self.alpha = 1;
    }
    [UIView commitAnimations];
}

- (BOOL)_canDrawFingerSize;
{
    RSGraphElement *GE = self.graphElement;
    
    if ([GE isKindOfClass:[RSTextLabel class]]) {
        return YES;
    }
    if ([GE isKindOfClass:[RSVertex class]]) {
        if ([(RSVertex *)GE isBar] && self.subpart == RSGraphElementSubpartWhole) {
            return NO;
        }
        return YES;
    }
    
    return NO;
}

- (void)makeFingerSize;
{
    GEVLog(@"RSGEV makeFingerSize");
    _shouldHide = NO;
    
    if (![self _canDrawFingerSize]) {
        [self updateFrame];
        [self setNeedsDisplay];
        [self showAnimated:YES];
        return;
    }
    
    self.hidden = NO;
    
    self.frame = [self _fingerStartFrame];
    _drawFingerSize = YES;
    [self setNeedsDisplay];
    
    [UIView beginAnimations:@"RSMakeFingerSizeAnimation" context:NULL];
    {
        [UIView setAnimationDuration:self.selectionDelay];
        self.frame = [self _fingerEndFrame];
    }
    [UIView commitAnimations];
}

- (void)makeNormalSizeAndHide:(BOOL)hide;
{
    GEVLog(@"RSGEV makeNormalSizeAndHide:");
    NSString *animationID = RSMakeNormalSizeAnimation;
    if (hide) {
        animationID = RSMakeNormalSizeAndHideAnimation;
        _shouldHide = YES;
    } else {
        _shouldHide = NO;
    }
    
    if (![self _canDrawFingerSize]) {
        [self _makeNormalSizeEffectDidStop:animationID finished:nil context:NULL];
        return;
    }
    
    [UIView beginAnimations:animationID context:NULL];
    {
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_makeNormalSizeEffectDidStop:finished:context:)];
        [UIView setAnimationDuration:self.selectionDelay];
        
        self.frame = [self _fingerStartFrame];
    }
    [UIView commitAnimations];
}

- (void)_makeNormalSizeEffectDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    _drawFingerSize = NO;
    
    if (animationID == RSMakeNormalSizeAndHideAnimation && _shouldHide) {
        self.hidden = YES;
        return;
    }
    
    [self setNeedsDisplay];
    [self updateFrame];
}


#pragma mark -
#pragma mark UIView

- (void)_drawAtFingerSize;
{
    OBPRECONDITION(self.graphElement);
    
    [self establishAllRenderingTransforms];
    
    
    // Our finger doesn't get bigger when we zoom!
    CGFloat scale = self.graphView.scale;
    CGFloat viewBorderWidth = self.borderWidth / scale;
    CGFloat minSize = RS_FINGER_WIDTH / scale;
    
    CGPoint p = [self.editor.mapper viewCenterOfElement:self.graphElement];
    [self.graphElement drawSelectionAtPoint:p borderWidth:viewBorderWidth color:[OQColor selectedTextBackgroundColor] minSize:CGSizeMake(minSize, minSize) subpart:self.subpart];
    //[self.graphElement drawSelectedUsingMapper:self.editor.mapper selectionColor:[OQColor selectedTextBackgroundColor] borderWidth:viewBorderWidth alpha:1 fingerWidth:minSize subpart:self.subpart];
}

- (void)drawRect:(CGRect)rect;
{
#if defined(DEBUG_robin)
    //NSLog(@"drawing GE View");
#endif
    
#if defined(DEBUG_robin) && 0
    CGRect bounds = self.bounds;
    [[UIColor colorWithRed:1 green:0 blue:0 alpha:0.2] set];
    UIBezierPath *P = [UIBezierPath bezierPathWithRect:bounds];
    //[P fill];
    [P setLineWidth:2];
    [P stroke];
#endif
    
    if (_drawFingerSize) {
        [self _drawAtFingerSize];
        return;
    }
    
    // If no object is under the finger, draw an effect that indicates touching the canvas. Maybe. <bug://bugs/60341>
    if (!self.graphElement) {
//        CGRect bounds = self.bounds;
//        [[OQColor selectedTextBackgroundColor] set];
//        UIBezierPath *P = [UIBezierPath bezierPathWithRect:bounds];
//        //[P fill];
//        [P setLineWidth:6];
//        [P stroke];
        return;
    }
    
    // Normally
    [self establishAllRenderingTransforms];
    
    [self.editor.renderer drawSelected:self.graphElement windowIsKey:YES];
}

@end
