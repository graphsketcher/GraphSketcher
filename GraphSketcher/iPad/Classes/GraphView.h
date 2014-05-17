// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// GraphView is the main OUIScalingView of the graph canvas. It is more or less analogous to the RSGraphView on the Mac app. It routes touch events to the _currentTool, so that multi-touch handling can be completely separated for each tool mode (hand, draw, fill).

#import <OmniUI/OUIScalingView.h>

#import <OmniUI/OUIInspectorDelegate.h>
#import <GraphSketcherModel/RSGraph.h> // RSAxisEnd

#if 0 && defined(DEBUG_bungi)
#define ENABLE_AXIS_TOOL
#endif

@class RSGraphEditor, RSGraphElement, RSGraphElementSelector, RSGraphElementView;
@class OUIInspector;

typedef enum _RSToolMode {
    RSToolModeNone = -1,
    RSToolModeHand,
    RSToolModeDraw,
    RSToolModeFill,
#ifdef ENABLE_AXIS_TOOL
    RSToolModeAxis,
#endif
} RSToolMode;

@interface GraphView : OUIScalingView <OUIInspectorDelegate, UIGestureRecognizerDelegate>
{
@private
    RSGraphEditor *_editor;
    
    NSMutableArray *_tools;
    RSToolMode _toolMode;
    NSTimeInterval _lastToolModeSwitch;
    
    OUIInspector *_inspector;
    
    RSGraphElementSelector *_s;
    RSGraphElementView *_selectionView;
    RSDataPoint _gridSnapPoint;
    RSGraphElement *_snappedToElement;
    CGRect _rectangularSelectRect;
    RSDataPoint _editMenuTapPoint;
}

@property(nonatomic,retain) RSGraphEditor *editor;
@property(readonly) OUIInspector *inspector;
@property(nonatomic,assign) RSToolMode toolMode;

@property (nonatomic, retain) UINavigationItem *navigationItem;
- (void)updateNavigationItem;

@property(readonly) RSGraphElementSelector *selectionController;
@property(readonly) RSGraphElementView *selectionView;
@property(nonatomic, assign) RSDataPoint gridSnapPoint;
- (void)hideGridSnapPoint;
@property(nonatomic, retain) RSGraphElement *snappedToElement;
@property(assign, nonatomic) CGRect rectangularSelectRect;

- (void)displayTemporaryOverlayWithString:(NSString *)string avoidingTouchPoint:(CGPoint)touchPoint;

- (void)showInspectorFromBarButtonItem:(UIBarButtonItem *)item;

- (void)hideSelectionAnimated:(BOOL)animated;
- (void)showSelectionAnimated:(BOOL)animated;
- (void)clearSelection;
- (void)updateSelection;

- (void)displayTextOverlayForAxisEnd:(RSAxisEnd)axisEnd;
- (void)displayTextOverlayForVertex:(RSVertex *)movingVertex;
- (void)hideTextOverlay;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

// Passed down via the RSGraphEditor's delegate.
- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
- (void)graphEditorDidUpdate:(RSGraphEditor *)editor;

- (BOOL)letToolUndo;
- (BOOL)letToolRedo;

- (void)bringUpEditMenuAtPoint:(CGPoint)targetPoint;
- (void)setupCustomMenuItemsForMenuController:(UIMenuController *)menuController;

- (BOOL)stopEditingLabel;

- (void)didReceiveMemoryWarning;

@end
