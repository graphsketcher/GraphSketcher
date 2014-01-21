// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/RSHandTool.h 200244 2013-12-10 00:11:55Z correia $

// RSHandTool is the main default mode where you can select and adjust graph elements and double-tap to edit text labels. It employs an RSGraphElementView to get the expanding selection outline when the user presses down on a vertex or text label.  The gesture setup is similar to Graffle-iPad though not identical. We use the same technique of "secondary" gesture recognizers to handle a tap or swipe while another finger is already being held down. That first finger is the _dragInProgress.

#import "RSTool.h"

#import <GraphSketcherModel/RSGraph.h> // RSAxisEnd
#import "TextEditor.h"

#define FLICK_DELETION_VELOCITY 400  // ending velocity cutoff, in pixels per second
#define FLICK_DELETION_FADE_TIME 0.5  // seconds during which flick deletion effect occurs

@class RSGraphElement, RSGraphElementSelector, RSGraphElementView, RSTextLabel, RSVertex;
@class AxisController, RectangularSelectViewController;
@class OUIDirectTapGestureRecognizer, OUIDragGestureRecognizer;

@interface RSHandTool : RSTool <TextEditorTarget, UIGestureRecognizerDelegate>
{
@private
    OUIDragGestureRecognizer *_dragGR;
    OUIDirectTapGestureRecognizer *_tapGR;
    OUIDirectTapGestureRecognizer *_doubleTapGR;
    NSMutableArray *_swipeGRs;
    
    RSGraphElementSelector *_s;  // non-retained
    
    NSArray *_leftToolbarItems;
    NSArray *_rightToolbarItems;
    
    CGPoint _touchBeganPoint;
    CGPoint _fingerOffset;
    RSDataPoint _v1Point;
    RSGraphElement *_touchedElement;
    RSGraphElement *_movingElement;
    NSArray *_vertexCluster;
    BOOL _menuWasVisible;
    RSVertex *_barEndVertex;
    RSAxisEnd _draggingAxisEnd;
    CGPoint _viewMins;
    CGPoint _viewMaxes;
    
    BOOL _dragInProgress;
    BOOL _startedDragging;
    BOOL _touchedSelection;
    BOOL _modelChanged;
    BOOL _rectangularSelect;
    BOOL _labelIsNew;
    
    RSGraphElementView *_effectView;
    AxisController *_axisController;
    RectangularSelectViewController *_rectSelectEffect;
}

@property (retain) RSGraphElement *movingElement;
@property (retain) NSArray *vertexCluster;

- (RSTextLabel *)addTextLabelAtPoint:(CGPoint)point;
- (void)editLabelForElement:(RSGraphElement *)GE touchPoint:(CGPoint)touchPoint;
- (RSTextLabel *)editingLabel;

- (void)performTap:(UIGestureRecognizer *)gestureRecognizer;

@end
