// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "GraphView.h"

#import "AppController.h"
#import "ArrowsInspectorSlice.h"
#import "AxisInspectorSlice.h"
#import "AxisTypeInspectorSlice.h"
#import "CanvasSizeInspectorSlice.h"
#import "Document.h"
#import "GridColorInspectorSlice.h"
#import "GridInspectorSlice.h"
#import "LabelDistanceInspectorSlice.h"
#import "LineInspectorSlice.h"
#import "Parameters.h"
#import "PointShapeInspectorSlice.h"
#import "PositionInspectorSlice.h"
#import "RSDrawTool.h"
#import "RSFillTool.h"
#import "RSGraphElementView.h"
#import "RSHandTool.h"
#import "ScientificNotationInspectorSlice.h"
#import "TextEditor.h"
#import "TickLabelsInspectorSlice.h"
#import "WidthInspectorSlice.h"

#import <MobileCoreServices/UTCoreTypes.h>
#import <OmniFoundation/OFPreference.h>
#import <GraphSketcherModel/RSDataImporter.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSGraph-XML.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraphElement-Rendering.h>
#import <GraphSketcherModel/RSGraphElementSelector.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSHitTester.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSVertex.h>
#import <OmniQuartz/OQColor.h>
#import <OmniUI/OUIColorInspectorSlice.h>
#import <OmniUI/OUIFontAttributesInspectorSlice.h>
#import <OmniUI/OUIFontInspectorSlice.h>
#import <OmniUI/OUIInspector.h>
#import <OmniUI/OUIOverlayView.h>
#import <OmniUI/OUIStackedSlicesInspectorPane.h>
#import <QuartzCore/CALayer.h>
#import <UIKit/UIKit.h>

RCS_ID("$Header$");

#if 0 && defined(DEBUG_robin)
    #define SHOW_FULL_DRAW_RECT 1
#else
    #define SHOW_FULL_DRAW_RECT 0
#endif

@interface GraphView (/*Private*/)
- (RSTool *)_currentTool;
@end

@implementation GraphView

//- (id)initWithFrame:(CGRect)aRect;
//{
//    if (!(self = [super initWithFrame:aRect]))
//        return nil;
//    
//    [self addSubview:_selectionView];
//    
//    return self;
//}

- (void)dealloc;
{
    [_s removeObserver:self forKeyPath:@"selection"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    _inspector.delegate = nil;
    [_inspector release];
    [_editor release];
    
    [[self _currentTool] deactivate];
    [_tools release];
    
    [_selectionView removeFromSuperview];
    [_selectionView release];
    [_s release];
    
    [_navigationItem release];
    
    [super dealloc];
}

- (void)didReceiveMemoryWarning;
{
    if (!_inspector.visible) {
        [_inspector release];
        _inspector = nil;
    }
}

@synthesize editor = _editor;
- (void)setEditor:(RSGraphEditor *)editor;
{
    if (editor == _editor)
	return;
    
    if (_editor) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        [_editor release];
        _editor = nil;
        
        [_tools release];
        _tools = nil;
        
        [pool release];  // Ensure we dealloc any lingering autoreleased objects that reference the old _graph
    }

    if (editor) {
        _editor = [editor retain];
        [_editor updateBounds:[self bounds]];
        
        if (!_s) {
            _s = [[RSGraphElementSelector alloc] init];
            [_s addObserver:self forKeyPath:@"selection" options:NSKeyValueObservingOptionNew context:NULL];
            _selectionView = [[RSGraphElementView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
            [self addSubview:_selectionView];
            _selectionView.hidden = YES;
        }
        
        // init tools
        _tools = [[NSMutableArray alloc] initWithObjects:
                  [[[RSHandTool alloc] initWithView:self] autorelease],
                  [[[RSDrawTool alloc] initWithView:self] autorelease],
                  [[[RSFillTool alloc] initWithView:self] autorelease],
#ifdef ENABLE_AXIS_TOOL
                  [[[AxisTool alloc] initWithView:self] autorelease],
#endif
                  nil];
        _toolMode = RSToolModeNone;
        self.toolMode = RSToolModeHand;
        
        [self hideGridSnapPoint];
        
#if 0
        [self updateTrackingAreas];
        [self setNeedsUpdateWhitespace];
        [self updateDisplayNow];
#endif
        [self setNeedsDisplay];
    }
    
}

@synthesize inspector = _inspector;

@synthesize selectionController = _s;
@synthesize selectionView = _selectionView;
@synthesize gridSnapPoint = _gridSnapPoint;

- (void)hideGridSnapPoint;
{
    if (_gridSnapPoint.x == DBL_MIN)
        return;
    
    _gridSnapPoint = RSDataPointMake(DBL_MIN, DBL_MIN);
    [self setNeedsDisplay];
}

@synthesize snappedToElement = _snappedToElement;
- (void)setSnappedToElement:(RSGraphElement *)element;
{
    if (_snappedToElement == element)
        return;
    
    [_snappedToElement release];
    _snappedToElement = [element retain];
    
    [self setNeedsDisplay];
}

@synthesize rectangularSelectRect = _rectangularSelectRect;
- (void)setRectangularSelectRect:(CGRect)rect;
{
    if (CGRectEqualToRect(rect, _rectangularSelectRect))
        return;
    
    _rectangularSelectRect = rect;
    [self setNeedsDisplay];
}

- (void)showInspectorFromBarButtonItem:(UIBarButtonItem *)item;
{
    if (!_inspector) {
        _inspector = [[OUIInspector alloc] initWithMainPane:nil height:INSPECTOR_POPOVER_HEIGHT];
        _inspector.delegate = self;
    }

    NSArray *objects = [[[self _currentTool] affectedObjects] allObjects];
    
    // If no selection, inspect the graph
    if ([objects count] == 0) {
        RSGraph *graph = _editor.graph;
        OBASSERT(graph);
        objects = [NSArray arrayWithObject:graph];
    }
    
    [_inspector inspectObjects:objects fromBarButtonItem:item];
}

- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
{
    [[self _currentTool] graphEditorNeedsDisplay:editor];
}

- (void)graphEditorDidUpdate:(RSGraphEditor *)editor;
{
    [[self _currentTool] graphEditorDidUpdate:editor];
}

- (void)hideSelectionAnimated:(BOOL)animated;
{
    //NSLog(@"hideSelectionAnimated");
    _selectionView.graphElement = _s.selection;
    [_selectionView hideAnimated:animated];
}

- (void)showSelectionAnimated:(BOOL)animated;
{
    //NSLog(@"showSelectionAnimated");
    _selectionView.graphElement = _s.selection;
    [_selectionView setNeedsDisplay];
    [_selectionView showAnimated:animated];
}

- (void)clearSelection;
{
    if (_s.selection) {
        _s.selection = nil;
        [self updateSelection];
    }
}

- (void)updateSelection;
{
//    if (_selectionView.graphElement == _s.selection)
//        return;
    
    if (_s.selection) {
        [self showSelectionAnimated:NO];
    } else {
        [self hideSelectionAnimated:YES];
    }
    
#ifdef ENABLE_AXIS_TOOL
    if ([_s.selection isKindOfClass:[RSAxis class]])
        self.toolMode = RSToolModeAxis;
#endif
}

@synthesize toolMode = _toolMode;
- (void)setToolMode:(RSToolMode)newToolMode;
{
    if (_toolMode == newToolMode)
        return;
    
    // Don't allow changing the mode too quickly.  We might not have finished transitioning to the new mode.  <bug://bugs/60926>
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    if (currentTime - _lastToolModeSwitch < 0.3) {
        return;
    }
    _lastToolModeSwitch = currentTime;
    
    [_inspector dismiss];
    
    // ends editing in the document title or any label.
    UIWindow *window = self.window;
    if (window) {
        if (![self isFirstResponder]) {
            [window endEditing:YES];
            [self becomeFirstResponder];
        }
    }
    
    if (_toolMode != RSToolModeNone) {
        [[self _currentTool] deactivate];
    }
    
    // Might not be set up fully yet.
    OBASSERT(!self.editor.undoer || [self.editor.undoer.undoManager isUndoRegistrationEnabled]);
    
    _toolMode = newToolMode;
    if (_toolMode != RSToolModeNone) {
        [[self _currentTool] activate];
    }
    
    [self updateNavigationItem];
}

- (void)updateNavigationItem;
{
    RSTool *currentTool = [self _currentTool];
    OBASSERT(currentTool != nil);

    self.navigationItem.leftBarButtonItems = [currentTool leftBarButtonItems];
    self.navigationItem.rightBarButtonItems = [currentTool rightBarButtonItems];
    
    NSString *toolbarTitle = [currentTool toolbarTitle];
    if (![NSString isEmptyString:toolbarTitle]) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = toolbarTitle;
        label.font = [UIFont boldSystemFontOfSize:17];
        label.textAlignment = NSTextAlignmentCenter;
        [label sizeToFit];
        
        self.navigationItem.titleView = label;
        [label release];
    } else {
        self.navigationItem.titleView = nil;
    }
}

- (void)displayTemporaryOverlayWithString:(NSString *)string avoidingTouchPoint:(CGPoint)touchPoint;
{
    UIView *superview = self.superview.superview;
    [OUIOverlayView displayTemporaryOverlayInView:superview withString:string avoidingTouchPoint:[self convertPoint:touchPoint toView:superview]];
}

- (void)displayTextOverlayForAxisEnd:(RSAxisEnd)axisEnd;
{
    RSAxis *axis = [self.editor.graph axisWithAxisEnd:axisEnd];
    NSString *tooltipPrefix;
    data_p value;
    if (axisEnd == RSAxisXMax || axisEnd == RSAxisYMax) {
        value = [axis max];
        tooltipPrefix = NSLocalizedString(@"Axis max: ", @"Tooltip prefix when dragging an axis handle");
    }
    else {
        value = [axis min];
        tooltipPrefix = NSLocalizedString(@"Axis min: ", @"Tooltip prefix when dragging an axis handle");
    }
    
    // Format number and exponents
    NSString *formattedValue = [axis formattedDataValue:value];
    NSAttributedString *attrFormattedValue = [[[NSAttributedString alloc] initWithString:formattedValue] autorelease];
    attrFormattedValue = [axis formatExponentsInString:attrFormattedValue];
    
    NSMutableAttributedString *tooltipText = [[[NSMutableAttributedString alloc] initWithString:tooltipPrefix] autorelease];
    [tooltipText appendAttributedString:attrFormattedValue];
    
    OUIOverlayView *textOverlay = [OUIOverlayView sharedTemporaryOverlay];
    textOverlay.attributedText = tooltipText;
    [textOverlay applyDefaultTextAttributes];
    
    CGSize tooltipSize = [textOverlay suggestedSize];
    CGPoint tooltipCenter = [self.editor.mapper positionOfAxisEnd:axisEnd];
    tooltipCenter = [self convertPointToRenderingSpace:tooltipCenter];
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        tooltipCenter.y -= 20;  // put it above the axis
    }
    else { // vertical axis
        tooltipCenter.x += tooltipSize.width/2.0f + 20;
        tooltipCenter.y += tooltipSize.height/2.0f;
    }
    
    UIView *outerView = self.superview;
    tooltipCenter = [outerView convertPoint:tooltipCenter fromView:self];
    
    [textOverlay centerAtPoint:tooltipCenter withOffset:CGPointZero withinBounds:outerView.bounds];
    [textOverlay displayInView:outerView];
}

- (void)displayTextOverlayForVertex:(RSVertex *)movingVertex;
{
    if (![self.editor.graph displayAxisLabels])
        return;
    
    OUIOverlayView *textOverlay = [OUIOverlayView sharedTemporaryOverlay];
    
    RSDataPoint finalPoint = [movingVertex position];
    NSString *formattedX = [self.editor.graph stringForDataValue:finalPoint.x inDimension:RS_ORIENTATION_HORIZONTAL];
    NSString *formattedY = [self.editor.graph stringForDataValue:finalPoint.y inDimension:RS_ORIENTATION_VERTICAL];
    NSString *coordString = [NSString stringWithFormat:@"x: %@  y: %@", formattedX, formattedY];
    textOverlay.text = coordString;
    
    // Convert back to touch coords
    CGPoint finalTouchPoint = [self.editor.mapper convertToViewCoords:finalPoint];
    finalTouchPoint = [self convertPointToRenderingSpace:finalTouchPoint];
    UIView *superview = self.superview.superview;
    CGPoint overlayPosition = [self convertPoint:finalTouchPoint toView:superview];
    [textOverlay centerAbovePoint:overlayPosition withinBounds:superview.bounds];
    [textOverlay displayInView:superview];
}

- (void)hideTextOverlay;
{
    [[OUIOverlayView sharedTemporaryOverlay] hide];
}

- (BOOL)letToolUndo;
// Returns YES if the tool took over undoing
{
    return [[self _currentTool] undoLastChange];
}

- (BOOL)letToolRedo;
// Returns YES if the tool took over redoing
{
    return [[self _currentTool] redoLastChange];
}

- (void)bringUpEditMenuAtPoint:(CGPoint)targetPoint;
{
    [self becomeFirstResponder];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    
    CGRect targetRect = CGRectZero;
    
    if (_s.selected) {
        targetRect = [_s.selection viewRectWithMapper:self.editor.mapper];
        targetRect = [self convertRectToRenderingSpace:targetRect];
    }
    
    // If the result is too big (or nonexistant), use the touch location
    CGSize maxObjectSize = CONTEXT_MENU_MAX_SIZE_OF_OBJECT_FOR_EXTERNAL_POSITIONING;
    if (CGRectIsEmpty(targetRect) || CGRectGetWidth(targetRect) > maxObjectSize.width || CGRectGetHeight(targetRect) > maxObjectSize.height ) {
        
        // Special case for axes
        if ([_s.selection isKindOfClass:[RSAxis class]]) {
            if (CGRectGetWidth(targetRect) > maxObjectSize.width) {
                targetRect = CGRectInset(targetRect, targetRect.size.width/2.0f, 0);
            }
            else {
                targetRect = CGRectInset(targetRect, 0, targetRect.size.height/2.0f);
            }
        }
        
        // Normal case -- use the touch location
        else {
            targetRect = CGRectMake(targetPoint.x, targetPoint.y, 0.0f, 0.0f);
        }
    }
    
    [menuController setTargetRect:targetRect inView:self];
    
    // Remember where the tap occurred (used sometimes by Paste)
    CGPoint viewPoint = [self viewPointForTouchPoint:targetPoint];
    RSDataPoint dataPoint = [self.editor.mapper convertToDataCoords:viewPoint];
    _editMenuTapPoint = dataPoint;
    
    // Add custom menu items
    [self setupCustomMenuItemsForMenuController:menuController];
    
    [menuController setMenuVisible:YES animated:YES];
}

- (BOOL)stopEditingLabel;
// Returns YES if a label was being edited and this method removed it.
{
    // Might be tapping out of editing the document title or editing a label. Don't select something while we are tapping out.
    if (![self isFirstResponder]) {
        // Make sure any editor that is working can save its edits.
        if (![self.window endEditing:NO])
            return YES;
        
        // Finally, become first responder ourselves, and now we'll start accepting hand actions.
        [self becomeFirstResponder];
        return YES;
    }
    
    return NO;
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if (object == _s) {
        //[self updateSelection];
    }
}



#pragma mark -
#pragma mark OUIScalingView subclass

- (BOOL)wantsUnflippedCoordinateSystem;
{
    return YES;
}

- (void)drawScaledContent:(CGRect)rect;
{
    //NSLog(@"graph view drawing");
    
    RSGraph *graph = _editor.graph;
    RSGraphRenderer *renderer = _editor.renderer;
    
    //NSLog(@"GV bounds: %f, %f, %f, %f", [self bounds].origin.x, [self bounds].origin.y, 
    //	[self bounds].size.width, [self bounds].size.height);
    
    // TODO: PDF output.
    BOOL isDrawingToScreen = YES;
    
    // Draw the graph background and grid lines
    OQColor *backgroundColor = [[graph backgroundColor] colorUsingColorSpace:OQColorSpaceRGB];
    if (isDrawingToScreen && [graph windowAlpha] < 1) {
        backgroundColor = [backgroundColor colorWithAlphaComponent:[graph windowAlpha]];
    }
    [renderer drawBackgroundWithColor:backgroundColor];
    
    // Draw snap-to-grid visual, if applicable
    if (isDrawingToScreen && _gridSnapPoint.x != DBL_MIN) {
        [renderer drawGridPoint:_gridSnapPoint];
    }
    
    // Draw all of the normal graph objects
    RSGraphElement *editingLabel = nil;
    if (self.toolMode == RSToolModeHand)
        editingLabel = [(RSHandTool *)[self _currentTool] editingLabel];

    [renderer drawAllGraphElementsExcept:editingLabel];
    
    // Draw snap effect, if applicable
    if (self.snappedToElement) {
        [self.editor.renderer drawHalfSelected:self.snappedToElement];
    }
    
    // Draw rectangular-select rect, if applicable
    if (!CGRectIsEmpty(_rectangularSelectRect)) {
        drawRectangularSelectRect(_rectangularSelectRect);
    }
}

- (void)scaleChanged;
{
    [super scaleChanged];
    
    // Let all the objects know about the effective scale.
    self.editor.hitTester.scale = self.scale;
    
    TextEditor *textEditor = [TextEditor currentTextEditor];
    if (textEditor.supportsFractionalFontSizes == NO)
        [self.editor.renderer informAllLabelsOfEffectiveScale:self.scale];
    
    // Reset caches that are scale-dependent
    [self.editor.mapper resetCurveCache];
    
    [[self _currentTool] viewScaleChanged];
}

- (void)scrollPositionChanged;
{
    [super scrollPositionChanged];
    
    if (_selectionView.superview) {
        [_selectionView updateFrame];
        [_selectionView setNeedsDisplay];
    }
    
    [[self _currentTool] viewScrollPositionChanged];
}

#pragma mark pseudo UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
{
    [[self _currentTool] viewScrollPositionChanged];
}

#pragma mark -
#pragma mark UIGestureRecognizerDelegate

//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
//{
//    UIScrollView *scrollView = (UIScrollView *)self.superview;
//    for (UIGestureRecognizer *recognizer in scrollView.gestureRecognizers) {
//        if (recognizer == otherGestureRecognizer) {
//            return YES;
//        }
//    }
//    
//    return NO;
//}


#pragma mark -
#pragma mark Cut/copy/paste



#pragma mark -
#pragma mark UIResponder

- (BOOL)canBecomeFirstResponder;
{
    return YES;
}

- (BOOL)_canPaste;
{
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    
    if ([pb containsPasteboardTypes:[NSArray arrayWithObject:RSGraphElementPboardType]]) {
        return YES;
    }
    
    if ([pb containsPasteboardTypes:[NSArray arrayWithObjects:(NSString *)kUTTypeUTF8PlainText, (NSString *)kUTTypePlainText, (NSString *)kUTTypeText, nil]]) {
        return YES;
    }
    return NO;
}

- (BOOL)_canConnectPoints:(RSGraphElement *)selection;
{
    if (!selection || ![selection isKindOfClass:[RSGroup class]])
        return NO;
    
    NSUInteger vertexCount = 0;
    for (RSGraphElement *GE in [(RSGroup *)selection elements]) {
        if ([GE isKindOfClass:[RSVertex class]]) {
            vertexCount += 1;
            continue;
        }
        if ([GE isKindOfClass:[RSTextLabel class]]) {
            continue;
        }
        return NO;
    }
    
    if (vertexCount >= 2)
        return YES;
    return NO;
}

- (BOOL)_canAddAxisTitle;
{
    if ([_s.selection isKindOfClass:[RSAxis class]]) {
        RSAxis *axis = (RSAxis *)_s.selection;
        if (![axis displayTitle]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)_canInterpolate:(RSGraphElement *)selection;
{
    return [selection numberOfElementsWithClass:[RSLine class]] > 0;
}

- (void)setupCustomMenuItemsForMenuController:(UIMenuController *)menuController;
{
    NSMutableArray *extraItems = [NSMutableArray array];
    
    if (_s.selected) {
        if ([_s.selection locked])
        [extraItems addObject:[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Unlock", @"edit menu") action:@selector(unlock:)] autorelease]];
        
        if ([_s.selection isLockable] && ![_s.selection locked])
            [extraItems addObject:[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Lock", @"edit menu") action:@selector(lock:)] autorelease]];
        
        if ([self _canConnectPoints:_s.selection])
            [extraItems addObject:[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Connect", @"edit menu") action:@selector(connectPoints:)] autorelease]];
        
        if ([_s.selection canBeDetached])
            [extraItems addObject:[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Detach", @"edit menu") action:@selector(detachElements:)] autorelease]];
        
        if ([self _canInterpolate:_s.selection]) {
            [extraItems addObject:[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Interpolate", @"edit menu") action:@selector(interpolateLines:)] autorelease]];
        }
        
        if ([_s.selection isKindOfClass:[RSAxis class]]) {
            [extraItems addObject:[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Show Axis Title", @"edit menu") action:@selector(editAxisTitle:)] autorelease]];
        }
        
    } else {
        if (![self _canPaste])
            [extraItems addObject:[[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Import Data", @"edit menu") action:@selector(import:)] autorelease]];
        
    }
    
    [menuController setMenuItems:extraItems];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (_s.selected) {
        if (action == @selector(delete:))
            return YES;
        if (action == @selector(copy:) && [_s.selection canBeCopied])
            return YES;
        if (action == @selector(unlock:) && [_s.selection locked])
            return YES;
        if (action == @selector(lock:) && [_s.selection isLockable] && ![_s.selection locked])
            return YES;
        if (action == @selector(connectPoints:) && [self _canConnectPoints:_s.selection])
            return YES;
        if (action == @selector(detachElements:) && [_s.selection canBeDetached])
            return YES;
        if (action == @selector(interpolateLines:) && [self _canInterpolate:_s.selection])
            return YES;
        if (action == @selector(editAxisTitle:) && [self _canAddAxisTitle])
            return YES;
        
    } else {
        if (action == @selector(selectAll:))
            return YES;
        if (action == @selector(paste:) && [self _canPaste])
            return YES;
        if (action == @selector(import:) && ![self _canPaste]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)_graphIdentifierForPasteboard;
{
    return [[[[AppController controller] document] fileURL] absoluteString];
}

- (void)writeElement:(RSGraphElement *)GE toPasteboard:(UIPasteboard *)pb;
{
    // Make sure the set of elements to copy includes all dependencies, etc.
    GE = [RSGraph prepareForPasteboard:GE];
    if (!GE)
        return;
    
    // UIPasteboard's -setData:forPasteboardType: is not incremental; it blows away anything added with a previous call.  So we have to build up a dictionary of pasteboard type/item pairs and give that to the pasteboard when we're ready.
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    // Native object data pasteboard type
    NSString *graphID = [self _graphIdentifierForPasteboard];
    NSData *xmlData = [RSGraph archivedDataWithRootObject:GE graphID:graphID error:nil];
    [dictionary setObject:xmlData forKey:RSGraphElementPboardType];
    
    // Special case for text labels
    if ( [GE isKindOfClass:[RSTextLabel class]] ) {
        // Rich text
//Not natively available on iPhone OS 3.2
//        NSAttributedString *attrString = [(RSTextLabel *)GE attributedString];
//        NSData *rtfData = [attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil];
//        [pb setData:rtfData forPasteboardType:NSRTFPboardType];
        
        // Plain text
        NSString *text = [(RSTextLabel *)GE text];
        [dictionary setObject:text forKey:@"public.utf8-plain-text"];
    }
    else {
        // Tabular and string data for other graph elements
        NSString *tabularStringRep = [RSGraph tabularStringRepresentationOfPointsIn:GE];
        if (tabularStringRep) {
            [dictionary setObject:tabularStringRep forKey:OmniDataOnlyTabularPboardType];
            [dictionary setObject:tabularStringRep forKey:@"public.utf8-plain-text"];
        }
    }
    
    // Put everything on the pasteboard itself
    [pb setItems:[NSArray arrayWithObject:dictionary]];
}

- (void)copy:(id)sender;
{
    if (![_s selected])
        return;
    
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    [self writeElement:[_s selection] toPasteboard:pb];
    
    // Copy doesn't make any changes, so there's no undo
}

- (void)cut:(id)sender;
{
    if (![_s selected])
        return;
    
    [self copy:sender];
    [self delete:sender];
    
    [[[AppController controller] document] finishUndoGroup];
}

- (void)delete:(id)sender;
{
    RSGraphElement *toDelete = [RSGraph elementsToDelete:_s.selection];
    [self.editor.graph removeElement:toDelete];
    
    // deselect
    _selectionView.graphElement = nil;
    _s.selection = nil;
    [self hideSelectionAnimated:YES];
    
    [self.editor setNeedsDisplay];
    
    [[[AppController controller] document] finishUndoGroup];
}

- (void)import:(id)sender;
{
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Importing Data", @"Alert explaining how to import data") message:NSLocalizedString(@"To import and plot data from a spreadsheet, database, or text, copy the data and paste it directly onto your graph.\n\nThe data must be in columns. If you include column headers, they will automatically be interpreted as axis titles. If the first column is descriptive labels, each label will be associated with the data point that follows. See the GraphSketcher Help for more details.", @"Alert explaining how to import data") delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Okay", @"Data import alert"), nil] autorelease];
    [alert show];
}

- (RSGraphElement *)_importElementsFromString:(NSString *)string;
{
    RSDataImporter *dataImporter = [RSDataImporter sharedDataImporter];
    RSGraphElement *everything = [dataImporter graphElementsFromString:string forGraph:_editor.graph connectSeries:YES];
    
    NSDictionary *warning = dataImporter.warning;
    if (warning) {
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:[warning valueForKey:RSDataImporterWarningTitle] message:[warning valueForKey:RSDataImporterWarningDescription] delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Okay", @"Data import alert"), nil] autorelease];
        [alert show];
    }
    
    if (!everything)
        return nil;
    
    BOOL importingData = NO;
    
    // If just a single text label, position in the center
    if ([everything isKindOfClass:[RSTextLabel class]]) {
        [_editor.renderer centerLabelInCanvas:(RSTextLabel *)everything];
    }
    else {
        importingData = YES;
    }
    
    // Add to the graph
    [_editor.graph addElement:everything];
    _s.selection = everything;
    [self updateSelection];
    
    // Auto-rescale if necessary:
    [_editor.mapper scaleAxesForNewObjects:[everything elements] importingData:importingData];
//    if (graphWasEmpty) {
//        [_editor.mapper scaleAxesToShrinkIfNecessary];
//    }
    
    if (importingData) {
	[RSDataImporter finishInterpretingStringDataForGraph:_editor.graph];
    }
    
    // Return the master group with everything in it
    return everything;
}

- (void)_pasteGraphElements;
{
    // Find out if the graph is starting out empty
    BOOL graphWasEmpty = NO;
    if( [[_editor.graph userElements] count] == 0 ) {
	graphWasEmpty = YES;
    }
    
    // Read in the RSGraphElement from the pasteboard:
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    NSData *xmlData = [pb dataForPasteboardType:RSGraphElementPboardType];
    NSString *graphID = nil;
    RSGraphElement *GE = [_editor.graph unarchiveObjectWithData:xmlData getGraphID:&graphID error:nil];
    GE = [RSGraph prepareToPaste:GE];
    
    if (!GE) {
        NSLog(@"Graph elements were not actually found on the pasteboard.");
        return;
    }
    
    // Shift position to the tap location under limited circumstances.
    BOOL pastedElementIsFromThisGraph = [graphID isEqualToString:[self _graphIdentifierForPasteboard]];
    if( pastedElementIsFromThisGraph || [GE isKindOfClass:[RSTextLabel class]]) {
        [GE setCenterPosition:_editMenuTapPoint];
    }
    
    // Actually add the new elements to the graph
    [_editor.graph addElement:GE];
    [_s setSelection:GE];
    [self updateSelection];
    
    // Auto-rescale if necessary:
    [_editor.mapper scaleAxesForNewObjects:[GE elements] importingData:NO];
    if (graphWasEmpty) {
        [_editor.mapper scaleAxesToShrinkIfNecessary];
    }
}

- (void)paste:(id)sender;
{
    if (![self _canPaste])
        return;
    
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    //NSLog(@"pasteboard types: %@", [pb pasteboardTypes]);
    
    // First, look for RSGraphElements on the pasteboard
    if ([pb containsPasteboardTypes:[NSArray arrayWithObject:RSGraphElementPboardType]]) {
        [self _pasteGraphElements];
    }
    // Second, look for text that could be imported
    else {
        // iOS 4 only works when we specify the UTF-8 UTI
        NSString *string = [pb valueForPasteboardType:(NSString *)kUTTypeUTF8PlainText];
        // iOS 5 does not work with the UTF-8 UTI
        if (!string || ![string isKindOfClass:[NSString class]]) {
            string = [pb valueForPasteboardType:(NSString *)kUTTypePlainText];
        }
        // Use rich text as a last resort
        if (!string || ![string isKindOfClass:[NSString class]]) {
            string = [pb valueForPasteboardType:(NSString *)kUTTypeText];
        }
        
        if (string && [string isKindOfClass:[NSString class]]) {
            //NSLog(@"Got a string: '%@'", string);
            [self _importElementsFromString:string];
        }
    }
    
    // OBFinishPorting: This should happen automatically due to KVO/notifications
    [_editor autoRescueTextLabels];
    [_editor setNeedsUpdateWhitespace];
    
    [[[AppController controller] document] finishUndoGroup];
}

- (void)select:(id)sender;
{
    
}

- (void)selectAll:(id)sender;
{
    _s.selection = [self.editor.graph userElements];
    [self showSelectionAnimated:YES];
}

- (void)lock:(id)sender;
{
    [[_s selection] setLocked:YES];
}

- (void)unlock:(id)sender;
{
    [[_s selection] setLocked:NO];
}

- (void)connectPoints:(id)sender;
{
    [self.editor.graph changeLineTypeOf:_s.selection toConnectMethod:defaultConnectMethod()];
}

- (void)detachElements:(id)sender;
{
    [self.editor.graph detachElements:_s.selection];
    [self.editor modelChangeRequires:RSUpdateConstraints];
}

- (void)editAxisTitle:(id)sender;
{
    OBASSERT([_s.selection isKindOfClass:[RSAxis class]]);
    if ([[self _currentTool] respondsToSelector:@selector(editLabelForElement:touchPoint:)]) {
        [(RSHandTool *)[self _currentTool] editLabelForElement:_s.selection touchPoint:CGPointZero];
    }
}

- (void)interpolateLines:(id)sender;
{
    NSArray *lines = [[_s.selection elementWithClass:[RSLine class]] elements];
    RSGroup *newSelection = [self.editor interpolateLines:lines];
    
    if (newSelection) {
        _s.selection = newSelection;
        [self showSelectionAnimated:YES];
        
        [self.editor modelChangeRequires:RSUpdateConstraints];
        [[[AppController controller] document] finishUndoGroup];
    }
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [[self _currentTool] touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [[self _currentTool] touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [[self _currentTool] touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [[self _currentTool] touchesCancelled:touches withEvent:event];
}


#pragma mark -
#pragma mark UIView

#if SHOW_FULL_DRAW_RECT
- (void)drawRect:(CGRect)r;
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGContextSaveGState(ctx);
    [super drawRect:r];
    CGContextRestoreGState(ctx);
    
    static NSUInteger drawRectCount = 0;
    
    drawRectCount++;
    
    switch (drawRectCount % 3) {
        case 0:
            [[UIColor colorWithRed:1.0 green:0.5 blue:0.5 alpha:0.15] set];
            break;
        case 1:
            [[UIColor colorWithRed:0.5 green:1.0 blue:0.5 alpha:0.15] set];
            break;
        case 2:
        default:
            [[UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:0.15] set];
            break;
    }

    CGContextFillRect(ctx, self.bounds);
}
#endif

- (void)layoutSubviews;
{
    // Unlike on the Mac, our bounds need to be pixel scaled to the device. So scaling on the iPad means we make a different bounds size and then adjust the CTM to draw w/in that bounds.
    //[_editor.mapper setBounds:[self bounds]];
    CGSize canvasSize = _editor.graph.canvasSize;
    [_editor.mapper setBounds:CGRectMake(0, 0, canvasSize.width, canvasSize.height)];
    
    [_editor prepareForDisplay];
    
    [_selectionView updateFrame];
    [_selectionView setNeedsDisplay];
    
    [super layoutSubviews];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event;
{
    // Want touches to be hit-tested against the axis handles (even if outside the canvas)
    
    for (UIView *subview in self.subviews) {
        if ([subview pointInside:[self convertPoint:point toView:subview] withEvent:event]) {
            return YES;
        }
    }
    
    return [super pointInside:point withEvent:event];
}

#pragma mark -
#pragma mark OUIInspectorDelegate

- (NSString *)inspector:(OUIInspector *)inspector titleForPane:(OUIInspectorPane *)pane;
{
    BOOL isColorPane = [pane.parentSlice isKindOfClass:[OUIColorInspectorSlice class]];
    BOOL isMainPane = [pane isKindOfClass:[OUIStackedSlicesInspectorPane class]];
    
// Font pane has good default strings
//    if ([pane.parentSlice isKindOfClass:[OUIFontInspectorSlice class]]) {
//        return NSLocalizedStringFromTableInBundle(@"Font", @"Inspectors", OMNI_BUNDLE, @"Inspector pane title");
//    }
    
    if (!isColorPane && !isMainPane) {
        return nil;
    }
    
    RSGraphElement *object = _s.selection;
    if (!object) {
        if (isColorPane) {
            return NSLocalizedStringFromTableInBundle(@"Canvas Color", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
        }
        return NSLocalizedStringFromTableInBundle(@"Canvas", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
    }
    if ([object isKindOfClass:[RSTextLabel class]]) {
        if (isColorPane) {
            return NSLocalizedStringFromTableInBundle(@"Label Color", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
        }
        return NSLocalizedStringFromTableInBundle(@"Label Style", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
    }
    if ([RSGraph isVertex:object]) {
        if (isColorPane) {
            return NSLocalizedStringFromTableInBundle(@"Point Color", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
        }
        return NSLocalizedStringFromTableInBundle(@"Point Style", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
    }
    if ([RSGraph isFill:object]) {
        if (isColorPane) {
            return NSLocalizedStringFromTableInBundle(@"Fill Color", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
        }
        return NSLocalizedStringFromTableInBundle(@"Fill Style", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
    }
    if ([RSGraph isLine:object]) {
        if (isColorPane) {
            return NSLocalizedStringFromTableInBundle(@"Line Color", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
        }
        return NSLocalizedStringFromTableInBundle(@"Line Style", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
    }
    if ([object isKindOfClass:[RSAxis class]]) {
        if (isColorPane) {
            return NSLocalizedStringFromTableInBundle(@"Axis Color", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
        }
        return NSLocalizedStringFromTableInBundle(@"Axis", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
    }
    
    // else
    if (isColorPane) {
        return NSLocalizedStringFromTableInBundle(@"Color", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
    }
    return NSLocalizedStringFromTableInBundle(@"Style", @"Inspectors", OMNI_BUNDLE, @"Inspector title");
}

- (NSArray *)inspector:(OUIInspector *)inspector makeAvailableSlicesForStackedSlicesPane:(OUIStackedSlicesInspectorPane *)pane;
{
    NSMutableArray *slices = [NSMutableArray array];
    
    [slices addObject:[[[AxisInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[LineInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[PointShapeInspectorSlice alloc] init] autorelease]];
    
    [slices addObject:[[[ArrowsInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[AxisTypeInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[WidthInspectorSlice alloc] init] autorelease]];
    
    [slices addObject:[[[OUIColorInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[TickLabelsInspectorSlice alloc] init] autorelease]];
    
    [slices addObject:[[[OUIFontAttributesInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[OUIFontInspectorSlice alloc] init] autorelease]];
    
    [slices addObject:[[[CanvasSizeInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[GridInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[GridColorInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[PositionInspectorSlice alloc] init] autorelease]];
    [slices addObject:[[[LabelDistanceInspectorSlice alloc] init] autorelease]];
    
    [slices addObject:[[[ScientificNotationInspectorSlice alloc] init] autorelease]];
        
    return [slices count] == 0 ? nil : slices;
}

- (void)inspectorDidDismiss:(OUIInspector *)inspector;
{
    [[[AppController controller] document] finishUndoGroup];
    
    [self becomeFirstResponder];
}

//- (void)inspector:(OUIInspector *)inspector wantsSelectionChanged:(id)changedSelection;
//{
//    OBASSERT([changedSelection isKindOfClass:[RSGraphElement class]]);
//    
//    _s.selection = changedSelection;
//}

#pragma mark -
#pragma mark Private

- (RSTool *)_currentTool;
{
    if (_toolMode == RSToolModeNone)
        return nil;
    
    return [_tools objectAtIndex:_toolMode];
}


@end
