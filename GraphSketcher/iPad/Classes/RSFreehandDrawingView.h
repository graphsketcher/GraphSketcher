// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// This view draws the freehand stroke in progress.

#import <UIKit/UIView.h>

@class RSFreehandStroke, OQColor, RSConnectLine, RSGraphElement;

@interface RSFreehandDrawingView : UIView
{
@private
    RSFreehandStroke *_freehand;
    OQColor *_color;
    CGFloat _thickness;
    
    RSConnectLine *_lineInProgress;
    RSGraphElement *_snappedToElement;
    
    RSDataPoint _gridSnapPoint;
}

@property(nonatomic,retain) RSFreehandStroke *freehandStroke;
@property(retain) OQColor *color;
@property(assign) CGFloat thickness;

@property (retain) RSConnectLine *lineInProgress;
@property (retain) RSGraphElement *snappedToElement;

@property (assign) RSDataPoint gridSnapPoint;
- (void)hideGridSnapPoint;

@end
