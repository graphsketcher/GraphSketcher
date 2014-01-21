// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/RSFillTool.h 200244 2013-12-10 00:11:55Z correia $

// RSFillTool uses a special TraceEdgesGestureRecognizer to implement the behavior where you are supposed to pause on each desired corner of the fill.  It uses a PointCreationEffect when a corner-pause is recognized. That effect is actually a subclass of RSGraphElementView.  Beyond the iPad-specific interaction techniques, the RSFillTool works much like its partner on the Mac app.

#import "RSTool.h"

@class FillDrawingView, TraceEdgesGestureRecognizer, RSFill, RSVertex, RSGraphElement;

@interface RSFillTool : RSTool
{
@private
    TraceEdgesGestureRecognizer *_traceEdgesGR;
    
    FillDrawingView *_drawingView;
    
    NSArray *_leftToolbarItems;
    NSArray *_rightToolbarItems;
    
    RSFill *_fillInProgress;
    RSVertex *_cornerInProgress;
    
    RSGraphElement *_touchedElement;
}

@property (readonly) RSFill *fillInProgress;

- (void)resetState;
- (void)discardFillInProgress;
- (BOOL)commitFillInProgress;
- (void)startNextFillCornerWithAnimation:(BOOL)animate;
- (void)fillCornerEndedAtPoint:(CGPoint)p;

@end
