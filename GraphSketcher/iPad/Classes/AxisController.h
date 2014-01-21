// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/AxisController.h 200244 2013-12-10 00:11:55Z correia $

// The AxisController class kicks in when the user selects an axis.  It displays "handles" that lets the user change the min, max, and tick spacing.  AxisController does all of the gesture recognition and state recording to enable axis manipulation.  It creates an invisible view that covers the axis and provides touch events.  A tap outside of that invisible view deselects the axis and returns control to the RSHandTool.

#import <UIKit/UIKit.h>

#import <GraphSketcherModel/RSGraph.h> // RSAxisEnd
#import "TextEditor.h"

#define AXIS_FRAME_THICKNESS 60
#define AXIS_HANDLE_THICKNESS 13

@class GraphView, RSAxis, OUIDragGestureRecognizer, AxisEndHandleView;

@interface AxisController : UIViewController <UIGestureRecognizerDelegate, TextEditorTarget>
{
@private
    GraphView *graphView;
    RSAxis *axis;
    
    UIImageView *tickSpacingHandle;
    AxisEndHandleView *maxHandle;
    AxisEndHandleView *minHandle;
    BOOL _menuWasVisible;
    
    CGPoint _touchOffset;
    CGFloat _anchorTick;
    CGFloat _localAxisMax;
    CGFloat _localAxisMin;
    data_p _dataAxisMax;
    data_p _dataAxisMin;
    RSDataPoint _downPoint;
    CGPoint _viewDownPoint;
    RSAxisEnd _axisEnd;
    
    BOOL touchInProgress;
    BOOL showInProgress;
}

@property (nonatomic, assign) GraphView *graphView;
@property (nonatomic, assign) RSAxis *axis;

@property (nonatomic, readonly) UIImageView *tickSpacingHandle;
@property (nonatomic, readonly) UIImageView *minHandle;
@property (nonatomic, readonly) UIImageView *maxHandle;

- (id)initWithGraphView:(GraphView *)GV;

- (void)update;
- (void)adjustHandlePositions;

- (void)show;
- (void)hide;

- (void)oneFingerDragGesture:(OUIDragGestureRecognizer *)gestureRecognizer;

@end
