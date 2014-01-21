// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSTextTool.m 200244 2013-12-10 00:11:55Z correia $

#import "RSTextTool.h"

#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSHitTester.h>

#import "RSGraphView.h"
#import "RSSelector.h"
#import "RSMode.h"

@implementation RSTextTool

////////////////////////////////////////
#pragma mark -
#pragma mark RSTool subclass
///////////

- (void)initState;
{
    
}

- (void)dealloc;
{
    
    
    [super dealloc];
}



- (void)mouseMoved:(NSEvent *)event;
{
    [super mouseMoved:event];
    
    RSGraphElement *GE = [_view.editor.hitTester elementUnderPoint:_viewMouseMovedPoint];
    
    /////////
    // Update half selection:
    if ( [_s halfSelection] != GE ) {
	[_s setHalfSelection:GE];
	[_view setNeedsDisplay:YES];
    }
}

- (void)mouseUp:(NSEvent *)event;
{
    [super mouseUp:event];
    
    // if over label, edit label;
    // if over object, edit attached or new attached;
    // if over nothing, new label
    
    RSLine *L;
    
    // if something's selected, deselect it
    [_view deselect];
    // change back to modify mode in certain circumstances
    [_m toolWasUsed:RS_text];
    
    // now it's essentially like the double-click code in modify tool's mouseDown
    if ( [[_s halfSelection] isKindOfClass:[RSTextLabel class]] ) {
	[_view setSelection:[_s halfSelection]];
    }
    else if ( [[_s halfSelection] isKindOfClass:[RSVertex class]] ) {
	[_renderer positionLabel:nil forOwner:[_s halfSelection]];
	[_view setSelection:[[_s halfSelection] label]];
    }
    else if ( (L = [RSGraph isLine:[_s halfSelection]]) ) {
	[L setSlide:[_view.editor.hitTester timeOfClosestPointTo:_viewMouseDownPoint onLine:L]];
	[_renderer positionLabel:nil forOwner:L];
	[_view setSelection:[L label]];
    }
    else if ( [[_s halfSelection] isKindOfClass:[RSFill class]] ) {
	[_renderer positionLabel:nil forOwner:[_s halfSelection]];
	[_view setSelection:[[_s halfSelection] label]];
    }
    else {	// no halfSelection, or untextlabelable halfSelection
	if ( ![_view wasEditingText] ) {	// only start a new label if it was not just editing
	    // create new label to edit:
	    RSTextLabel *TL = [[[RSTextLabel alloc] initWithGraph:_graph] autorelease];
	    NSPoint newPos = [_mapper convertToViewCoords:_mouseUpPoint];
	    newPos.y -= 12;	// shift down 12 pixels
	    [TL setPosition:[_mapper convertToDataCoords:newPos]];
	    [_graph addLabel:TL];
	    [_view setSelection:TL];
	    [_s setHalfSelection:nil];
	}
	// else do nothing, other than the deselect above
    }
    
    // if a label is ready for editing
    if ( [_s selected] && [[_s selection] isKindOfClass:[RSTextLabel class]]) {	
	[_s sendChange:nil];	// spread the news
	[_view startEditingLabel];	// start editing
    }
    
    [_view setWasEditingText:NO];
}


@end
