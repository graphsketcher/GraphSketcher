// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSDrawTool is very similar to RSDrawTool on the Mac.  For the freehand-drawing method of creating lines, it uses a transparent RSFreehandDrawingView to display a stroke while it is being drawn. As before, an RSFreehandStroke in the Model framework does the heavy lifting of curve beautification.  For the line-creation method where you tap on each desired control point, RSDrawTool uses a PulsingPointView to indicate the most recent control point that was created.  Tapping that point again ends the line. PulsingPointView is similar to RSGraphElementView and they could probably be combined into one class with a few new attributes.

#import "RSTool.h"

@class RSGraphElement, RSFreehandStroke, RSFreehandDrawingView, RSVertex, RSConnectLine, OUIDragGestureRecognizer, PulsingPointView, RSGraphElementView;

@interface RSDrawTool : RSTool
{
@private
    OUIDragGestureRecognizer *_drawStrokeGR;
    //UITapGestureRecognizer *_tapGR;
    UIPanGestureRecognizer *_moveGR;
    
    NSArray *_leftToolbarItems;
    NSArray *_rightToolbarItems;
    
    RSFreehandStroke *_freehand;
    NSTimeInterval _touchBeganTimestamp;
    
    RSGraphElement *_touchedElement;
    CGPoint _fingerOffset;
    RSVertex *_pulsingVertex;
    RSVertex *_vertexInProgress;
    RSConnectLine *_lineInProgress;
    NSArray *_vertexCluster;
    RSGraphElement *_addedElement;
    
    BOOL _pulsing;
    BOOL _shouldEndLine;
    
    RSFreehandDrawingView *_drawingView;
    PulsingPointView *_pulsingView;
    RSGraphElementView *_fingerView;
}

@property (nonatomic, retain) RSFreehandStroke *freehand;
@property (retain) RSVertex *pulsingVertex;
@property (retain) RSVertex *vertexInProgress;
@property (retain) RSConnectLine *lineInProgress;
@property (retain) NSArray *vertexCluster;
@property (retain) RSGraphElement *addedElement;

- (void)tapTouchEnded;
- (void)resetState;

@end
