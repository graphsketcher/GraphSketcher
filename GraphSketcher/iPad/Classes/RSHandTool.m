// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSHandTool.h"

#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSGraphElementSelector.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSGraphElement-Rendering.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSHitTester.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSUndoer.h>

#import <OmniUI/OUIDirectTapGestureRecognizer.h>
#import <OmniUI/OUIOverlayView.h>
#import <OmniUI/OUIDragGestureRecognizer.h>
#import <OmniUIDocument/OUIDocumentAppController.h>
#import <OmniFoundation/OFPreference.h>

#import "AppController.h"
#import "Document.h"
#import "TextEditor.h"

#import "GraphView.h"
#import "RSGraphElementView.h"
#import "AxisController.h"
#import "RectangularSelectViewController.h"
#import "Parameters.h"

RCS_ID("$Header$");

@interface RSHandTool (/*Private*/)
@property (retain) RSGraphElement *touchedElement;
- (BOOL)_isTapGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
@end

@implementation RSHandTool

#pragma mark -
#pragma mark RSTool subclass

- (id)initWithView:(GraphView *)view;
{
    if (!(self = [super initWithView:view]))
        return nil;
    
    _s = [view.selectionController retain];
    OBASSERT(_s);
    [_s addObserver:self forKeyPath:@"selection" options:NSKeyValueObservingOptionNew context:NULL];
    
    return self;
}

- (void)dealloc;
{
    [_s removeObserver:self forKeyPath:@"selection"];
    [_s release];
    
    [_leftToolbarItems release];
    [_rightToolbarItems release];
    
    self.touchedElement = nil;
    self.movingElement = nil;
    self.vertexCluster = nil;
    
    [_effectView release];
    
    [_dragGR release];
    [_tapGR release];
    [_doubleTapGR release];
    [_swipeGRs release];
    
    [super dealloc];
}

- (void)viewScaleChanged;
{
    [super viewScaleChanged];
    
    if ([[TextEditor currentTextEditor] isTarget:self])
        [[TextEditor currentTextEditor] confirmEdits];
    
    [_axisController update];
}

- (void)viewScrollPositionChanged;
{
    //[_axisController update];
}

- (void)activate;
{
    [super activate];
    
    _barEndVertex = nil;
    
    if (!_dragGR) {
        _dragGR = [[OUIDragGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragGesture:)];
        _dragGR.delegate = self;
        _dragGR.holdDuration = SELECTION_DELAY;
    }
    [self.view addGestureRecognizer:_dragGR];
    
    if (!_tapGR) {
        _tapGR = [[OUIDirectTapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        _tapGR.delegate = self;
        // use default parameters: 1 tap, 1 touch
    }
    [self.view addGestureRecognizer:_tapGR];
    
    if (!_doubleTapGR) {
        _doubleTapGR = [[OUIDirectTapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTapGesture:)];
        _doubleTapGR.delegate = self;
        _doubleTapGR.numberOfTapsRequired = 2;
    }
    [self.view addGestureRecognizer:_doubleTapGR];
    
    // Swipe GRs for nudging while one finger is held down
    if (!_swipeGRs) {
        _swipeGRs = [[NSMutableArray alloc] initWithCapacity:4];
        for (NSInteger i=0; i<4; i++) {
            // Calculate direction enum based on documentation:
            NSInteger direction = 1 << i;
            UISwipeGestureRecognizer *swipeGR = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
            swipeGR.delegate = self;
            swipeGR.direction = direction;
            [_swipeGRs addObject:swipeGR];
            [swipeGR release];
        }
    }
    for (UISwipeGestureRecognizer *swipeGR in _swipeGRs) {
        [self.view addGestureRecognizer:swipeGR];
    }
    
    // Set default ivar values
    _labelIsNew = NO;
}

- (void)deactivate;
{
    [self.view removeGestureRecognizer:_dragGR];
    [self.view removeGestureRecognizer:_tapGR];
    [self.view removeGestureRecognizer:_doubleTapGR];
    for (UIGestureRecognizer *swipeGR in _swipeGRs) {
        [self.view removeGestureRecognizer:swipeGR];
    }
    
    [_rectSelectEffect release];
    _rectSelectEffect = nil;
    
    [super deactivate];
}

- (NSArray *)leftBarButtonItems;
{
    if (_leftToolbarItems == nil) {
        OUIDocumentAppController *controller = [OUIDocumentAppController controller];
        UIBarButtonItem *undoSpaceItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:NULL] autorelease];
        undoSpaceItem.width = 44;

        NSArray *items = @[
            controller.closeDocumentBarButtonItem,
            undoSpaceItem,
            controller.undoBarButtonItem,
        ];

        _leftToolbarItems = [items copy];
    }
    
    return _leftToolbarItems;
}

- (NSArray *)rightBarButtonItems;
{
    if (_rightToolbarItems == nil) {
        OUIDocumentAppController *controller = [OUIDocumentAppController controller];

        UIBarButtonItem *drawToolButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"ToolDraw.png"] style:UIBarButtonItemStylePlain target:controller action:@selector(_drawMode:)] autorelease];
        drawToolButton.width = 30 + 14;
        
        UIBarButtonItem *fillToolButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"ToolFill.png"] style:UIBarButtonItemStylePlain target:controller action:@selector(_fillMode:)] autorelease];
        fillToolButton.width = 38 + 6;

        NSArray *items = @[
            fillToolButton,
            drawToolButton,
            controller.infoBarButtonItem,
        ];

        _rightToolbarItems = [items copy];
    }
    
    return _rightToolbarItems;
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if (object == _s) {
        [self.editor.undoer endRepetitiveUndo];
        
        if ([_s.selection isKindOfClass:[RSAxis class]]) {
            if (!_axisController) {
                _axisController = [[AxisController alloc] initWithGraphView:self.view];
            }
            [_axisController show];
        }
        else {
            [_axisController hide];
        }

    }
}

#pragma mark -
#pragma mark Effects

- (void)beginTouchEffect;
{
    RSGraphElement *GE = self.touchedElement;
    
    if (_touchedSelection && ![RSGraph isVertex:GE] && ![GE isKindOfClass:[RSTextLabel class]])
        return;
    
    if (!_effectView) {
        _effectView = [[RSGraphElementView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        [self.view addSubview:_effectView];
        //_effectView.backgroundColor = [UIColor colorWithRed:1.0f green:0 blue:0 alpha:0.1f];
    }
    
    _effectView.graphElement = GE;
    _effectView.subpart = _barEndVertex ? RSGraphElementSubpartBarEnd : RSGraphElementSubpartWhole;
    
    [_effectView makeFingerSize];
    
    if (!_touchedSelection && !_dragInProgress) {
        [self.view hideSelectionAnimated:(GE == nil)];
    }
}

- (void)endTouchEffect;
{
    [_effectView makeNormalSizeAndHide:YES];
    
    if (![self editingLabel]) {
        [self.view updateSelection];
    }
    
    [_rectSelectEffect hide];

    // Done doing a drag
    [[[AppController controller] document] finishUndoGroup];
}

- (void)_performFlickDeletionWithTranslation:(CGPoint)translation;
// Translation is in touch coords
{
    // Scale translation according to zoom level
    translation.x *= self.view.scale;
    translation.y *= self.view.scale;
    
    CGRect frame = _effectView.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    frame.size.width *= 2;
    frame.size.height *= 2;
    
//    CGPoint center = [self.editor.mapper viewCenterOfElement:self.touchedElement];
//    center = CGPointMake(center.x + translation.x,
//                         center.y + translation.y);
//    NSLog(@"*** new center: %@", NSStringFromCGPoint(center));
//    
//    CGSize endSize = [self.touchedElement selectionSizeWithMinSize:CGSizeMake(RS_FINGER_WIDTH, RS_FINGER_WIDTH)];
//    endSize = CGSizeMake(endSize.width*2, endSize.height*2);
    
    [UIView beginAnimations:@"RSTouchEffectAnimation" context:NULL];
    {
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_endTouchEffectDidStop:finished:context:)];
        [UIView setAnimationDuration:FLICK_DELETION_FADE_TIME];
        
        //_effectView.frame = [self.view viewRectWithCenter:center size:endSize];
        _effectView.frame = frame;
        _effectView.alpha = 0;
    }
    [UIView commitAnimations];
}



#pragma mark -
#pragma mark Actions we can take

- (RSTextLabel *)addTextLabelAtPoint:(CGPoint)point;
// point in view coords
{
    RSDataPoint dataPoint = [self.view.editor.mapper convertToDataCoords:point];
    RSTextLabel *TL = [[RSTextLabel alloc] initWithGraph:self.view.editor.graph];
    [TL setPosition:dataPoint];
    [self.view.editor.graph addLabel:TL];
    [TL release];
    
    _labelIsNew = YES;
    
    [self.view.editor setNeedsDisplay];
    return TL;
}

- (RSTextLabel *)editingLabel;
{
    id <TextEditor> textEditor = [TextEditor currentTextEditor];
    if ([textEditor isTarget:self]) {
        OBASSERT([_s.selection isKindOfClass:[RSTextLabel class]]);
        return (RSTextLabel *)_s.selection;
    }
    return nil;
}

// Try to give a keyboard that suits the current content.  We could make this smarter... some cases to consider:
//
//   $4.00
//   3.2TeV
//   1e10
//   -4
//   (5)

static UIKeyboardType _keyboardTypeForString(NSString *string)
{
    if ([string length] == 0)
        return UIKeyboardTypeDefault;
    
    // Has a number at the beginning
    if ([string doubleValue] != 0)
        return UIKeyboardTypeNumbersAndPunctuation;

    // Only has number-like characters? Doesn't catch Yen or other currency symbols.
    static NSCharacterSet *notNumberCharacterSet = nil;
    if (!notNumberCharacterSet) {
        NSString *currencyChars = @"$¢£¤¥ƒ৲৳૱௹􏰂¤ℳ元円圆圓﷼₠₡₢₣₤₥₦₧₨₩₪₫€₭₮₯􏰀􏰁₲₳₴₵ȻGRs";
        NSString *numbersEtc = @"0123456789,.-()^%~e";
        NSString *numericalSymbols = [NSString stringWithFormat:@"%@%@", numbersEtc, currencyChars];
        notNumberCharacterSet = [[[NSCharacterSet characterSetWithCharactersInString:numericalSymbols] invertedSet] retain]; // Lame, but should be pretty darn effective
    }
    
    if ([string rangeOfCharacterFromSet:notNumberCharacterSet].location == NSNotFound)
        return UIKeyboardTypeNumbersAndPunctuation;
    
    return UIKeyboardTypeDefault;
}

- (UIKeyboardType)keyboardTypeForTextLabel:(RSTextLabel *)TL;
{
    RSGraph *graph = self.editor.graph;
    
    // For tick labels not on the end, use a regular keyboard. The assumption is that users editing these labels are doing so to make non-numeric custom labels such as "January", "Q1", "Mary".
    if ([graph isAxisTickLabel:TL] && ![graph isAxisEndLabel:TL]) {
        return UIKeyboardTypeDefault;
    }
    
    // Otherwise, base it on the text already in the label.
    return _keyboardTypeForString(TL.attributedString.string);
}

- (void)startEditingLabel:(RSTextLabel *)TL andSelectIt:(BOOL)shouldSelectAll;
{
    // Remove the tooltip overlay view (for some reason it was causing problems when bringing up the keyboard)
    [[OUIOverlayView sharedTemporaryOverlay] hideAnimated:NO];
    
    [[TextEditor currentTextEditor] confirmEditsAndEndEditing:YES];
    OBASSERT([TextEditor currentTextEditor] == nil);
    
    
    id <TextEditor> textEditor = [TextEditor makeEditor];
    textEditor.interpretsTabsAndNewlines = [TL isAxisTickLabel];
    
    textEditor.fontDescriptor = TL.fontDescriptor;
    textEditor.color = TL.color;
    
    RSDataMapper *mapper = self.editor.mapper;
    //CGFloat degrees = [TL rotation];
    
    // Drawing coordinates
    CGPoint textOrigin = [mapper convertToViewCoords:[TL position]];
    
    // UIView coordinates
    CGPoint textViewOrigin = [self.view convertPointToRenderingSpace:textOrigin];
    //NSLog(@"textRect %@ -> textViewRect %@", NSStringFromRect(textRect), NSStringFromRect(textViewRect));
    
    textEditor.keyboardType = [self keyboardTypeForTextLabel:TL];
    
    NSAttributedString *text = TL.attributedString;
    [textEditor editString:text atPoint:textViewOrigin ofView:self.view target:self object:TL];
    if(shouldSelectAll)
        [textEditor selectAll];
    
    // Needs to redraw w/o this label.
    [self.view setNeedsDisplay];
    [self endTouchEffect];
    
    [self.view hideSelectionAnimated:NO];
}

- (void)editLabelForElement:(RSGraphElement *)GE touchPoint:(CGPoint)touchPoint;
{
    RSVertex *movingVertex = [RSGraph isVertex:GE];
    RSTextLabel *labelToEdit = nil;
    RSLine *L = nil;
    if (GE) {
        if ( [GE isKindOfClass:[RSTextLabel class]] ) {
            labelToEdit = (RSTextLabel *)GE;
        }
        else if ( movingVertex ) {
            if (![movingVertex label]) {
                _labelIsNew = YES;
            }
            [self.editor.hitTester autoSetLabelPositioningForVertex:movingVertex];
            [self.editor.renderer positionLabel:nil forOwner:movingVertex];
            labelToEdit = [movingVertex label];
        }
        else if ( (L = [RSGraph isLine:GE]) ) {
            if (![L label]) {
                _labelIsNew = YES;
            }
            [self.editor.renderer positionLabel:nil forOwner:L];
            labelToEdit = [L label];
        }
//        else if ( [GE isKindOfClass:[RSFill class]] ) {
//            // This doesn't currently work, because self.touchedElement is expanded to get the fill plus its vertices
//            [self.editor.renderer positionLabel:nil forOwner:GE];
//            labelToEdit = [GE label];
//        }
        else if( [GE isKindOfClass:[RSAxis class]] ) {
            [(RSAxis *)GE setDisplayTitle:YES];
            [self.view.editor setNeedsUpdateWhitespace];
            [self.view.editor updateDisplayNow];
            labelToEdit = [(RSAxis *)GE title];
        }
    }
    if (!labelToEdit) {
        // Make a new label
        CGPoint viewPoint = [self.view viewPointForTouchPoint:touchPoint];
        viewPoint.y -= 12;
        labelToEdit = [self addTextLabelAtPoint:viewPoint];
        _s.selection = labelToEdit;
        [self startEditingLabel:labelToEdit andSelectIt:YES];
    }
    else{
        _s.selection = labelToEdit;
        [self startEditingLabel:labelToEdit andSelectIt:NO];
    }
}

- (void)moveVertex:(RSVertex *)movingVertex toPoint:(CGPoint)newPoint constrainingOrientation:(NSUInteger)orientation;
{
    // start by clearing any snapped-to objects
    [movingVertex clearSnappedTo];
    
    // resize bar, constraining to horizontal/vertical
    RSDataPoint old = [movingVertex position];
    RSDataPoint p = [self.editor.mapper convertToDataCoords:newPoint];
    RSDataPoint o;
    if( orientation == RS_ORIENTATION_VERTICAL ) {
	o.x = old.x;
	o.y = p.y;
    } else {
	o.y = old.y;
	o.x = p.x;
    }
    CGPoint oView = [self.editor.mapper convertToViewCoords:o];
    // TODO: retrieve snapped-to object
    [self.editor.hitTester snapVertex:movingVertex fromPoint:oView];
    
    // re-constrain after the snap
    [movingVertex clearSnappedTo];
    if( orientation == RS_ORIENTATION_VERTICAL ) {
	[movingVertex setPositionx:old.x];
    } else {
	[movingVertex setPositiony:old.y];
    }
}

- (void)moveVertexToPoint:(CGPoint)newPoint;
{
    if (_barEndVertex) {
        // Constrain movement parallel to the bar
        BOOL vertical = [_barEndVertex shape] == RS_BAR_VERTICAL;
        NSUInteger constrainingOrientation = vertical ? RS_ORIENTATION_VERTICAL : RS_ORIENTATION_HORIZONTAL;
        [self moveVertex:_barEndVertex toPoint:newPoint constrainingOrientation:constrainingOrientation];
        return;
    }
    
    RSVertex *movingVertex = [RSGraph isVertex:self.movingElement];
    if (![movingVertex isKindOfClass:[RSVertex class]]) {
        OBASSERT_NOT_REACHED("Shouldn't be called if the moving element is not a vertex");
        return;
    }
    
    if ([movingVertex isBar]) {
        // Constrain movement perpendicular to the bar
        BOOL vertical = [movingVertex shape] == RS_BAR_VERTICAL;
        NSUInteger constrainingOrientation = vertical ? RS_ORIENTATION_HORIZONTAL : RS_ORIENTATION_VERTICAL;
        [self moveVertex:movingVertex toPoint:newPoint constrainingOrientation:constrainingOrientation];
        return;
    }
    
    // start by clearing any snap-constraints, because user dragging overrides those
    [movingVertex setVertexCluster:self.vertexCluster];
    
    RSGraphElement *hitElement = [self.editor.hitTester snapVertex:movingVertex fromPoint:newPoint];
    if (hitElement) {
        self.view.snappedToElement = hitElement;
    } else {
        self.view.snappedToElement = nil;
    }
    
    // copy the snapped position throughout the movable vertex cluster
    RSDataPoint finalPoint = [movingVertex position];
    for (RSVertex *V in self.vertexCluster) {
        [V setPosition:finalPoint];
    }
}

- (void)updateRectangularSelectForGesture:(UIGestureRecognizer *)gestureRecognizer;
{
    CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
    CGPoint delta = CGPointMake(touchPoint.x - _touchBeganPoint.x, touchPoint.y - _touchBeganPoint.y);
    
    //NSLog(@"Rectangular select");
    CGRect rect = CGRectMake(_touchBeganPoint.x, _touchBeganPoint.y, delta.x, delta.y);
    rect = CGRectStandardize(rect);
    
    CGRect viewRect = [self.view convertRectFromRenderingSpace:rect];
    [self.view setRectangularSelectRect:viewRect];
    
    RSGraphElement *insiders = [self.editor.hitTester elementsIntersectingRect:viewRect];
    _s.selection = insiders;
    [self.view updateSelection];
    
    // Transition from the new selection view
    if (_rectSelectEffect.view.superview) {
        CGFloat exaggerationFactor = 3;
        CGRect exaggeratedRect = CGRectMake(_touchBeganPoint.x, _touchBeganPoint.y, delta.x*exaggerationFactor, delta.y*exaggerationFactor);
        [_rectSelectEffect hideToRect:CGRectStandardize(exaggeratedRect)];
    }
}

- (void)updateMovingElementWith:(RSGraphElement *)GE forGesture:(UIGestureRecognizer *)gestureRecognizer;
{
    // If user touched something in the selection, the whole selection should move.  Exception for vertices.
    if (_touchedSelection && ![RSGraph isVertex:GE]) {
        GE = _s.selection;
    }
    
    // Calculate which parts are movable
    if (GE) {
        self.movingElement = [[RSGraph elementsToMove:GE] shake];
        RSVertex *movingVertex = [RSGraph isVertex:self.movingElement];
        if (movingVertex) {
            self.vertexCluster = [movingVertex vertexCluster];
        }
    }
    else {
        self.movingElement = nil;
        self.vertexCluster = nil;
    }
    
    //if (_dragInProgress) {
        // Update the ivars that keep track of initial positioning for drags
        CGPoint viewTouchPoint = [self.view viewPointForTouchPoint:[_dragGR locationInView:self.view]];
        _v1Point = [self.editor.mapper convertToDataCoords:viewTouchPoint];
        
        CGPoint elementPoint = [self.editor.mapper convertToViewCoords:[self.movingElement position]];
        _fingerOffset = CGPointMake(viewTouchPoint.x - elementPoint.x, viewTouchPoint.y - elementPoint.y);
    //}
}

- (BOOL)updateSelectionForGesture:(UIGestureRecognizer *)gestureRecognizer;
// Updates the selection based on the touchedElement.  Returns YES if the selection was actually changed.
{
    RSGraphElement *originalSelection = _s.selection;
    
    if (!_dragInProgress) {
        _s.selection = self.touchedElement;
    }
    else {  // Secondary tap
        // Modify the selection with the touchedElement
        _s.selection = [_s.selection elementEorElement:self.touchedElement];
    }
    
    if ( (!originalSelection && !_s.selection) || [_s.selection isEqual:originalSelection]) {
        return NO;
    }

    [self updateMovingElementWith:_s.selection forGesture:gestureRecognizer];
    
    [self.view updateSelection];
    return YES;
}

/*
- (void)beginTouchAtPoint:(CGPoint)touchPoint;
{
    _menuWasVisible = [[UIMenuController sharedMenuController] isMenuVisible];
    _barEndVertex = nil;
    _draggingAxisEnd = RSAxisEndNone;
    _touchBeganPoint = touchPoint;
    
    GraphView *view = (GraphView *)self.view;
    
    CGPoint p = [view viewPointForTouchPoint:touchPoint];
    GestureLog(@"began touch at %@", NSStringFromCGPoint(p));
    
    //NSLog(@"hit testing point %@", NSStringFromPoint(p));
    RSGraphElement *GE = [view.editor.hitTester elementUnderPoint:p fromSelection:_s.selection];
    if (GE) {
        //NSLog(@"Hit element %@", GE);
        
        // Expand to select any relevant groupings, as long as a special subset is not already selected.
        if (![_s selected] || ![[_s selection] containsElement:GE]) {
            GE = [view.editor.hitTester expand:GE toIncludeGroupingsAndElementsUnderPoint:p];
        }
        self.touchedElement = GE;
        OBASSERT(self.touchedElement);
        
        // Select touched elements right away in some cases only.  <bug://bugs/59768>
        if (_s.selection && [_s.selection containsElement:self.touchedElement]) {
            _touchedSelection = YES;
        } else {
            _touchedSelection = NO;
        }
        
        if ([GE isKindOfClass:[RSVertex class]] && [self.editor.hitTester hitTestPoint:p onBarEnd:(RSVertex *)GE]) {
            _barEndVertex = (RSVertex *)GE;
        }
    }
    else {  // Nothing was hit
        self.touchedElement = nil;
        _touchedSelection = NO;
        
        if (!_dragInProgress) {  // If this is the only touch, start a rectangular selection
            if (!_rectSelectEffect) {
                _rectSelectEffect = [[RectangularSelectViewController alloc] init];
            }
            [_rectSelectEffect showAtPoint:_touchBeganPoint inView:view];
        }
    }
    
    if (!_touchedSelection || [RSGraph isVertex:self.touchedElement] || [self.touchedElement isKindOfClass:[RSTextLabel class]]) {
        [self beginTouchEffect];
    } 
//    else {
//       [self beginTouchEffectForElement:_s.selection];
//    }
}
*/

#pragma mark -
#pragma mark TextEditorTarget

- (void)_removeLabelIfEmpty:(RSTextLabel *)TL;
{
    if ([TL length] == 0) {
        [self.editor.graph removeLabel:TL];
        
        if ([_s selection] == TL) {
            _s.selection = nil;
        }
    }
}

- (void)textEditor:(id <TextEditor>)editor textChanged:(NSAttributedString *)text inObject:(id)object;
{
    OBPRECONDITION([object isKindOfClass:[RSTextLabel class]]);
    RSTextLabel *TL = (RSTextLabel *)object;
    
    // The model label positioning code assumes the label's string is updated. Would be better if we could just pass down the size.
    TL.attributedString = text;
}

- (CGPoint)textEditor:(id <TextEditor>)editor updateTextPosition:(CGPoint)currentPosition forSize:(CGSize)size inObject:(id)object;
{
    OBPRECONDITION([object isKindOfClass:[RSTextLabel class]]);

    GraphView *view = self.view;

    // Returns CoreGraphics "view" coordinates.
    RSTextLabel *TL = (RSTextLabel *)object;
    
    CGPoint pt;
    if (TL.rotation == 0) {
        pt = [self.editor updatedLocationForEditedTextLabel:TL withSize:size];
        //NSLog(@"size %@, pt = %@", NSStringFromSize(size), NSStringFromPoint(pt));
        
        // Convert to UIKit space
    } else {
        // Since our editor doesn't support rotation yet, it is weird to move its origin down the screen while editing.
        // <bug://bugs/60472> (While editing the y-axis (rotated label) the text field moves down the screen the longer the field is)
        return currentPosition;
    }
    
    return [view convertPointToRenderingSpace:pt];
}

- (void)textEditor:(id <TextEditor>)editor confirmedText:(NSAttributedString *)text inObject:(id)object;
{
    OBPRECONDITION([object isKindOfClass:[RSTextLabel class]]);
    
    [self.view showSelectionAnimated:NO];
    
    //NSLog(@"handTool got string: '%@'", text);

    RSTextLabel *TL = (RSTextLabel *)object;
    TL.attributedString = text;

    RSGraph *graph = self.editor.graph;
    if ( [graph isAxisEndLabel:TL] ) {
        [self.editor processText:[text string] forEditedLabel:TL];
    }
    else {
        [self _removeLabelIfEmpty:TL];
    }

    [self.editor.undoer endRepetitiveUndo];
    
    _labelIsNew = NO;

    // Needs to redraw w/ this label visible again.
    [self.view setNeedsDisplay];

    [[[AppController controller] document] finishUndoGroup];
}

- (void)textEditor:(id <TextEditor>)editor cancelledInObject:(id)object;
// This means editing ended without any changes having been made.
{
    [self.editor.undoer endRepetitiveUndo];
    
    // If the label was new and no changes were made, delete the label (because it was probably created by accident).
    if (_labelIsNew) {
        RSTextLabel *TL = (RSTextLabel *)object;
        [self.editor.graph removeLabel:TL];
        if (_s.selection == TL) {
            _s.selection = nil;
        }
        
        _labelIsNew = NO;
    }
    
    [self.view showSelectionAnimated:NO];
    
    // Needs to redraw w/ this label visible again.
    [self.view setNeedsDisplay];
}

- (void)textEditor:(id <TextEditor>)editor interpretedText:(NSString *)actionCharacter inObject:(id)object;
{
//    RSTextLabel *TL = (RSTextLabel *)object;
//    
//    // If it was a tab, start editing the next label
//    if (OFISEQUAL(actionCharacter, @"\t")) {
//        RSTextLabel *next = [self.editor.renderer nextLabel:TL];
//        if (next) {
//            [self.view.window endEditing:NO];
//            _s.selection = next;
//            [self startEditingLabel:next];
//        }
//    }
//    // If it was a return or other control character, simply end editing.
//    else {
        [self.view stopEditingLabel];
//    }
}

#pragma mark -
#pragma mark Touch handling

@synthesize touchedElement = _touchedElement;
@synthesize movingElement = _movingElement;
@synthesize vertexCluster = _vertexCluster;

- (NSSet *)affectedObjects;
{
    RSGraphElement *element = _s.selection;
    
    if (!element)
        return nil;
    
    // Hack for <bug://bugs/60490>. Maybe should change how inspectors work instead. 
    RSFill *F = [RSGraph isFill:element];
    if (F) {
        return [NSSet setWithObject:F];
    }

    
    // If multi-selection, inspect all together
    if ([element isKindOfClass:[RSGroup class]]) {
        NSMutableSet *set = [NSMutableSet setWithCapacity:[(RSGroup *)element count]];
        for (RSGraphElement *GE in [(RSGroup *)element elements]) {
            [set addObject:GE];
        }
        return set;
    }
    
    // Single selection
    return [NSSet setWithObject:element];
}

- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
{
    // Don't redraw the graph if we're editing a text label
    if ([self editingLabel])
        return;
    
    [super graphEditorNeedsDisplay:editor];
}

- (void)graphEditorDidUpdate:(RSGraphEditor *)editor;
{
    [_axisController update];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    _menuWasVisible = [[UIMenuController sharedMenuController] isMenuVisible];
    
    // If this touch is for the editor, then it isn't for us.
    id <TextEditor> textEditor = [TextEditor currentTextEditor];
    for (UITouch *touch in touches) {
        if ([textEditor hasTouch:touch]) {
            return;
        }
    }
    
    // No longer calling -[UIView endEditing:] here since that would clear our first responder status too. 
    if (![self.view isFirstResponder]) {
        // Our response to a tap will make us first responder -- don't do it here since we need one place to handle it and the tap gets called last, it seems.
        return;
    }
    
    // Hide the contextual menu if it is visible
    if (_menuWasVisible) {
        [[UIMenuController sharedMenuController] setMenuVisible:NO animated:YES];
    }
    
    _barEndVertex = nil;
    _draggingAxisEnd = RSAxisEndNone;
    
    GraphView *view = (GraphView *)self.view;
        
    UITouch *touch = [touches anyObject];
    CGPoint p = [view viewPointForTouchPoint:[touch locationInView:view]];
    GestureLog(@"hand touch began at %@", NSStringFromCGPoint(p));
    
    _touchBeganPoint = [touch locationInView:view];
    
    //NSLog(@"hit testing point %@", NSStringFromPoint(p));
    RSGraphElement *GE = [view.editor.hitTester elementUnderPoint:p fromSelection:_s.selection];
    if (GE) {
        //NSLog(@"Hit element %@", GE);
        
        // Expand to select any relevant groupings, as long as a special subset is not already selected.
        if (![_s selected] || ![[_s selection] containsElement:GE]) {
            GE = [view.editor.hitTester expand:GE toIncludeGroupingsAndElementsUnderPoint:p];
        }
        self.touchedElement = GE;
        OBASSERT(self.touchedElement);
        
        // Select touched elements right away in some cases only.  <bug://bugs/59768>
        if (_s.selection && [_s.selection containsElement:self.touchedElement]) {
            _touchedSelection = YES;
        } else {
            _touchedSelection = NO;
        }
        
        if ([GE isKindOfClass:[RSVertex class]] && [self.editor.hitTester hitTestPoint:p onBarEnd:(RSVertex *)GE]) {
            _barEndVertex = (RSVertex *)GE;
        }
    }
    else {  // Nothing was hit
        self.touchedElement = nil;
        _touchedSelection = NO;
        
        if (!_dragInProgress) {  // If this is the only touch, start a rectangular selection
            if (!_rectSelectEffect) {
                _rectSelectEffect = [[RectangularSelectViewController alloc] init];
            }
            [_rectSelectEffect showAtPoint:_touchBeganPoint inView:view];
        }
    }
    
    [self beginTouchEffect];
    
}

//- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
//{
//    [super touchesMoved:touches withEvent:event];
//    
//}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesEnded:touches withEvent:event];
    GestureLog(@"hand touch ended");
  
    if (_dragInProgress) {  // Ignore stray touches
        return;
    }
    
    [self endTouchEffect];
    
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
// This usually means that a gesture recognizer took over handling the touch events
{
    [super touchesCancelled:touches withEvent:event];
    GestureLog(@"hand touch cancelled");
    
    // If no gesture recognizer took over, or a discrete recognizer did, we need to cancel the touch effect here.
    if (!_dragInProgress) {
        [self endTouchEffect];
    }
}



#pragma mark -
#pragma mark Gesture handling

- (void)gestureDragBegan:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    if (_dragInProgress) {
        NSLog(@"Error. Multiple move gestures recognizing at once?");
        return;
    }
    
    // If text is being edited, stop editing and cancel the gesture recognizer.
    if (![self.view isFirstResponder]) {
        gestureRecognizer.enabled = NO;
        [self.view stopEditingLabel];
        gestureRecognizer.enabled = YES;
        
        return;
    }
    
    _modelChanged = NO;
    
    // Select touched elements right away in some cases only.  <bug://bugs/59768>  <bug://bugs/60839>
    if (!_touchedSelection) {
        [self updateSelectionForGesture:gestureRecognizer];
    }
    else {
        [self updateMovingElementWith:self.touchedElement forGesture:gestureRecognizer];
    }
    
    RSVertex *movingVertex = [RSGraph isVertex:self.movingElement];
    if (movingVertex) {
        // Display coordinates in an overlay
        [self.view displayTextOverlayForVertex:movingVertex];
    }
    
    _rectangularSelect = !self.touchedElement;
    
    _dragInProgress = YES;
    _startedDragging = NO;  // have not yet overcome hysteresis
}

- (void)gestureDragChanged:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    // Must overcome hysteresis
    if (!gestureRecognizer.overcameHysteresis) {
        return;
    }
    
    // Let the AxisController handle axis dragging
    if ([_s.selection isKindOfClass:[RSAxis class]]) {
        if (_effectView.alpha)
            [_effectView hideAnimated:NO];
        return;
    }
    
    if (_rectangularSelect) {
        [self updateRectangularSelectForGesture:gestureRecognizer];
        return;
    }
    
    // Move selected elements
    CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
    CGPoint viewPoint = [self.view viewPointForTouchPoint:touchPoint];
    CGPoint newPoint = CGPointMake(viewPoint.x - _fingerOffset.x,
                                   viewPoint.y - _fingerOffset.y);
    //NSLog(@"touch moved to %@", NSStringFromCGPoint(newPoint));
    RSDataPoint dataPoint = [self.editor.mapper convertToDataCoords:newPoint];
    
    // Vertex dragging
    RSVertex *movingVertex = [RSGraph isVertex:self.movingElement];
    if (movingVertex) {
        [self moveVertexToPoint:newPoint];
        
        // Display coordinates in an overlay
        [self.view displayTextOverlayForVertex:movingVertex];
        
        // Set up snap-to-grid visualization
        if (![self.editor.graph noGridComponentsAreDisplayed]) {
            self.view.gridSnapPoint = [movingVertex position];
        }
        
        [_effectView updateFrame];
        [_effectView setNeedsDisplay];
    }
    
    // Axis tick label dragging
    else if ([self.editor.graph isAxisTickLabel:self.touchedElement]) {
        //NSLog(@"drag tick label");
        if (_draggingAxisEnd == RSAxisEndNone) {
            _draggingAxisEnd = [self.editor axisEndEquivalentForPoint:_v1Point onAxisOrientation:[(RSTextLabel *)self.touchedElement axisOrientation]];
            _viewMins = [self.editor.mapper viewMins];
            _viewMaxes = [self.editor.mapper viewMaxes];
        }
        CGPoint p = [self.view viewPointForTouchPoint:[gestureRecognizer locationInView:self.view]];
        
        [self.editor dragAxisEnd:_draggingAxisEnd downPoint:_v1Point currentViewPoint:p viewMins:_viewMins viewMaxes:_viewMaxes];
        [self.view displayTextOverlayForAxisEnd:_draggingAxisEnd];
        
        if (_effectView.alpha)
            [_effectView hideAnimated:YES];
    }
    
    // Regular text label dragging
    else if ([self.movingElement isKindOfClass:[RSTextLabel class]] && ![self.movingElement isPartOfAxis]) {
        RSTextLabel *movingLabel = (RSTextLabel *)self.movingElement;
        if (!_startedDragging) {
            [self.editor.hitTester beginDraggingLabel:movingLabel];
        }
        
        [movingLabel setPosition:dataPoint];
        self.view.snappedToElement = [self.editor.hitTester snapLabel:movingLabel toObjectsNear:viewPoint];
        
        if (_effectView.alpha)
            [_effectView hideAnimated:YES];
    }
    
    // Dragging anything else
    else {
        // If there is no moving element and no special cases above applied, the object is for all intents and purposes locked.
        if (self.touchedElement && !self.movingElement) {
            [self.view displayTemporaryOverlayWithString:NSLocalizedString(@"Object is locked", @"Overlay message when objects can't be moved.") avoidingTouchPoint:[gestureRecognizer locationInView:self.view]];
            return;
        }
        
        // If there is a moving element but no special cases applied, move the element normally.
        [self.editor.mapper moveElement:self.movingElement toPosition:dataPoint];
        
        if (_effectView.alpha)
            [_effectView hideAnimated:NO];
    }
    
    [self.view hideSelectionAnimated:YES];
    
    _startedDragging = YES;
    
//    
//    [self hideIconMenu];
//    [self updateResizeHandles];
}

- (void)gestureDragEnded:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    _dragInProgress = NO;
    
    
    // <bug://bugs/59607> (Temporarily disable flick (swipe) delete)
#if 0
    if (self.touchedElement && gestureRecognizer.velocity > FLICK_DELETION_VELOCITY) {
        CGPoint direction = gestureRecognizer.direction;
        CGFloat velocity = gestureRecognizer.velocity;
        CGPoint translation = CGPointMake(direction.x*velocity*FLICK_DELETION_FADE_TIME,
                                          direction.y*velocity*FLICK_DELETION_FADE_TIME);
        //NSLog(@"Flick-delete with direction: %@; translation: %@; old translation: %@", NSStringFromCGPoint(direction), NSStringFromCGPoint(translation), NSStringFromCGPoint(gestureRecognizer.translation));
        
        [self _performFlickDeletionWithTranslation:translation];
        
        _s.selection = nil;
        [self.view.editor.graph removeElement:self.touchedElement];
        [self.view.editor setNeedsDisplay];
        return;
    }
#endif
    
    
    // Bring up edit menu if the finger was down long enough before releasing, and didn't move in the meantime
    if (![self editingLabel] && ![gestureRecognizer overcameHysteresis] && !_modelChanged) {
        if (gestureRecognizer.gestureDuration > EDIT_MENU_DELAY) {
            CGPoint targetPoint = [gestureRecognizer locationInView:self.view];
            [self.view bringUpEditMenuAtPoint:targetPoint];
        }
        else {
            // Treat this as a tap
            [self performTap:gestureRecognizer];
        }
    }
    
    // Clear out snap visualizations
    [self.view hideGridSnapPoint];
    self.view.snappedToElement = nil;
    
    if (_draggingAxisEnd != RSAxisEndNone) {
        [[OUIOverlayView sharedTemporaryOverlay] hide];
    }
    
    if (_rectangularSelect) {
        [self.view setRectangularSelectRect:CGRectZero];
    }
    
    [self endTouchEffect];
    [self.view hideTextOverlay];
    
//    
//    [self showIconMenu];
}

- (void)performTap:(UIGestureRecognizer *)gestureRecognizer;
{
    GestureLog(@"performTap");
    
    BOOL selectionChanged = [self updateSelectionForGesture:gestureRecognizer];
    
    if (_dragInProgress) {
        // Reset hysteresis for dragging further
        [_dragGR resetHysteresis];
    }
    else {
        // Bring up contextual menu if the tap didn't change the selection, and the menu wasn't already visible.
        if (!selectionChanged && !_menuWasVisible) {
            CGPoint targetPoint = [gestureRecognizer locationInView:self.view];
            [self.view bringUpEditMenuAtPoint:targetPoint];
        }
    }
}

- (void)performNudge:(UISwipeGestureRecognizer *)gestureRecognizer;
{
    UISwipeGestureRecognizerDirection direction = [gestureRecognizer direction];
    
    // Calculate the nudge delta
    CGPoint delta = CGPointZero;
    CGFloat nudgeDistance = 1.0/self.editor.hitTester.scale;
    switch (direction) {
        case UISwipeGestureRecognizerDirectionRight:
            delta.x = nudgeDistance;
            break;
        case UISwipeGestureRecognizerDirectionLeft:
            delta.x = -nudgeDistance;
            break;
        case UISwipeGestureRecognizerDirectionUp:
            delta.y = nudgeDistance;
            break;
        case UISwipeGestureRecognizerDirectionDown:
            delta.y = -nudgeDistance;
            break;
        default:
            break;
    }
    
    // Apply the nudge
    [self.editor.mapper shiftElement:self.movingElement byDelta:delta];
    
    // Update overlay
    RSVertex *movingVertex = [RSGraph isVertex:self.movingElement];
    if (movingVertex) {
        [self.view displayTextOverlayForVertex:movingVertex];
    }
    
    // This should probably be automatic (i.e. get set by the undo mechanism).  For now, just used for suppressing the contextual menu.
    _modelChanged = YES;
    
    // Reset hysteresis for dragging further
    [_dragGR resetHysteresis];
}

#pragma mark -

- (void)resetSecondaryGestureRecognizers;
// In order for simple gesture recognizers to function simultaneously while another finger is already down, they need to ignore that finger.  The best way I've managed to achieve this is to wait until another gesture recognizer has claimed the original touches, and then disable and immediately re-enable the gesture recognizers whose internal state we want to reset.  (FWIW, it also works to import UIGestureRecognizerSubclass.h and call -reset.)
{
    NSMutableArray *secondaryGRs = [NSMutableArray array];
    [secondaryGRs addObject:_tapGR];
    //this disabled normal double-tap//[secondaryGRs addObject:doubleTapGR];
    [secondaryGRs addObjectsFromArray:_swipeGRs];
    
    for (UIGestureRecognizer *GR in secondaryGRs) {
        GR.enabled = NO;
        GR.enabled = YES;
    }
}

- (void)handleDragGesture:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        GestureLog(@"%.2f drag gesture began", [gestureRecognizer holdDuration]);
        [self gestureDragBegan:gestureRecognizer];
        
        [self resetSecondaryGestureRecognizers];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        GestureLog(@"%.2f drag gesture changed", [gestureRecognizer holdDuration]);
        [self gestureDragChanged:gestureRecognizer];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        GestureLog(@"%.2f drag gesture ended", [gestureRecognizer holdDuration]);
        [self gestureDragEnded:gestureRecognizer];
    }
    
    // If user touched and held on an axis, transfer drag handling to the axis controller.
    if ([_s.selection isKindOfClass:[RSAxis class]]) {
        //_s.selection = self.touchedElement;
        [_axisController oneFingerDragGesture:gestureRecognizer];
        //return;
    }
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gestureRecognizer;
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        GestureLog(@"tap gesture recognized");
        
        // Might be tapping out of editing the document title or editing a label. Don't select something while we are tapping out.
        if (![self.view isFirstResponder]) {
            [self.view stopEditingLabel];
            return;
        }

        [self performTap:gestureRecognizer];
        [self endTouchEffect];
        
        return;
    }
}

- (void)handleDoubleTapGesture:(UITapGestureRecognizer *)gestureRecognizer;
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        GestureLog(@"doubleTap gesture recognized");
        
        RSGraphElement *GE = self.touchedElement;
        CGPoint touchPoint = [gestureRecognizer locationInView:self.view];
        [self editLabelForElement:GE touchPoint:touchPoint];
        
        return;
    }
}

- (void)handleSwipeGesture:(UISwipeGestureRecognizer *)gestureRecognizer;
{
    GestureLog(@"handleSwipeGesture");
    
    if (!_s.selected) {
        GestureLog(@"Does nudge gesture applied to the canvas mean something?");
        return;
    }
    
    [self performNudge:gestureRecognizer];
}


#pragma mark -
#pragma mark OUIGestureDelegate

//- (void)gesture:(OUIGestureRecognizer *)recognizer likelihoodDidChange:(CGFloat)likelihood;
//{
//    GestureLog(@"<%@ %p> has likelihood %f", [recognizer class], recognizer, likelihood);
//    if ( recognizer != _dragGR ) {
//        return;
//    }
//    
//    if (likelihood > 0 && likelihood < 1) {
//        //[self beginTouchAtPoint:[_dragGR firstTouchPointInView:self.view]];
//        
//        if (!self.touchedElement) {
//            if (!_rectSelectEffect) {
//                _rectSelectEffect = [[RectangularSelectViewController alloc] init];
//            }
//            [_rectSelectEffect showAtPoint:_touchBeganPoint inView:self.view];
//        }
//        
//        [self beginTouchEffect];
//    }
//    else if (likelihood == 0) {
//        [self endTouchEffect];
//    }
//}


#pragma mark -
#pragma mark UIGestureRecognizerDelegate

- (BOOL)_isTapGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
{
    return (gestureRecognizer == _tapGR || gestureRecognizer == _doubleTapGR);
}

- (BOOL)_isDragGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
{
    return (gestureRecognizer == _dragGR);
}

- (BOOL)_isNudgeGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
{
    return ([gestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]]);
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
{
    // If the text editor is up, don't force end editing unless the hit point is outside the editor.
    if ([[TextEditor currentTextEditor] hasTouchByGestureRecognizer:gestureRecognizer])
        return NO;
    
    if (gestureRecognizer == _dragGR) {
        // Specify when to allow immediate drag
        if ([_dragGR completedHold] || _touchedSelection) {
            return YES;
        }
        return NO;
    }
    
    if ([self _isNudgeGestureRecognizer:gestureRecognizer]) {
        // Only use swipes for nudging when another finger is already down.
        return _dragInProgress;
    }
    
    if (gestureRecognizer == _doubleTapGR) {
        return !_dragInProgress;
    }
    
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
{
    // Tapping while dragging
    if ([self _isTapGestureRecognizer:gestureRecognizer] && [self _isDragGestureRecognizer:otherGestureRecognizer]) {
        return YES;
    }
    
    // Nudging while dragging
    else if ([self _isNudgeGestureRecognizer:gestureRecognizer] && [self _isDragGestureRecognizer:otherGestureRecognizer]) {
        return YES;
    }
    
    return NO;
}

@end
