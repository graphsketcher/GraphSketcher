// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSFillTool.m 200244 2013-12-10 00:11:55Z correia $

#import "RSFillTool.h"

#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSHitTester.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>

#import "RSSelector.h"
#import "RSMode.h"
#import "RSGraphView.h"


@interface RSFillTool (/*Private*/)
@property (nonatomic,retain) RSVertex *prevFillVertex;
@property (nonatomic,retain) RSFill *fillInProgress;
@end


@implementation RSFillTool

@synthesize prevFillVertex = _prevFillVertex;
@synthesize fillInProgress = _fillInProgress;


///////////////////////
#pragma mark -
#pragma mark Tool logistics
///////////////////////

- (void)resetState;
{
    // create a new fill to build:
    self.fillInProgress = [[[RSFill alloc] initWithGraph:_graph] autorelease];
    
    // clean vertex clusters
    [_persistentVertex clearSnappedTo];
    
    // reset history:
    self.prevFillVertex = nil;
    _objectToAdd = nil;
    
    [_view setNeedsDisplay:YES];
}

- (void)discardEditing;
{
    // Cancel the fill that will never be committed
    [_fillInProgress clearSnappedTos];
    [_fillInProgress removeAllVertices];
    //[_fillInProgress invalidate];
    
    // Reset the tool
    [self resetState];
    
    OBASSERT(_fillInProgress.graph);
}

- (BOOL)commitEditing;
{
    // add anything in newFillObject
    /*or not
     if( _newFillObject ) {
     // never add the actual _newFillVertex to the graph
     if( _newFillObject == _newFillVertex ) {
     RSVertex *V = [[_newFillVertex parentlessCopy] autorelease];
     [V setSnappedTo:[_newFillVertex snappedTo] withParams:[_newFillVertex snappedToParams]];  // copy over the snappedTo info
     [V setTentative:YES];
     // clean the newFillVertex
     [_newFillVertex clearSnappedTo];
     
     _newFillObject = V;
     }
     [_newFill addVerticesAtEnd:_newFillObject];
     }
     */
    
    // Cancel the fill if it isn't an actual area
    if ( ![_fillInProgress hasAtLeastThreeVertices] ) {
	[self discardEditing];
        return YES;  // means "no errors"
    }
    
    // Add the fill to the graph and select it
    [_graph addElement:_fillInProgress];
    [_u setActionName:NSLocalizedStringFromTable(@"Fill In Area", @"UndoActions", @"Undo action name")];
    [_s setSelection:_fillInProgress];
    
    // Reset the tool
    [self resetState];
    
    OBASSERT(_fillInProgress.graph);
    return YES;
}





////////////////////////////////////////
#pragma mark -
#pragma mark RSTool subclass
///////////

- (void)initState;
{
    self.fillInProgress = [[[RSFill alloc] initWithGraph:_graph] autorelease];
    
    _persistentVertex = [[RSVertex alloc] initWithGraph:_graph];
    [_u addExemptObject:_persistentVertex];
    [_persistentVertex setWidth:0];
    
    self.prevFillVertex = nil;
    _objectToAdd = nil;
    _retainedObjectToAdd = nil;
    
    _shouldEndFill = NO;
}

- (void)dealloc;
{
    self.prevFillVertex = nil;
    
    //[_fillInProgress removeAllVertices];
    self.fillInProgress = nil;
    
    [_u removeExemptObject: _persistentVertex];
    [_persistentVertex release];
    
    [super dealloc];
}


- (RSDataPoint)closestGridPoint;
{
    return _startDrawPoint;
}



- (void)mouseMoved:(NSEvent *)event;
{
    [super mouseMoved:event];
    
    NSUInteger modiferFlags = [event modifierFlags];
    
    [_fillInProgress acceptLatestDefaults];
    OBASSERT(_fillInProgress.graph);
    
    /////////////
    // Set up _startDrawPoint
    _startDrawPoint.x = _startDrawPoint.y = 0;
    
    //////////////////
    // Perform hit detection on graph objects
    RSGraphElement *GE = [_view.editor.hitTester elementUnderPoint:_viewMouseMovedPoint extraElement:_fillInProgress];
    
    // Freshen the persistent newFillVertex object
    [_persistentVertex clearSnappedTo];
    
    // update fill data structures etc.
    //
    if( [GE isKindOfClass:[RSVertex class]] ) {
	// always:
	_startDrawPoint = [GE position];
	
	if( [RSTool commandKeyIsDown:[event modifierFlags]] && [GE group] ) {
	    // add all vertices in the group to the fill-in-progress
	    GE = [GE group];
	    _objectToAdd = GE;
	}
	else {  // normal case
	    _objectToAdd = nil;
	    // if the previous vertex was in the same group as the current halfSelection
	    if( [GE group] && [_prevFillVertex group] == [GE group] ) {
		// add everything in between
		_objectToAdd = [[GE group] elementsBetween:_prevFillVertex and:GE];
		// add the end vertex, too
		[(RSGroup *)_objectToAdd addElement:GE];
		// manage memory
		if( _retainedObjectToAdd != _objectToAdd ) {
		    [_retainedObjectToAdd release];
		    _retainedObjectToAdd = [_objectToAdd retain];
		}
	    }
	    if( !_objectToAdd ) {
		// just add this one vertex to the fill-in-progress
		if ([_fillInProgress containsVertex:(RSVertex *)GE]) {
		    _objectToAdd = GE;
		}
		else {
		    [_persistentVertex setPosition:[GE position]];
		    [_persistentVertex shallowAddSnappedTo:GE withParam:[NSNumber numberWithFloat:0]];
		    _objectToAdd = _persistentVertex;
		}
	    }
	}
    }
    else {  // no GE found, or a GE was found of a type we don't have special behavior for
        RSSnapBehavior behavior = RSSnapBehaviorRegular;
        if ([RSTool shouldStraighten:modiferFlags])
            behavior = RSSnapBehaviorShiftKey;
        
	[_view.editor.hitTester snapVertex:_persistentVertex fromPoint:_viewMouseMovedPoint behavior:behavior prevVertex:_prevFillVertex nextVertex:[_fillInProgress firstVertex]];
	
	_startDrawPoint = [_persistentVertex position];
	_objectToAdd = _persistentVertex;
    }
    
    //maybe//[_newFill polygonize];
    OBASSERT(_fillInProgress.graph);
    
    
    // Update half-selection
    if ( [_s halfSelection] != GE ) {
	[_s setHalfSelection:GE];
    }
    
    // Update inspector about the _startDrawPoint
    if ( [[_s selection] isKindOfClass:[RSUnknown class]] ) {
	[[_s selection] setPosition:_startDrawPoint];
    }
    
    // Update status bar about the _startDrawPoint
    [_s setStatusMessage:[_graph infoStringForPoint:_startDrawPoint]];
    
    // always redisplay in fill mode
    [_view setNeedsDisplay:YES];
}




- (void)mouseDown:(NSEvent *)event;
{
    [super mouseDown:event];
    
    [_view deselect];
    
    [_fillInProgress acceptLatestDefaults];
    OBASSERT(_fillInProgress.graph);
    
    // double-click
    if ( [event clickCount] >= 2 ) {
	if ( [_fillInProgress hasAtLeastThreeVertices] ) {
	    _shouldEndFill = YES;   // (ending the fill is done in MouseUp)
	}
    }
    // single-click
    else {
	//if( [[_s halfSelection] isKindOfClass:[RSVertex class]] ) {
	//	V = (RSVertex *)[_s halfSelection];
	//[_newFill addVertex:(RSVertex *)[_s halfSelection]];
	//}
	if( _objectToAdd == nil )
            _objectToAdd = _persistentVertex;
	
	if( _objectToAdd == _persistentVertex ) {  // adding a new point to the fill
	    RSVertex *V = [[_persistentVertex parentlessCopy] autorelease];
	    [V setSnappedTo:[_persistentVertex snappedTo] withParams:[_persistentVertex snappedToParams]];  // copy over the snappedTo info
            
	    // clean the newFillVertex
	    [_persistentVertex clearSnappedTo];
	    
	    _objectToAdd = V;
	}
	else {  // adding an existing element to the fill
	    //GE = _newFillObject;
	}
	// add the vertex to the fill
	//if( [_newFill addVertexAtEnd:V] ) {
	//	_prevFillVertex = V;
	//}
	if( ![_fillInProgress addVerticesAtEnd:_objectToAdd] ) {
	    _shouldEndFill = YES;  // the vertex(es) were already in the fill, so end the fill
	}
	else {
	    if( [_objectToAdd isKindOfClass:[RSVertex class]] )
		self.prevFillVertex = (RSVertex *)_objectToAdd;
	    else if ( [_objectToAdd isKindOfClass:[RSGroup class]] ) {
		self.prevFillVertex = (RSVertex *)[(RSGroup *)_objectToAdd 
					       lastElementWithClass:[RSVertex class]];
	    }
	}
	
	// the new object has now been added
	_objectToAdd = nil;
    }
    OBASSERT(_fillInProgress.graph);
    
    // redraw
    [_view setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event;
{
    [super mouseDragged:event];
    
    // Dragging currently has no effect in fill mode
}

- (void)mouseUp:(NSEvent *)event;
{
    [super mouseUp:event];
    
    OBASSERT(_fillInProgress.graph);
    
    // potentially add the new fill to the graph
    if( _shouldEndFill ) {
	
	if ( [_fillInProgress hasAtLeastThreeVertices] ) {
	    // change back to modify mode in certain circumstances
	    [_m toolWasUsed:RS_fill];
	}
	
	_objectToAdd = nil;
	// this takes care of the rest
	[self commitEditing];
	
	_shouldEndFill = NO;
    }
    
    OBASSERT(_fillInProgress.graph);
}


- (void)cancelOperation:(NSEvent *)event;
// "Escape" key pressed
{
    [self discardEditing];  // cancel the current line being constructed
}

- (void)delete:(id)sender;
{
    if (![_fillInProgress isEmpty]) {
	[_fillInProgress removeVertex:_prevFillVertex];
	self.prevFillVertex = (RSVertex *)[[_fillInProgress vertices] lastElement];
	[_view setNeedsDisplay:YES];
    }
}

- (void)insertNewline:(id)sender;
// "Return" key pressed
{
    if ([_m mouseDragging])  // avoid weird interactions with future-implemented mouse dragging behavior
        return;
    
    [self commitEditing];
}



- (void)drawPhaseAtBeginning;
{
    if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SnapToGrid"]
	&& [_mapper isGridLinePoint:_startDrawPoint] )
    {
	[_renderer drawGridPoint:_startDrawPoint];
    }
}

- (void)drawPhaseWithShadows;
{
    
}
- (void)drawPhaseAtEnd;
{
    // Show mouse position on axes
    [_renderer drawPosition:_startDrawPoint onAxis:[_graph xAxis]];
    [_renderer drawPosition:_startDrawPoint onAxis:[_graph yAxis]];
    
    ////////////////
    // Draw fill-in-progress, if any
    if ( _fillInProgress ) {
        if (_objectToAdd) {
            RSFill *potentialFill = [_fillInProgress fillWithElement:_objectToAdd];
            // then draw it
            [_renderer drawFill:potentialFill];
            [potentialFill invalidate];
        } else {
            // just draw the fill in progress
            [_renderer drawFill:_fillInProgress];
        }
    }
}




@end
