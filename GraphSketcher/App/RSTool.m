// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSTool.h"

#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSHitTester.h>

#import "RSGraphView.h"
#import "RSSelector.h"
#import "RSMode.h"


@implementation RSTool


///////////
#pragma mark -
#pragma mark Utility methods
///////////

+ (BOOL)commandKeyIsDown:(NSUInteger)modifierFlags {
    if ( modifierFlags & NSCommandKeyMask )
	return YES;
    else  return NO;
}
+ (BOOL)shiftKeyIsDown:(NSUInteger)modifierFlags {
    if ( modifierFlags & NSShiftKeyMask )
	return YES;
    else  return NO;
}
+ (BOOL)shouldStraighten:(NSUInteger)modifierFlags {
    if ( modifierFlags & NSShiftKeyMask )  return YES;
    if ( modifierFlags & NSCommandKeyMask )  return YES;
    // if got this far
    return NO;
}

+ (RSGroup *)elementsToMove:(RSGraphElement *)GE;
{
    if (!GE)
        return nil;
    
    // make a new group
    RSGroup *movers = [RSGroup groupWithGraph:[GE graph]];
    
    // Special case if this is a single vertex.
    // Return the the whole cluster, but only if nothing in it is locked. <bug://bugs/53616>
    if ([GE isKindOfClass:[RSVertex class]]) {
	NSArray *cluster = [(RSVertex *)GE vertexCluster];
	for (RSVertex *V in cluster) {
	    if ( [V locked] || ![V isMovable])
                return nil;
	    
	    [movers addElement:V];
	}
	return movers;
    }
    
    // turn single elements into a group
    if( ![GE isKindOfClass:[RSGroup class]] ) {
	[movers addElement:GE];
	
	return [RSTool elementsToMove:movers];
    }
    
    for (RSGraphElement *obj in [(RSGroup *)GE elements]) {
	if ([obj isKindOfClass:[RSVertex class]]) {
	    
	    if ([(RSVertex *)obj isConstrained] || [obj locked] || ![obj isMovable])
		continue;
	    
            // Do not return vertex clusters containing any locked components. <bug://bugs/53616>
            BOOL isMovable = YES;
            for (RSVertex *V in [(RSVertex *)obj vertexSnappedTos]) {
                if ( [V locked] || ![V isMovable]) {
                    isMovable = NO;
                    break;
                }
            }
            if (!isMovable)
                continue;
            
            for (RSVertex *V in [(RSVertex *)obj vertexSnappedTos]) {
                [movers addElement:V];
            }
	}
	else if ([obj isKindOfClass:[RSLine class]]) {
            if ([obj isMovable] && ![obj locked]) {
                [movers addElement:obj];
            }
	    [movers addElement:[RSTool elementsToMove:[(RSLine *)obj vertices]]];
	    continue;
	}
	else if ([obj isKindOfClass:[RSFill class]]) {
	    [movers addElement:[RSTool elementsToMove:[(RSFill *)obj vertices]]];
	    continue;
	}
        else if ([obj isKindOfClass:[RSTextLabel class]]) {
            if ([[obj graph] isAxisLabel:obj])
                continue;
        }
	
	// if made it this far...
	[movers addElement:obj];
    }
    
    return movers;
}



////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////

- (id)init;
{
    // not allowed
    OBASSERT_NOT_REACHED("RSTool needs to be initialized with a view and graph");
    return nil;
}

- (id)initWithView:(RSGraphView *)view;
{
    if (!(self = [super init]))
        return nil;
    
    _view = view;
    _mapper = view.editor.mapper;
    _graph = [view graph];
    _s = [view RSSelector];
    _u = [[_s undoer] retain];
    _renderer = view.editor.renderer;
    
    _m = [RSMode sharedModeController];
    
    [view.editor.hitTester linesThatWereHit];  // initialize hit-testing extension
    
    [self initState];
    
    return self;
}

- (void)dealloc;
{
    [_u release];
    
    [super dealloc];
}


////////////////////////////////////////
#pragma mark -
#pragma mark Tool class methods
///////////
- (void)initState;
{
    
}

////////////////////////////////////////
#pragma mark -
#pragma mark Accessors
///////////
- (RSDataPoint)closestGridPoint;
{
    return _mouseMovedPoint;
}

- (BOOL)shouldDrawSelection;
{
    return ( [_s selected] && ![_m mouseDragging] );
}

////////////////////////////////////////
#pragma mark -
#pragma mark Mouse and key handling
///////////

- (void)mouseExited:(NSEvent *)event;
{
    
}

- (void)mouseMoved:(NSEvent *)event;
{
    NSPoint locationInWindow;
    
    NSEventType type = [event type];
    if (type == NSLeftMouseDown || type == NSLeftMouseUp || type == NSRightMouseDown || type == NSRightMouseUp || type == NSMouseMoved || type == NSLeftMouseDragged || type == NSRightMouseDragged || type == NSMouseEntered) {
        OBASSERT([event window]);
        locationInWindow = [event locationInWindow];
    }
    else {
        // If the event doesn't come with a locationInWindow (it's nil or not a mouse event), then ask the window for the current mouse location.
        locationInWindow = [[_view window] mouseLocationOutsideOfEventStream];
    }
    
    _viewMouseMovedPoint = [_view convertPoint:locationInWindow fromView:nil];
    [_m setGlobalViewMouseMovedPoint:_viewMouseMovedPoint];  //! probably don't need this anymore
    
    _mouseMovedPoint = [_mapper convertToDataCoords:_viewMouseMovedPoint];
}
- (void)mouseDown:(NSEvent *)event;
{
    _viewMouseDownPoint = [_view convertPoint:[event locationInWindow] fromView:nil];
    _mouseDownPoint = [_mapper convertToDataCoords:_viewMouseDownPoint];
    
    if (!NSEqualPoints(_viewMouseMovedPoint, _viewMouseDownPoint)) {
        //DEBUG_RS(@"The mouse moved without the tool's knowledge. %@ and %@", NSStringFromPoint(_viewMouseMovedPoint), NSStringFromPoint(_viewMouseDownPoint));
        [self mouseMoved:event];
    }
}
- (void)mouseDragged:(NSEvent *)event;
{
    if ( [event type] == NSLeftMouseDragged ) {
	_viewMouseDraggedPoint = [_view convertPoint:[event locationInWindow] fromView:nil];
	_mouseDraggedPoint = [_mapper convertToDataCoords:_viewMouseDraggedPoint];
    }
    // if the event doesn't have a locationInWindow (e.g. it's nil or flagsChanged), just keep the previously saved location (above)
}
- (void)mouseUp:(NSEvent *)event;
{
    _viewMouseUpPoint = [_view convertPoint:[event locationInWindow] fromView:nil];
    _mouseUpPoint = [_mapper convertToDataCoords:_viewMouseUpPoint];
}

- (void)cancelOperation:(NSEvent *)event;
{
    
}
- (void)delete:(id)sender;
{
    
}
- (void)insertNewline:(id)sender;
{
    
}


- (void)discardEditing;
{
    
}
- (BOOL)commitEditing;
{
    return YES;  // Nothing happened, so there were no errors.
}


////////////////////////////////////////
#pragma mark -
#pragma mark Actions
///////////
- (void)drawPhaseAtBeginning;
{
    
}
- (void)drawPhaseWithShadows;
{
    
}
- (void)drawPhaseAtEnd;
{
    
}





@end
