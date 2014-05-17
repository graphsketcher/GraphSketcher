// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "AxisController.h"
#import "Parameters.h"
#import "GraphView.h"
#import "AxisEndHandleView.h"
#import "AppController.h"
#import "Document.h"

#import <GraphSketcherModel/RSAxis.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>
#import <GraphSketcherModel/RSGraphElementSelector.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSTextLabel.h>

#import <OmniUI/OUIDragGestureRecognizer.h>
#import <OmniUI/OUIOverlayView.h>
#import <OmniUI/OUIScalingScrollView.h>


@interface AxisControllerMainView : UIView
{
    AxisController *controller;
}
@property (assign, nonatomic) AxisController *controller;
@end

@implementation AxisControllerMainView

@synthesize controller;

// Override so that touches are hit-tested against the handles.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event;
{
    NSArray *handleViews = [NSArray arrayWithObjects:controller.tickSpacingHandle, controller.maxHandle, controller.minHandle, nil];
    for (UIImageView *handleView in handleViews) {
        if ([handleView pointInside:[self convertPoint:point toView:handleView] withEvent:event]) {
            return YES;
        }
    }
    
    return [super pointInside:point withEvent:event];
}

- (void)layoutSubviews;
{
    //NSLog(@"AxisControllerMainView layoutSubviews");
    
    //[controller adjustHandlePositions];
}

@end


@implementation AxisController

@synthesize graphView, axis;
@synthesize tickSpacingHandle, minHandle, maxHandle;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

- (id)initWithGraphView:(GraphView *)GV;
{
    if (!(self = [super init]))
        return nil;
    
    graphView = GV;
    
    return self;
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView;
{
    AxisControllerMainView *mainView = [[AxisControllerMainView alloc] initWithFrame:CGRectZero];
    mainView.controller = self;
    self.view = mainView;
    [mainView release];
    //self.view.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.1];
    
    tickSpacingHandle = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AxisTickSpacingKnob.png"]];
    tickSpacingHandle.userInteractionEnabled = YES;
    tickSpacingHandle.contentMode = UIViewContentModeBottom;
    tickSpacingHandle.bounds = CGRectMake(0, 0, 45, 58);
    //tickSpacingHandle.backgroundColor = [UIColor yellowColor];
    [self.view addSubview:tickSpacingHandle];
    
    maxHandle = [[AxisEndHandleView alloc] initWithAxis:axis isMax:YES];
    [self.view addSubview:maxHandle];
    
    minHandle = [[AxisEndHandleView alloc] initWithAxis:axis isMax:NO];
    [self.view addSubview:minHandle];
    
    // Set up gesture recognizers
    OUIDragGestureRecognizer *dragGR = [[OUIDragGestureRecognizer alloc] initWithTarget:self action:@selector(tickSpacingDragGesture:)];
    dragGR.holdDuration = 0.02;
    dragGR.delegate = self;
    [tickSpacingHandle addGestureRecognizer:dragGR];
    [dragGR release];
    
//    dragGR = [[OUIDragGestureRecognizer alloc] initWithTarget:self action:@selector(maxHandleDragGesture:)];
//    dragGR.holdDuration = 0.02;
//    [maxHandle addGestureRecognizer:dragGR];
//    [dragGR release];
//    
//    dragGR = [[OUIDragGestureRecognizer alloc] initWithTarget:self action:@selector(minHandleDragGesture:)];
//    dragGR.holdDuration = 0.02;
//    [minHandle addGestureRecognizer:dragGR];
//    [dragGR release];
    
    dragGR = [[OUIDragGestureRecognizer alloc] initWithTarget:self action:@selector(oneFingerDragGesture:)];
    dragGR.holdDuration = 0.05;
    dragGR.delegate = self;
    [self.view addGestureRecognizer:dragGR];
    [dragGR release];
    
    OUIDragGestureRecognizer *panGR = [[OUIDragGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerDragGesture:)];
    panGR.holdDuration = 0.02;
    panGR.numberOfTouchesRequired = 2;
    panGR.delegate = self;
    [self.view addGestureRecognizer:panGR];
    [panGR release];
    
}

- (BOOL)shouldAutorotate;
{
    return YES;
}

#pragma mark - API

- (UIView *)stableOuterView;
{
    return graphView;//.superview.superview;
}

- (UIScrollView *)outerScrollView;
{
    UIScrollView *scrollView = (UIScrollView *)graphView.superview;
    OBASSERT([scrollView isKindOfClass:[UIScrollView class]]);
    return scrollView;
}

- (CGPoint)convertPointToViewSpace:(CGPoint)point;
{
    CGPoint viewPosition = [graphView convertPoint:point fromView:self.view];
    viewPosition = [graphView convertPointFromRenderingSpace:viewPosition];
    return viewPosition;
}

- (void)setCenter:(CGPoint)center forView:(UIView *)subview;
// Align subview to pixel grid
{
    subview.center = center;
    
    if ([subview superview]) {
        CGRect newFrame = subview.frame;
        CGPoint origin = [[subview superview] convertPoint:newFrame.origin toView:nil];
        origin.x = rint(origin.x);
        origin.y = rint(origin.y);
        origin = [[subview superview] convertPoint:origin fromView:nil];
        newFrame.origin = origin;
        subview.frame = newFrame;
    }
}

- (void)restoreScrollPosition;
{
    OUIScalingScrollView *scrollView = (OUIScalingScrollView *)[graphView superview];
    OBASSERT([scrollView isKindOfClass:[OUIScalingScrollView class]]);
    
    scrollView.extraEdgeInsets = UIEdgeInsetsZero;
    [scrollView adjustContentInsetAnimated:YES];
    //[scrollView scrollRectToVisible:graphView.frame animated:YES];
}

- (void)scrollToMakeHandlesFitOnScreen;
{
    OUIScalingScrollView *scrollView = (OUIScalingScrollView *)[graphView superview];
    OBASSERT([scrollView isKindOfClass:[OUIScalingScrollView class]]);
    
    CGRect handleRect = CGRectUnion(minHandle.frame, maxHandle.frame);
    if (tickSpacingHandle.alpha) {
        handleRect = CGRectUnion(handleRect, tickSpacingHandle.frame);
    }
    CGRect scrollBounds = [graphView convertRect:handleRect fromView:self.view];
    CGRect canvasRect = graphView.bounds;
    CGRect unionRect = CGRectUnion(scrollBounds, canvasRect);
    
    if ( !CGRectEqualToRect(unionRect, canvasRect) ) {
        UIEdgeInsets newInset;
        newInset.top = CGRectGetMinY(canvasRect) - CGRectGetMinY(unionRect);
        newInset.left = CGRectGetMinX(canvasRect) - CGRectGetMinX(unionRect);
        newInset.bottom = CGRectGetMaxY(unionRect) - CGRectGetMaxY(canvasRect);
        newInset.right = CGRectGetMaxX(unionRect) - CGRectGetMaxX(canvasRect);
        //NSLog(@"new inset: %@", NSStringFromUIEdgeInsets(newInset));
        
        UIEdgeInsets currentInset = scrollView.contentInset;
        BOOL shouldChange = newInset.top > currentInset.top || newInset.left > currentInset.left || newInset.bottom > currentInset.bottom || newInset.right > currentInset.right;
        
        if (shouldChange) {
            scrollView.extraEdgeInsets = newInset;
            [scrollView adjustContentInsetAnimated:YES];
            [scrollView scrollRectToVisible:scrollBounds animated:YES];
            //NSLog(@"scrollRectToVisible: %@", NSStringFromCGRect(scrollBounds));
        }
    }
    
    else {
        [self restoreScrollPosition];
    }
}

- (void)update;
{
    RSAxis *selectedAxis = (RSAxis *)[graphView.selectionController selection];
    if (![selectedAxis isKindOfClass:[RSAxis class]]) {
        self.axis = nil;
    } else {
        self.axis = selectedAxis;
    }
    
    if (!axis)
        return;
    
    if (!showInProgress && touchInProgress) {
        return;
    }
    
    RSDataMapper *mapper = graphView.editor.mapper;
    
    // Position our main view according to the axis' position.
    
    CGPoint min = [graphView convertPointToRenderingSpace:[mapper viewMins]];
    CGPoint max = [graphView convertPointToRenderingSpace:[mapper viewMaxes]];
    CGPoint origin = [graphView convertPointToRenderingSpace:[mapper viewOriginPoint]];
    CGRect frame;
    
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        frame = CGRectMake(min.x, origin.y - AXIS_FRAME_THICKNESS/2.0f, max.x - min.x, AXIS_FRAME_THICKNESS);
        _localAxisMin = 0;
        _localAxisMax = CGRectGetWidth(frame);
        
        tickSpacingHandle.transform = CGAffineTransformIdentity;
    }
    else {  // RS_ORIENTATION_VERTICAL
        frame = CGRectMake(origin.x - AXIS_FRAME_THICKNESS/2.0f, min.y, AXIS_FRAME_THICKNESS, max.y - min.y);
        _localAxisMin = 0;
        _localAxisMax = CGRectGetHeight(frame);
        
        tickSpacingHandle.transform = CGAffineTransformMakeRotation(M_PI_2);
    }
    
    frame = CGRectStandardize(frame);
    frame = [[self stableOuterView] convertRect:frame fromView:graphView];
    self.view.frame = frame;
    
    // Update properties of the axis control handles.
    maxHandle.axis = axis;
    maxHandle.labelText = [axis formattedDataValue:[axis max]];
    
    minHandle.axis = axis;
    minHandle.labelText = [axis formattedDataValue:[axis min]];
    
    // Position the axis control handles.
    [self adjustHandlePositions];
}

- (void)adjustHandlePositions;
{
    CGPoint handlePoint;
    
    // Position the tick spacing handle.
    
    if ([axis noGridComponentsAreDisplayed] || ![axis isLinear]) {
        tickSpacingHandle.alpha = 0;
    }
    else {
        tickSpacingHandle.alpha = 1;
        
        CGFloat axisLength = fabs(_localAxisMax - _localAxisMin);
        data_p fraction = ([axis controlTick] - [axis min])/([axis max] - [axis min]);
        data_p anchorFraction = ([axis firstTick] - [axis min])/([axis max] - [axis min]);
        
        UIScrollView *scrollView = [self outerScrollView];
        CGFloat zoomScale = scrollView.zoomScale;
        CGFloat tickWidthIn = (axis.width + axis.tickWidthIn) * graphView.scale * zoomScale - 1.0f;
        CGPoint tipInset = AXIS_TICK_SPACING_KNOB_TIP_INSET;
        
        if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
            CGFloat handlePosition = fraction * axisLength * zoomScale;
            handlePoint = CGPointMake(handlePosition - tipInset.x, AXIS_FRAME_THICKNESS/2.0f*zoomScale - tickWidthIn - CGRectGetHeight(tickSpacingHandle.bounds)/2.0f + tipInset.y);
            
            _anchorTick = anchorFraction * axisLength;
        }
        else {  // RS_ORIENTATION_VERTICAL
            CGFloat handlePosition = (1 - fraction) * axisLength * zoomScale;
            handlePoint = CGPointMake(AXIS_FRAME_THICKNESS/2.0f*zoomScale + tickWidthIn + CGRectGetHeight(tickSpacingHandle.bounds)/2 - tipInset.y, handlePosition - tipInset.x);
            
            _anchorTick = (1 - anchorFraction)*axisLength;
        }
        [self setCenter:handlePoint forView:tickSpacingHandle];
    }
    
    
    //
    // Position the max handle
    _dataAxisMax = [axis max];
    
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        CGPoint centerOffset = maxHandle.centerOffset;
        handlePoint = CGPointMake(_localAxisMax + centerOffset.x, AXIS_FRAME_THICKNESS/2.0f + centerOffset.y);
    }
    else {  // RS_ORIENTATION_VERTICAL
        CGPoint centerOffset = maxHandle.centerOffset;
        handlePoint = CGPointMake(AXIS_FRAME_THICKNESS/2.0f + centerOffset.x, _localAxisMin + centerOffset.y);
    }
    //NSLog(@"max handle point: %@", NSStringFromCGPoint(handlePoint));
    [self setCenter:handlePoint forView:maxHandle];
    
    //
    // Position the min handle
    
    _dataAxisMin = [axis min];
    
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        CGPoint centerOffset = minHandle.centerOffset;
        handlePoint = CGPointMake(_localAxisMin + centerOffset.x, AXIS_FRAME_THICKNESS/2.0f + centerOffset.y);
    }
    else {  // RS_ORIENTATION_VERTICAL
        CGPoint centerOffset = minHandle.centerOffset;
        handlePoint = CGPointMake(AXIS_FRAME_THICKNESS/2.0f + centerOffset.x, _localAxisMax + centerOffset.y);
    }
    [self setCenter:handlePoint forView:minHandle];
    
    
    //
    // Potentially scroll the canvas so that the handles fit onscreen
    [self scrollToMakeHandlesFitOnScreen];
}

- (void)displayTickSpacingOverlay;
{
    data_p tickSpacing = [axis spacing];
    NSString *formattedTickSpacing = [axis formattedDataValue:tickSpacing];
    NSString *tooltipPrefix = NSLocalizedString(@"Tick spacing: ", @"Tooltip prefix when dragging the tick spacing control");
    
    // Format number and exponents
    NSAttributedString *attrFormattedValue = [[[NSAttributedString alloc] initWithString:formattedTickSpacing] autorelease];
    attrFormattedValue = [RSTextLabel formatExponentsInString:attrFormattedValue exponentSymbol:[[axis tickLabelNumberFormatter] exponentSymbol] removeLeadingOne:YES];  // Always remove any leading one
    
    NSMutableAttributedString *tooltipText = [[[NSMutableAttributedString alloc] initWithString:tooltipPrefix] autorelease];
    [tooltipText appendAttributedString:attrFormattedValue];
    
    UIView *outerView = self.view.superview.superview;
    CGPoint tooltipCenter = tickSpacingHandle.center;
    tooltipCenter = [outerView convertPoint:tooltipCenter fromView:self.view];
    tooltipCenter.y -= 70;
    
    OUIOverlayView *textOverlay = [OUIOverlayView sharedTemporaryOverlay];
    textOverlay.attributedText = tooltipText;
    [textOverlay applyDefaultTextAttributes];
    [textOverlay centerAtPoint:tooltipCenter withOffset:CGPointZero withinBounds:outerView.bounds];
    [textOverlay displayInView:outerView];
}

- (void)hideTextOverlay;
{
    [[OUIOverlayView sharedTemporaryOverlay] hide];
}

- (void)updateTickSpacing;
{
    CGFloat handlePosition;
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        handlePosition = tickSpacingHandle.center.x;
    }
    else {  // RS_ORIENTATION_VERTICAL
        handlePosition = tickSpacingHandle.center.y;
    }
    
    data_p axisRange = [axis max] - [axis min];
    CGFloat viewAxisRange = _localAxisMax - _localAxisMin;
    CGFloat viewTickSpacing = fabs(handlePosition - _anchorTick);
    data_p tickSpacing = viewTickSpacing/viewAxisRange*axisRange;
    
    tickSpacing = [axis snapTickSpacing:tickSpacing];
    
    [axis setUserSpacing:tickSpacing];
}

- (void)moveHandle:(UIView *)handleView toPosition:(CGFloat)position max:(CGFloat)maxPosition min:(CGFloat)minPosition;
{
    if (position > maxPosition)
        position = maxPosition;
    else if (position < minPosition)
        position = minPosition;
    
    CGPoint center = handleView.center;
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        center.x = position;
    }
    else {  // RS_ORIENTATION_VERTICAL
        center.y = position;
    }
    [self setCenter:center forView:handleView];
}

- (void)moveTickSpacingHandleToPosition:(CGPoint)point;
{
    CGFloat position, maxPosition, minPosition;
    
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        position = point.x;
        maxPosition = (_localAxisMax - _localAxisMin) * 0.55;
        minPosition = _anchorTick + (_localAxisMax - _localAxisMin) * 0.01;
    }
    else {  // RS_ORIENTATION_VERTICAL
        position = point.y;
        maxPosition = _anchorTick - (_localAxisMax - _localAxisMin) * 0.01;
        minPosition = (_localAxisMax - _localAxisMin) * 0.45;
    }
    
    [self moveHandle:tickSpacingHandle toPosition:position max:maxPosition min:minPosition];
}

- (void)show;
{
    //NSLog(@"showing");
    showInProgress = YES;
    
    UIView *outerView = [self stableOuterView];
    [outerView addSubview:self.view];
    
    [self update];
    
    self.view.alpha = 0;
    [UIView beginAnimations:@"show AxisController" context:NULL];
    {
        [UIView setAnimationDuration:0.2];
        self.view.alpha = 1;
    }
    [UIView commitAnimations];
    
    showInProgress = NO;  // This is just for the sake of -update, so we don't care about the animation finishing.
}

- (void)hide;
{
    if (!self.view.superview)
        return;
    
    [self restoreScrollPosition];
    
    [self.view removeFromSuperview];
}

- (void)makeHandlesInvisible;
{
    if (tickSpacingHandle.alpha == 0)
        return;
    
    [UIView beginAnimations:@"makeHandlesInvisible" context:NULL];
    {
        //[UIView setAnimationDuration:0.1];
        tickSpacingHandle.alpha = 0;
        maxHandle.alpha = 0;
        minHandle.alpha = 0;
    }
    [UIView commitAnimations];
}

- (void)makeHandlesVisible;
{
    if (tickSpacingHandle.alpha == 1)
        return;
    
    [UIView beginAnimations:@"makeHandlesVisible" context:NULL];
    {
        //[UIView setAnimationDuration:0.1];
        tickSpacingHandle.alpha = 1;
        maxHandle.alpha = 1;
        minHandle.alpha = 1;
    }
    [UIView commitAnimations];
}

- (void)startEditingEndLabel:(AxisEndHandleView *)endLabel;
{
    // Remove the tooltip overlay view (for some reason it was causing problems when bringing up the keyboard)
    [[OUIOverlayView sharedTemporaryOverlay] hideAnimated:NO];
    
    [[TextEditor currentTextEditor] confirmEditsAndEndEditing:YES];
    OBASSERT([TextEditor currentTextEditor] == nil);
    
    id <TextEditor> textEditor = [TextEditor makeEditor];
    textEditor.interpretsTabsAndNewlines = YES;
    
    textEditor.fontDescriptor = endLabel.fontDescriptor;
//    textEditor.color = endLabel.textColor;
    textEditor.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    
    NSAttributedString *text = endLabel.labelAttributedString;
    //CGPoint editorPosition = [graphView convertPoint:endLabel.textOrigin fromView:endLabel];
    CGPoint editorPosition = endLabel.textOrigin;
    
    [textEditor editString:text atPoint:editorPosition ofView:endLabel target:self object:endLabel];
    //[textEditor selectAll];
    
    // Needs to redraw w/o its own text visible.
    endLabel.isEditing = YES;
    [endLabel update];
}

- (void)performTapWithGesture:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    // Find out whether the user tapped a handle or the axis.
    UIView *activeView = self.view;
    if ([maxHandle pointInside:[gestureRecognizer locationInView:maxHandle] withEvent:nil]) {
        activeView = maxHandle;
    }
    else if ([minHandle pointInside:[gestureRecognizer locationInView:minHandle] withEvent:nil]) {
        activeView = minHandle;
    }
    
    if (activeView == self.view) {
        // If text is being edited, stop editing.
        if (![graphView isFirstResponder]) {
            [graphView stopEditingLabel];
            return;
        }
        
        // If touching axis, show edit menu on the second tap
        if (!_menuWasVisible) {
            CGPoint targetPoint = [gestureRecognizer locationInView:graphView];
            [graphView bringUpEditMenuAtPoint:targetPoint];
        }
    }
    
    else if (gestureRecognizer.gestureDuration < EDIT_MENU_DELAY) {
        OBASSERT([activeView isKindOfClass:[AxisEndHandleView class]]);
        [self startEditingEndLabel:(AxisEndHandleView *)activeView];
    }
}


#pragma mark -
#pragma mark TextEditorTarget

- (RSTextLabel *)_textLabelForAxisEndHandle:(AxisEndHandleView *)endHandle;
{
    RSTextLabel *TL = nil;
    if (endHandle == maxHandle) {
        TL = [axis maxLabel];
    } else if (endHandle == minHandle) {
        TL = [axis minLabel];
    } else {
        OBASSERT_NOT_REACHED("One of the end-label handles should have been used.");
    }
    
    return TL;
}

- (void)textEditor:(id <TextEditor>)editor textChanged:(NSAttributedString *)attributedString inObject:(id)object;
{
    OBPRECONDITION([object isKindOfClass:[AxisEndHandleView class]]);
    AxisEndHandleView *endHandle = (AxisEndHandleView *)object;
    
    // Could update the axis range in real-time, but it's dubious whether the pros outweigh the cons.
    //RSTextLabel *TL = [self _textLabelForAxisEndHandle:endHandle];
    //[graphView.editor processText:text forEditedLabel:TL];
    
    endHandle.labelText = [attributedString string];
}

- (CGPoint)textEditor:(id <TextEditor>)editor updateTextPosition:(CGPoint)currentPosition forSize:(CGSize)size inObject:(id)object;
{
    [self adjustHandlePositions];
    
    return currentPosition;
}

- (void)textEditor:(id <TextEditor>)editor confirmedText:(NSAttributedString *)text inObject:(id)object;
{
    OBPRECONDITION([object isKindOfClass:[AxisEndHandleView class]]);
    AxisEndHandleView *endHandle = (AxisEndHandleView *)object;
    
    RSTextLabel *TL = [self _textLabelForAxisEndHandle:endHandle];
    if (TL) {
        [graphView.editor processText:[text string] forEditedLabel:TL];
        [graphView.editor.undoer endRepetitiveUndo];
        [[[AppController controller] document] finishUndoGroup];
    }
    
    endHandle.isEditing = NO;
    [endHandle update];
}

- (void)textEditor:(id <TextEditor>)editor cancelledInObject:(id)object;
{
    OBPRECONDITION([object isKindOfClass:[AxisEndHandleView class]]);
    AxisEndHandleView *endHandle = (AxisEndHandleView *)object;
    
    [graphView.editor.undoer endRepetitiveUndo];
    
    // Needs to redraw w/ this label visible again.
    endHandle.isEditing = NO;
    [endHandle update];
}

- (void)textEditor:(id <TextEditor>)editor interpretedText:(NSString *)actionCharacter inObject:(id)object;
{
    // For now, end editing regardless of whether tab or return was received.
    [graphView stopEditingLabel];
}


#pragma mark -
#pragma mark Gesture recognizer target

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    // Don't let touches percolate up to the GraphView if they occurred on any part of the axis controller.
}

- (void)tickSpacingDragGesture:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        //NSLog(@"dragGesture on the tickSpacingHandle");
        
        CGPoint center = gestureRecognizer.view.center;
        CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
        
        _touchOffset = CGPointMake(touchPoint.x - center.x, touchPoint.y - center.y);
        
        [self displayTickSpacingOverlay];
        touchInProgress = YES;
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if (!gestureRecognizer.overcameHysteresis)
            return;
        
        CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
        CGPoint position = CGPointMake(touchPoint.x - _touchOffset.x, touchPoint.y - _touchOffset.y);
        
        [self moveTickSpacingHandleToPosition:position];
        [self updateTickSpacing];
        [self displayTickSpacingOverlay];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        touchInProgress = NO;
        [self hideTextOverlay];
        [self update];
    }
}

- (void)oneFingerDragGesture:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        //NSLog(@"oneFingerDragGesture");
        
        CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
        
        _downPoint = [graphView.editor.mapper convertToDataCoords:[self convertPointToViewSpace:touchPoint]];
        _axisEnd = [graphView.editor axisEndEquivalentForPoint:_downPoint onAxisOrientation:[axis orientation]];
        touchInProgress = YES;
        _menuWasVisible = [[UIMenuController sharedMenuController] isMenuVisible];
        
        [graphView displayTextOverlayForAxisEnd:_axisEnd];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if (!gestureRecognizer.overcameHysteresis)
            return;
        
        // If text is being edited, stop editing and cancel the gesture recognizer.
        if (![graphView isFirstResponder]) {
            gestureRecognizer.enabled = NO;
            [graphView stopEditingLabel];
            gestureRecognizer.enabled = YES;
            
            return;
        }
        
        [self makeHandlesInvisible];
        
        CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
        
        CGPoint viewPosition = [self convertPointToViewSpace:touchPoint];
        CGPoint viewMins = [self convertPointToViewSpace:CGPointMake(_localAxisMin, _localAxisMax)];
        CGPoint viewMaxes = [self convertPointToViewSpace:CGPointMake(_localAxisMax, _localAxisMin)];
        
        [graphView.editor dragAxisEnd:_axisEnd downPoint:_downPoint currentViewPoint:viewPosition viewMins:viewMins viewMaxes:viewMaxes];
        
        [graphView displayTextOverlayForAxisEnd:_axisEnd];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        touchInProgress = NO;
        [self hideTextOverlay];
        [self makeHandlesVisible];
        [self update];
        
        if (!gestureRecognizer.overcameHysteresis && gestureRecognizer.view == self.view) {
            // If finger did not move significantly, treat this as a tap.
            [self performTapWithGesture:gestureRecognizer];
        }
    }
}

- (void)twoFingerDragGesture:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        //NSLog(@"twoFingerDragGesture");
        
        // If text is being edited, stop editing and cancel the gesture recognizer.
        if (![graphView isFirstResponder]) {
            gestureRecognizer.enabled = NO;
            [graphView stopEditingLabel];
            gestureRecognizer.enabled = YES;
            
            return;
        }
        
        CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
        
        _viewDownPoint = touchPoint;
        touchInProgress = YES;
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if (!gestureRecognizer.overcameHysteresis)
            return;
        
        [self makeHandlesInvisible];
        
        CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
        CGFloat localDelta;
        if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
            localDelta = touchPoint.x - _viewDownPoint.x;
        } else {
            localDelta = _viewDownPoint.y - touchPoint.y;
        }

        CGFloat fraction = localDelta/(_localAxisMax - _localAxisMin);
        data_p dataDelta = fraction * (_dataAxisMax - _dataAxisMin);
        
        [axis setMin:_dataAxisMin - dataDelta];
        [axis setMax:_dataAxisMax - dataDelta];
        
        // snap ends to ticks, if close enough:
	[graphView.editor.hitTester snapAxisToGrid:axis];
        [axis setUserModifiedRange:YES];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        touchInProgress = NO;
        [self makeHandlesVisible];
        [self update];
    }
}


#pragma mark -
#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
{
    // If the text editor is up, don't force end editing unless the hit point is outside the editor.
    if ([[TextEditor currentTextEditor] hasTouchByGestureRecognizer:gestureRecognizer])
        return NO;
    
    return YES;
}


@end
