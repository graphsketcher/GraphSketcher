// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// Snapping functionality is a category on RSHitTester because the implementation is based on hit testing. Snapping works by first doing hit testing around the point being dragged, and then snapping the point to any valid snap target that may have been found.  There is some caching to improve performance for complex curved lines.

#import <GraphSketcherModel/RSHitTester.h>

@class RSAxis, RSGraphElement, RSVertex;

typedef enum _RSSnapBehavior {
    RSSnapBehaviorNone = 0,
    RSSnapBehaviorRegular = 1,
    RSSnapBehaviorShiftKey = 2,
} RSSnapBehavior;


@interface RSHitTester (Snapping)

// Some of the relevant methods are in RSDataMapper

// Snapping points //

// Snap to grid
- (void)snapAxisToGrid:(RSAxis *)A;
- (void)snapAxisToGrid:(RSAxis *)A viewMin:(CGFloat)viewMin viewMax:(CGFloat)viewMax;
- (BOOL)snapAxisEndToGrid:(RSAxisEnd)axisEnd viewMin:(CGFloat)viewMin viewMax:(CGFloat)viewMax;


// High-level methods for vertex snapping
- (RSGraphElement *)snapVertex:(RSVertex *)movingVertex fromPoint:(CGPoint)p;
- (RSGraphElement *)snapVertex:(RSVertex *)movingVertex fromPoint:(CGPoint)p behavior:(RSSnapBehavior)behavior;
- (RSGraphElement *)snapVertex:(RSVertex *)movingVertex fromPoint:(CGPoint)p behavior:(RSSnapBehavior)behavior prevVertex:(RSVertex *)prevVertex nextVertex:(RSVertex *)nextVertex;


// Maintaining snap-constraints
- (void)updateSnappedTos;
- (void)updateSnappedTosForVertices:(NSArray *)vertices;


// Snapping Labels to objects
- (void)autoSetLabelPositioningForVertex:(RSVertex *)V;
- (CGFloat)snapAngleToCorners:(CGFloat)rad;  // in radians
- (CGFloat)snapPercentage:(CGFloat)val toCenterOfLength:(CGFloat)length;
- (void)beginDraggingLabel:(RSTextLabel *)label;
- (RSGraphElement *)snapLabel:(RSTextLabel *)label toObjectsNear:(CGPoint)draggedPoint;

@end
