// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSFillTool.h"

#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>

#import "AppController.h"
#import "Document.h"
#import "FillDrawingView.h"
#import "TraceEdgesGestureRecognizer.h"
#import "GraphView.h"
#import "PointCreationEffect.h"

@interface RSFillTool (/*Private*/)
@property (retain) RSVertex *cornerInProgress;
@property (retain) RSGraphElement *touchedElement;
@end

@implementation RSFillTool

#pragma mark -
#pragma mark Private

- (void)_setupDrawingView;
{
    if (!_drawingView) {
        _drawingView = [[FillDrawingView alloc] initWithFrame:CGRectZero];
        _drawingView.delegate = self;
    }
    
    // size to viewport
    GraphView *graphView = self.view;
    CGRect canvasRect = [graphView bounds];
    CGRect superRect = [graphView.superview bounds];
    _drawingView.frame = CGRectIntersection(superRect, canvasRect);
    
    [graphView addSubview:_drawingView];
}


#pragma mark -
#pragma mark RSTool

- (void)dealloc;
{
    [_traceEdgesGR release];
    [_drawingView release];
    [_fillInProgress removeAllVertices];
    [_fillInProgress release];
    [_touchedElement release];
    [_leftToolbarItems release];
    [_rightToolbarItems release];
    self.cornerInProgress = nil;
    
    [super dealloc];
}

- (void)activate;
{
    [super activate];
    
    [self.view clearSelection];

    if (!_traceEdgesGR) {
        _traceEdgesGR = [[TraceEdgesGestureRecognizer alloc] initWithTarget:self action:@selector(traceEdgesGesture:)];
        _traceEdgesGR.tool = self;
    }
    [self.view addGestureRecognizer:_traceEdgesGR];
}

- (void)deactivate;
{
    [self discardFillInProgress];
    
    [self.view removeGestureRecognizer:_traceEdgesGR];
    
    [_drawingView removeFromSuperview];
    [_drawingView release];
    _drawingView = nil;
    
    [super deactivate];
}

- (NSArray *)leftBarButtonItems;
{
    if (_leftToolbarItems == nil) {
        OUIDocumentAppController *controller = [OUIDocumentAppController controller];
        NSArray *items = @[
            [controller undoBarButtonItem]
        ];
        _leftToolbarItems = [items copy];
    }
    
    return _leftToolbarItems;
}

- (NSArray *)rightBarButtonItems;
{
    if (_rightToolbarItems == nil) {
        OUIDocumentAppController *controller = [OUIDocumentAppController controller];
        NSArray *items = @[
            [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:controller action:@selector(_handMode:)] autorelease]
        ];
        _rightToolbarItems = [items copy];
    }
    
    return _rightToolbarItems;
}

- (NSString *)toolbarTitle;
{
    return NSLocalizedString(@"Trace around the area to fill, pausing at each corner.", @"Explanotext when you enter fill mode.");
}

- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
{
    // Don't redraw the graph while we're drawing a line
    if (self.fillInProgress) {
        //[self.editor.hitTester updateSnappedTosForVertices:[[_fillInProgress vertices] elements]];
        [self.editor.mapper resetCurveCache];
        [self.editor.renderer invalidateCache];
        [_drawingView setNeedsDisplay];
        
        return;
    }
    
    [super graphEditorNeedsDisplay:editor];
}


#pragma mark -
#pragma mark Fill construction methods

@synthesize touchedElement = _touchedElement;
@synthesize fillInProgress = _fillInProgress;
@synthesize cornerInProgress = _cornerInProgress;

- (RSVertex *)_guaranteedCornerInProgress;
{
    if (!_fillInProgress)
        _fillInProgress = [[RSFill alloc] initWithGraph:self.editor.graph];
    
    OBPRECONDITION(_fillInProgress);
    
    if (!self.cornerInProgress) {
        self.cornerInProgress = [[[RSVertex alloc] initWithGraph:self.editor.graph] autorelease];
        [self.cornerInProgress setWidth:0];
        [self.fillInProgress addVertexAtEnd:self.cornerInProgress];
        //NSLog(@"adding corner #%d", [[_fillInProgress vertices] elements].count);
        
//        if ([[_fillInProgress vertices] elements].count == 4) {
//            OBASSERT_NOT_REACHED("hi");
//        }
    }
    return self.cornerInProgress;
}

- (RSVertex *)_prevFillVertex;
{
    OBPRECONDITION(_fillInProgress);

    if (![_fillInProgress count])
        return nil;
    
    NSArray *elements = [[_fillInProgress vertices] elements];
    return [elements lastObject];
}

- (void)resetState;
{
    //NSLog(@"resetState");
    
    [_fillInProgress release];
    _fillInProgress = nil;
    
    self.cornerInProgress = nil;
    
    _drawingView.snappedToElement = nil;
    [_drawingView hideGridSnapPoint];
    [_drawingView setNeedsDisplay];
    
    // We've either completed or discarded a fill. Close off any undo group for this multi-event operation
    [[[AppController controller] document] finishUndoGroup];
}

- (void)discardFillInProgress;
{
    //NSLog(@"discardFillInProgress");
    
    // Cancel the fill that will never be committed
    [_fillInProgress clearSnappedTos];
    [_fillInProgress removeAllVertices];
    [_fillInProgress invalidate];
    
    // Reset the tool
    [self resetState];
}

- (BOOL)commitFillInProgress;
{
    OBPRECONDITION(_fillInProgress);

    //NSLog(@"commitFillInProgress");
    
    // Add the current vertex
    //[self startNextFillCornerWithAnimation:NO];
    
    // Cancel the fill if it isn't an actual area
    if ( ![_fillInProgress hasAtLeastThreeVertices] || [_fillInProgress shouldBeDrawnAsLine] ) {
	[self discardFillInProgress];
        return YES;  // means "no errors"
    }
    
    // Add the fill to the graph and select it
    [self.editor.graph addElement:_fillInProgress];
    RSGraphElement *addedElement = [_fillInProgress groupWithVertices];
    
    // Reset the tool
    [self resetState];
    
    // Update and redraw the main GraphView
    [self.editor modelChangeRequires:RSUpdateConstraints];
    
    [super completeOperationWithElement:addedElement];
    
    return YES;
}

- (void)startNextFillCornerWithAnimation:(BOOL)animate;
{
    //NSLog(@"startNextFillCorner");
    OBASSERT(self.cornerInProgress);
    
    RSVertex *V = self.cornerInProgress;
    
//    RSVertex *V = [[_persistentVertex parentlessCopy] autorelease];
//    [V setSnappedTo:[_persistentVertex snappedTo] withParams:[_persistentVertex snappedToParams]];  // copy over the snappedTo info
//    [_persistentVertex clearSnappedTo];
//    
//    BOOL wereNew = [_fillInProgress addVertexAtEnd:V];
//    [_fillInProgress polygonize];
//    if (!wereNew) {
//        // end the fill?
//    }
    
    if (animate)
        [PointCreationEffect pointCreationEffectWithElement:V inView:self.view];
    
    // Remove redundant points snapped to the same line as the last vertex
    [self.fillInProgress pruneFromEndVertex];
    
    self.cornerInProgress = nil;
    [_drawingView setNeedsDisplay];
    
    //[_drawingView setFillInProgress:_fillInProgress withVertex:_persistentVertex];
}

- (void)fillCornerEndedAtPoint:(CGPoint)p;
{
    //NSLog(@"fillCornerEndedAtPoint:");
    
    [self startNextFillCornerWithAnimation:YES];
}


#pragma mark -
#pragma mark Touch handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesBegan:touches withEvent:event];
    
    if ([touches count] != 1) {
        return;
    }
    
    [self _setupDrawingView];
    
    GraphView *view = (GraphView *)self.view;
    UITouch *touch = [touches anyObject];
    CGPoint p = [view viewPointForTouchPoint:[touch locationInView:view]];
    
    self.touchedElement = [self.editor.hitTester snapVertex:[self _guaranteedCornerInProgress] fromPoint:p];
    
    _drawingView.snappedToElement = self.touchedElement;
    _drawingView.gridSnapPoint = [self _guaranteedCornerInProgress].position;
    [_drawingView setNeedsDisplay];
    
    [PointCreationEffect pointCreationEffectWithElement:self.cornerInProgress inView:self.view];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
// If we get this, no gesture recognizers were activated
{
    [super touchesEnded:touches withEvent:event];
    
    [self discardFillInProgress];
}

- (void)traceEdgesGesture:(TraceEdgesGestureRecognizer *)gestureRecognizer;
{
    OBPRECONDITION(_fillInProgress);

    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        GestureLog(@"traceEdges gesture began");
        //_activeRecognizer = gestureRecognizer;
        
        [self startNextFillCornerWithAnimation:NO];
        
        CGPoint p = [self.view viewPointForTouchPoint:[gestureRecognizer locationInView:self.view]];
        [[self _guaranteedCornerInProgress] clearSnappedTo];
        self.touchedElement = [self.editor.hitTester snapVertex:self.cornerInProgress fromPoint:p];
        
        [self.editor.hitTester updateSnappedTosForVertices:[[_fillInProgress vertices] elements]];
        
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if (gestureRecognizer.paused) {
            return;
        }
        //NSLog(@"traceEdges gesture changed");
        
        //NSLog(@"velocity: %f", gestureRecognizer.velocity);
        
        CGPoint p = [self.view viewPointForTouchPoint:[gestureRecognizer locationInView:self.view]];
        
        [[self _guaranteedCornerInProgress] clearSnappedTo];
        
        self.touchedElement = [self.editor.hitTester snapVertex:[self _guaranteedCornerInProgress] fromPoint:p];// behavior:RSSnapBehaviorRegular prevVertex:[self _prevFillVertex] nextVertex:[_fillInProgress firstVertex]];
//        if (self.touchedElement) {
//            NSLog(@"snapped element: %@", self.touchedElement);
//        }
        
        _drawingView.gridSnapPoint = [self _guaranteedCornerInProgress].position;
        
        [self.editor.hitTester updateSnappedTosForVertices:[[self.fillInProgress vertices] elements]];
        //[self.fillInProgress polygonize];
        
        _drawingView.snappedToElement = self.touchedElement;
        [_drawingView setNeedsDisplay];
        
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        GestureLog(@"traceEdges gesture ended");
        
        [self commitFillInProgress];
        
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        GestureLog(@"traceEdges gesture cancelled");
        
        [self discardFillInProgress];
        
        return;
    }
}


@end
