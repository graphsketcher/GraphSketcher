// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSDrawTool supports (a) creating points by clicking twice in one spot, (b) creating lines by clicking at each control point, and (c) creating lines by freehand-dragging.  In that last case, an RSFreehandStroke is used to do the heavy lifting of curve beautification/simplification.

#import "RSTool.h"

@class RSConnectLine, RSVertex, RSGraphElement, RSFreehandStroke;

@interface RSDrawTool : RSTool
{
    RSConnectLine *_lineInProgress;
    RSVertex *_newDrawVertex;  // this object is temporary only
    RSVertex *_prevDrawVertex;
    RSGraphElement *_newDrawObject;
    RSVertex *_firstClickElement;
    
    RSDataPoint _startDrawPoint;
    RSDataPoint _closestGridPoint;
    
    BOOL _shouldEndDraw;
    
    // for stroke recognition
    NSDate *_timeMouseWentDown;
    RSFreehandStroke *_freehand;
}

@end
