// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/FillDrawingView.m 200244 2013-12-10 00:11:55Z correia $

#import "FillDrawingView.h"

#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGraphElement.h>
#import <OmniQuartz/OQColor.h>
#import "GraphView.h"
#import "RSFillTool.h"


@implementation FillDrawingView

- (id)initWithFrame:(CGRect)aRect;
{
    if (!(self = [super initWithFrame:aRect]))
        return nil;
    
    self.userInteractionEnabled = NO;
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    [self hideGridSnapPoint];
    
    return self;
}

- (void)dealloc;
{
    [_snappedToElement release];
    [super dealloc];
}

@synthesize delegate = _delegate;

@synthesize snappedToElement = _snappedToElement;
@synthesize gridSnapPoint = _gridSnapPoint;

- (void)hideGridSnapPoint;
{
    if (_gridSnapPoint.x == DBL_MIN)
        return;
    
    _gridSnapPoint = RSDataPointMake(DBL_MIN, DBL_MIN);
    [self setNeedsDisplay];
}


#pragma mark -
#pragma mark Rendering

- (CGAffineTransform)transformToLayerSpace;
{
    CGRect frame = self.frame;
    
    CGAffineTransform xform = CGAffineTransformIdentity;
    xform = CGAffineTransformTranslate(xform, -frame.origin.x, -frame.origin.y);
    
    return xform;
}

- (void)establishTransformToLayerSpace;
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(ctx, [self transformToLayerSpace]);
}

- (void)drawRect:(CGRect)rect;
{
    //NSLog(@"FillDrawingView drawRect");
    
    [self establishTransformToLayerSpace];
    
    GraphView *graphView = (GraphView *)self.superview;
    [graphView establishTransformToRenderingSpace:UIGraphicsGetCurrentContext()];
    
//    [[UIColor redColor] set];
//    UIBezierPath *P = [UIBezierPath bezierPathWithRect:CGRectMake(200, 200, 100, 100)];
//    [P setLineWidth:4];
//    [P stroke];
    
    // snap-to-grid visualization
    if (_gridSnapPoint.x != DBL_MIN) {
        [graphView.editor.renderer drawGridPoint:_gridSnapPoint];
    }
    
    if (self.snappedToElement) {
        [graphView.editor.renderer drawHalfSelected:self.snappedToElement];
    }
    
    [graphView.editor.renderer drawFill:self.delegate.fillInProgress inProgress:NO];
}


@end
