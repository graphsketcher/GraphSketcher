// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFObject.h>

#import <GraphSketcherModel/RSNumber.h>

@class RSGraphView, RSDataMapper, RSSelector, RSMode, RSGraphRenderer;
@class RSGraph, RSUndoer, RSGroup, RSGraphElement;

@interface RSTool : OFObject
{
    RSGraphView *_view;  // non-retained
    RSDataMapper *_mapper;  // non-retained
    RSGraph *_graph;  // non-retained
    RSSelector *_s;  // non-retained
    RSUndoer *_u;
    RSMode *_m;  // non-retained
    RSGraphRenderer *_renderer;  // non-retained
    
    RSDataPoint _mouseMovedPoint;
    NSPoint _viewMouseMovedPoint;
    RSDataPoint _mouseDownPoint;
    NSPoint _viewMouseDownPoint;
    RSDataPoint _mouseDraggedPoint;
    NSPoint _viewMouseDraggedPoint;
    RSDataPoint _mouseUpPoint;
    NSPoint _viewMouseUpPoint;
}

// Utility methods
+ (BOOL)commandKeyIsDown:(NSUInteger)modifierFlags;
+ (BOOL)shiftKeyIsDown:(NSUInteger)modifierFlags;
+ (BOOL)shouldStraighten:(NSUInteger)modifierFlags;

+ (RSGroup *)elementsToMove:(RSGraphElement *)GE;


- (id)initWithView:(RSGraphView *)view;


// Tool class methods
- (void)initState;


// Accessors
- (RSDataPoint)closestGridPoint;
- (BOOL)shouldDrawSelection;


// Mouse and key handling
- (void)mouseExited:(NSEvent *)event;
- (void)mouseMoved:(NSEvent *)event;
- (void)mouseDown:(NSEvent *)event;
- (void)mouseDragged:(NSEvent *)event;
- (void)mouseUp:(NSEvent *)event;
- (void)cancelOperation:(NSEvent *)event;
- (void)delete:(id)sender;
- (void)insertNewline:(id)sender;


// Actions
- (void)drawPhaseAtBeginning;
- (void)drawPhaseWithShadows;
- (void)drawPhaseAtEnd;



@end
