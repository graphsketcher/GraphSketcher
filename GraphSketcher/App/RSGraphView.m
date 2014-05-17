// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSGraphView.h"

#import "RSSelector.h"
#import "RSMode.h"
#import "RSTool.h"
#import "ErrorBarSheet.h"
#import "DataImportOptionsSheet.h"

#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSGrid.h>
#import <GraphSketcherModel/RSEquationLine.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/OFPreference-RSExtensions.h>
#import <GraphSketcherModel/NSBezierPath-RSExtensions.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>
#import <GraphSketcherModel/RSDataImporter.h>
#import <GraphSketcherModel/RSLog.h>
#import <GraphSketcherModel/RSGraph-XML.h>  // for object copy/paste

#import <OmniInspector/OIInspectorRegistry.h>
#import <OmniQuartz/OQColor.h>
#import <OmniAppKit/OAFontDescriptor.h>


// Quick way to let us keep these shortcuts
#define _graph _editor.graph
#define _mapper _editor.mapper
#define _renderer _editor.renderer



@implementation RSGraphView


////////////////////////////////////////////
#pragma mark -
#pragma mark Class methods
////////////////////////////////////////////
- (void)updateTrackingAreas;
{
    [super updateTrackingAreas];
    
    [self removeTrackingRect:_trackingRectTag];
    _trackingRectTag = [self addTrackingRect:[self bounds] owner:self 
                                    userData:nil assumeInside:NO];
}


////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
////////////////////////////////////////////

- (id)initWithFrame:(NSRect)frameRect
{
    if (!(self = [super initWithFrame:frameRect]))
        return nil;
    
    _s = nil;
    
    // get shared mode controller
    _m = [RSMode sharedModeController];
    
    // initialize state variables
    _mouseExited = NO;
    _importingData = NO;
    _drawingToScreen = YES;
    _mouseIsDown = NO;
    
    _textView = nil;
    _textSnapshot = nil;
    _discardingEditing = NO;
    
    _cursorMode = RS_none;
    _trackingRectTag = 0;
    
    _wasEditingText = NO;
    _connectNextImport = NO;
    
    _tools = nil;
    
    
    // Custom cursors
    _penCursor = [[NSCursor alloc]  initWithImage:[NSImage imageNamed:@"DrawCursor"] hotSpot:NSMakePoint(0, 15)];
    _fillCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"FillCursor"] hotSpot:NSMakePoint(0, 2)];
    
    return self;
}

- (void)dealloc
{
    DEBUG_RS(@"An RSGraphView is being deallocated.");
    
    [self setRSSelector:nil];
    [_halfSelectionLayer release];
    
    // unregister observer from notification center
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
    
    // release allocated objects
    [_penCursor release];
    [_fillCursor release];
    
    self.editor = nil; // Unsubscribes KVO.
    
    [super dealloc];
}

- (void)awakeFromNib
// Anything that initializes nib elements needs to go here
// rather than in initWithFrame: above, because nib elements get
// initialized after initWithFrame: gets called.
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    _document = [windowController document];
    
    // Core Animation
    _halfSelectionLayer = nil;
//    [self setWantsLayer:YES];
//    [[self layer] setAutoresizingMask:(kCALayerWidthSizable | kCALayerHeightSizable)];
//    
//    _halfSelectionLayer = [[CALayer alloc] init];
//    [_halfSelectionLayer setDelegate:self];
//    [_halfSelectionLayer setNeedsDisplayOnBoundsChange:YES];
//    
//    [[self layer] addSublayer:_halfSelectionLayer];
//    [_halfSelectionLayer setFrame:[[self layer] bounds]];
//    [_halfSelectionLayer setAutoresizingMask:(kCALayerWidthSizable | kCALayerHeightSizable)];
    
    
    // Register to receive notifications about selection changes
    [nc addObserver:self 
           selector:@selector(selectionChangedNotification:)
               name:@"RSSelectionChanged"
             object:nil];
    
    // Register to receive notifications when the undo manager has made a change
    [nc addObserver:self 
           selector:@selector(undoManagerMadeAChange:)
               name:NSUndoManagerDidRedoChangeNotification
             object:nil];
    [nc addObserver:self 
           selector:@selector(undoManagerMadeAChange:)
               name:NSUndoManagerDidUndoChangeNotification
             object:nil];
    
    // Register to receive notifications when the toolbar is clicked
    [nc addObserver:self 
           selector:@selector(RSToolbarClickedNotification:)
               name:@"RSToolbarClicked"
             object:nil];
    
    // Register to receive notifications of an external change in mode
    [nc addObserver:self 
           selector:@selector(RSModeWillChangeNotification:)
               name:@"RSModeWillChange"
             object:nil];
    [nc addObserver:self 
           selector:@selector(RSModeDidChangeNotification:)
               name:@"RSModeDidChange"
             object:nil];
    
    // Register to receive notifications of system change of highlight color
    [nc addObserver:self 
           selector:@selector(NSSystemColorsDidChangeNotification:)
               name:NSSystemColorsDidChangeNotification
             object:nil];
    
    // Register to receive notifications that something is suggesting an autoscale
    [nc addObserver:self 
           selector:@selector(AutoScaleIfWantedNotification:)
               name:@"RSAutoScaleIfWanted"
             object:nil];
    
    
    // this makes sure mouseMoved events get noticed from the get-go
    [[self window] setInitialFirstResponder:self];
    
    [self updateTrackingAreas];
    
    [[self window] invalidateCursorRectsForView:self];
    //[self resetCursorRects];
    //[self updateCursor];
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    [self updateTrackingAreas];
    
    [[self window] makeFirstResponder:self];
    
    //NSLog(@"hi: %f", [self bounds].size.width);
    //[_graph setCanvasSize:[self bounds].size];
}

#pragma mark Init and access helper classes

@synthesize document = _document;

- (void)setEditor:(RSGraphEditor *)editor;
{
    if (editor == _editor)
        return;
    
    if (_editor) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        [_editor release];
        _editor = nil;
        
        // clear out selection
        if( [_s deselect] ) {
            [_s sendChange:nil];
        }
        [_s setHalfSelection:nil];
        
        [OIInspectorRegistry clearInspectionSet];
        
        [_tools release];
        
        [pool release];  // Ensure we dealloc any lingering autoreleased objects that reference the old graph
    }
    if (editor) {
        _editor = [editor retain];
        [_editor updateBounds:[self bounds]];
        
        // init tools
        _tools = [[NSMutableArray alloc] initWithObjects:[[[RSTool alloc] initWithView:self] autorelease], // "none"
                  [RSMode toolForMode:RS_modify withView:self],
                  [RSMode toolForMode:RS_draw withView:self],
                  [RSMode toolForMode:RS_fill withView:self],
                  [RSMode toolForMode:RS_text withView:self],
                  nil];
        
        [self updateTrackingAreas];
    }
}

@synthesize editor = _editor;

- (RSGraph *)graph
{
    return _editor.graph;
}

- (void)setRSSelector:(RSSelector *)selector {
    if (_s) {
        [_s removeObserver:self forKeyPath:@"halfSelection"];
        [_s release];
    }
    _s = selector;
    if (_s) {
        [_s retain];
	[_s addObserver:self forKeyPath:@"halfSelection" options:NSKeyValueObservingOptionNew context:NULL];
        [_s deselect];
    }
}
- (RSSelector *)RSSelector;
{
    return _s;
}

- (RSTool *)currentTool;
{
    NSUInteger mode = [_m mode];
    if (!mode)
	return nil;
    return [_tools objectAtIndex:mode];
}

- (void)windowDidResize;
{
    // this is called by [GraphDocument (void)windowDidResize:(NSNotification *)note]
    // and other things are done there.
    [_editor updateBounds:[self bounds]];
    
    [self mouseEntered:nil];
}


///////////////////////////////////////
#pragma mark -
#pragma mark Notifications:
///////////////////////////////////////
/*
- (void)IAmSelectionObjectNotification:(NSNotification *)note
{
    Log3(@"GraphView received notification: %@", note);
    _s = [note object];
	[self setNeedsDisplay:YES];
}
 */
- (void)selectionChangedNotification:(NSNotification *)note;
// sent by selection object when any object modifies the selection in any way
{
    Log2(@"GraphView received %@", note);
    
    // Ensure that these commands are only executed for the document window in focus
    if ( ![[self window] isMainWindow] )
	return;
    
    
    //[_s setStatusMessage:[[_s selection] infoString]];
    
    // Make sure the toolbar items are updated right away, if needed
    [[[self window] toolbar] validateVisibleItems];
    
    if ( [note object] == self )
	return;
    
    // If a different object sent this notification, update self further.
    if ( [[note object] isKindOfClass:[RSTextLabel class]] )
    {
	if (_textView)
	    [self stopEditingLabel];
	if ([_editor.graph isAxisLabel:[note object]])
	    [_editor setNeedsUpdateWhitespace];
    }
    
    [_editor modelChangeRequires:RSUpdateConstraints];
}

- (void)undoManagerMadeAChange:(NSNotification *)note;
{
    if ( ![[self window] isMainWindow] )
	return;
    
    if ( [note object] != [_editor.undoer undoManager] )
	return;
    
    //DEBUG_RS(@"updating display after undo or redo");
    [_s setHalfSelection:nil];
    [self setNeedsDisplay:YES];
}


- (void)RSToolbarClickedNotification:(NSNotification *)note;
{
    Log3(@"GraphView received notification: %@", note);
    
    /* Do nothing, because RSModeChangedNotification will be sent too
     [self deselect];
     //[self cancelTentativeFill];
     [self commitTentativeFill];
     //[self stopEditingLabel];
     */
}
- (void)RSModeWillChangeNotification:(NSNotification *)note;
{
    Log3(@"GraphView received notification: %@", note);
    
    if (![[self window] isMainWindow])
	return;
    
    [self commitEditing];
}
- (void)RSModeDidChangeNotification:(NSNotification *)note;
{
    if (![[self window] isMainWindow])
	return;
    
    [_s setStatusMessage:[[_s selection] infoString]];
    
    // update inspectors:
    [OIInspectorRegistry updateInspector];
    
    [self setWasEditingText:NO];
    
    // Go through the mouseMoved code path with the new tool to initialize it properly:
    [self mouseMoved:nil];
    
    [self setNeedsDisplay:YES];
}

- (void)NSSystemColorsDidChangeNotification:(NSNotification *)note;
// Sent by the system whenever the user changes their color preferences
{
    Log3(@"GraphView received notification: %@", note);
    
    [self setNeedsDisplay:YES];
}

- (void)AutoScaleIfWantedNotification:(NSNotification *)note;
{
    Log3(@"GraphView received notification: %@", note);
    
    [_editor.mapper scaleAxesToMakeVisible:[_editor.graph Vertices]];
}



////////////////////////////////////////////////
#pragma mark -
#pragma mark NSEditor protocol
////////////////////////////////////////////////
- (BOOL)commitEditing;
{
    //! Possibly, we should only commit the changes in the editor, not stop editing.  Stopping editing seems safest, though.
    [self stopEditingLabel];
    
    BOOL result = [[self currentTool] commitEditing];
    
    [_editor.undoer endRepetitiveUndo];
    
    [self displayIfNeeded];  // Update any pending changes to the view.  In particular, we need this to accept the changes to transparency caused by removing the field editor.
    
    return result;
}

- (void)discardEditing;
// Corresponds to "esc" key behavior.
{
    _discardingEditing = YES;
    
    if ([self isEditingLabel]) {
        OBASSERT([self textSnapshot]);
        
        RSTextLabel *TL = [self stopEditingLabel];
        OBASSERT(TL);
        
        [self revertEditsForLabel:TL];
        
        [_editor.undoer endRepetitiveUndo];
    }
    
    else {
        [self setSelection:nil];
    }
    
    _discardingEditing = NO;
}


#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if (object == _s) {
        OBASSERT(context == NULL);
        if (_halfSelectionLayer)
            [_halfSelectionLayer setNeedsDisplay];
        else
            [self setNeedsDisplay:YES];
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


#pragma mark -
#pragma mark OIInspectableController protocol

- (void)addInspectedObjects:(OIInspectionSet *)inspectionSet;
{
    [inspectionSet addObject:_document];
}



////////////////////////////////////////////////
#pragma mark -
#pragma mark NSObject subclass
///////////////////////////////////////////////

- (void)changeColor:(id)sender;
{
    // If a color well is active, it should take care of this rather than the first responder.
    if ([OAColorWell hasActiveColorWell])
        return;
    
    RSGraphElement *obj = [_s selection];
    NSColor *newColor = [sender color];
    
    // set the color
    [obj setColor:[OQColor colorWithPlatformColor:newColor]];
    
    if ( [obj isKindOfClass:[RSUnknown class]] ) {
	if ([_m mode] == RS_fill) {
	    [[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newColor forKey:@"DefaultFillColor"];
	}
	else {
	    [[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newColor forKey:@"DefaultLineColor"];	    
	}
    }
    else if ([RSGraph isLine:obj] || [obj isKindOfClass:[RSVertex class]]) {
	[[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newColor forKey:@"DefaultLineColor"];
    }
    else if ([obj isKindOfClass:[RSFill class]]) {
	[[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newColor forKey:@"DefaultFillColor"];
    }
    
    [_s sendChange:self];
}


////////////////////////////////////////////////
#pragma mark -
#pragma mark NSView subclass (plus helpers)
///////////////////////////////////////////////

- (BOOL)acceptsFirstResponder
{
    Log2(@"acceptsFirstResponder");
    // make sure axes, etc. are displayed right
    //[self setNeedsUpdateWhitespace];
    
    return YES;
}

- (BOOL)acceptsFirstMouse {
    return YES;
}

- (NSCursor *)chooseCursor {
    //if (!_mouseExited) {
    if ( [_m mode] == RS_modify )
	return [NSCursor arrowCursor];
    else if ( [_m mode] == RS_draw )
	return _penCursor;
    else if ( [_m mode] == RS_fill )
	return _fillCursor;
    else if ( [_m mode] == RS_text ) {
	//if ( _subview )  return [NSCursor arrowCursor];
	//else  
	return [NSCursor IBeamCursor];
    }
    //}
    //else
    OBASSERT_NOT_REACHED("No cursor chosen.");
    return nil;
}


- (void)updateCursor;
// make sure cursor is correct
{
    _cursorMode = [_m mode];
    [[self window] invalidateCursorRectsForView:self];
    //[self setNeedsDisplay:YES];
}

- (void)resetCursorRects {
    // Called automatically whenever the window is resized or cursor rects need to be
    // reestablished for some other reason.
    // To manually reset cursor rects, use:
    // [[self window] invalidateCursorRectsForView:self];
    // Use addCursorRect:cursor: for each cursor rectangle you want to establish.
    NSRect r;
    //if ( !_subview ) {
    r = [self bounds];
    r.size.height -= 14;	// this is all for resize box in lower right
    r.origin.y += 14;
    //NSLog(@"Mode = %d", [_m mode]);
    [self addCursorRect:r cursor:[self chooseCursor]];
    //}
    
}

- (void)setDrawingToScreen:(BOOL)flag;
{
    _drawingToScreen = flag;
}
- (BOOL)isDrawingToScreen;
{
    return (_drawingToScreen && [NSGraphicsContext currentContextDrawingToScreen]);
}

- (void)viewWillDraw;
{
    // Update display parameters if necessary
    [_editor prepareForDisplay];
    
    // Tell window-backing shadow that it needs to update
    if ([_editor.graph windowAlpha] < 1) {
        [[self window] invalidateShadow];
    }
    
    // Update frame of text field editor
    if (_textView && _textViewNeedsUpdate) {
        [self processTextChange];
    }

    // set the status message?

    [super viewWillDraw];
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    NSGraphicsContext *nsGraphicsContext;
    nsGraphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:ctx
                                                                   flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsGraphicsContext];
    
    // Draw half-selection into its own special layer
    if (layer == _halfSelectionLayer)
    {
        if ( [_s halfSelection] && [self isDrawingToScreen] )
        {
            [_editor.renderer drawHalfSelected:[_s halfSelection]];
        }
        
//        // Test rects
//        [[NSColor redColor] set];
//        NSRect rect=[self bounds];
//        NSFrameRect(rect);
//        rect.size.width *= 0.5;
//        rect.size.height *= 0.5;
//        NSFrameRect(rect);
    }
    
    // Draw everything else into the main (root) layer
    else if (layer == [self layer])
    {
        [self drawRect:[self bounds]];
    }
    
    else {
        OBASSERT_NOT_REACHED("Unknown layer");
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawRect:(NSRect)rect
// called every time the RSGraphView is deemed needing a redraw.
{
    //DEBUG_RS(@"RSGraphView drawRect");
    
    // OBFinishPorting: This seems like too many calls into the RSGraphEditor's guts (which need to be duplicated between the Mac and iPad).
    RSGraph *graph = _editor.graph;
    RSGraphRenderer *renderer = _editor.renderer;
    
    [_editor.mapper resetCurveCache];
    
    //NSLog(@"GV bounds: %f, %f, %f, %f", [self bounds].origin.x, [self bounds].origin.y, 
    //	[self bounds].size.width, [self bounds].size.height);
    
    
    // Draw the graph background and grid lines
    OQColor *backgroundColor = [[graph backgroundColor] colorUsingColorSpace:OQColorSpaceRGB];
    if ([self isDrawingToScreen] && [graph windowAlpha] < 1) {
        backgroundColor = [backgroundColor colorWithAlphaComponent:[graph windowAlpha]];
    }
    [renderer drawBackgroundWithColor:backgroundColor];
    
    
    // Give tools a chance to draw behind the graph elements
    if ([self isDrawingToScreen] && !_mouseExited) {
	[[self currentTool] drawPhaseAtBeginning];
    }
    
    
    // Draw all of the normal graph objects
    RSGraphElement *selection = nil;
    if (_textView) {
        selection = [_s selection];
    }
    [renderer drawAllGraphElementsExcept:selection];
    
    
    // Give tools a chance to draw with shadows
    if ([self isDrawingToScreen] && !_mouseExited) {
        [renderer turnOnShadows];
        [[self currentTool] drawPhaseWithShadows];
        [renderer turnOffShadows];
    }
    
    
    // Draw selection, if any
    if ( [[self currentTool] shouldDrawSelection] 
	&& !_textView 
	&& [self isDrawingToScreen] ) {
	
	[renderer drawSelected:[_s selection] windowIsKey:[[self window] isKeyWindow]];
    }
    
    // Draw half-selection, if any
    if ( !_halfSelectionLayer && [_s halfSelection] && [self isDrawingToScreen] ) {
	
	[renderer drawHalfSelected:[_s halfSelection]];
    }
    
    if (_textView) {
        OBASSERT([[_s selection] isKindOfClass:[RSTextLabel class]]);
        // We have to do this fancy conversion rather than just calling [_textView frame] so that it will work for rotated labels too (i.e. y-axis title):
        NSRect labelRect = [self convertRect:[_textView bounds] fromView:_textView];  
        [renderer drawFocusRingAroundRect:labelRect];
    }
    
    
    // Give tools a chance to draw on top of everything else
    if ([self isDrawingToScreen] && !_mouseExited) {
	[[self currentTool] drawPhaseAtEnd];
    }

    
    Log3(@"drawRect finished");
}

- (void)mouseEntered:(NSEvent *)event
{
    if ( ![[self window] isMainWindow] )
	return;
    if ( ![[self window] isKeyWindow] )
	return;
    
    [[self window] setAcceptsMouseMovedEvents:YES];
    
    _mouseExited = NO;
    
    [self updateCursor];  // Necessary when you click between windows after having changed the tool mode.
    
    [_s setStatusMessage:[[_s selection] infoString]];
    
    [_editor.mapper resetCurveCache];
    
    //DEBUG_RS(@"mouse entered successfully");
}
- (void)mouseExited:(NSEvent *)event
{
    Log2(@"MouseExited on event %@", event);
    
    if ([_m mouseDragging])
	return;  // Otherwise, this can lead to weird tool behaviors like <bug://bugs/52369> (When doing a drag select and you move the cursor out of the window, the selection box is no longer visible)
    
    [[self window] setAcceptsMouseMovedEvents:NO];
    
    // Update inspector if nothing is selected
    if ( [[_s selection] isKindOfClass:[RSUnknown class]] ) {
	// set things to zeros
	[[_s selection] setPosition:RSDataPointMake(0,0)];
	[_s sendChange:self];
    }
    
    if ([[self window] isMainWindow]) {
        [_s setStatusMessage:messageForCanvasSize([_editor.graph canvasSize])];
    }
    
    [_s setHalfSelection:nil];
    
    _mouseExited = YES;
    
    [self setNeedsDisplay:YES];
    
    [[self currentTool] mouseExited:event];
}
- (void)mouseMoved:(NSEvent *)event
// Called whenever the mouse is inside the RSGraphView
// so we can check whether it's over something interesting
{
    // This type of thing always seems to end up backfiring
//    if ( [event type] == NSMouseMoved ) {
//	NSPoint p = [event locationInWindow];
//	NSRect r = [self bounds];
//	if ( !NSPointInRect(p, [self bounds]) ){
//	    [self mouseExited:event];
//	    return;
//	}
//    }
    
    _mouseIsDown = NO;
    
    // make sure cursor is correct:
    if ( [_m mode] != _cursorMode ) {
	[self updateCursor];
    }
    
    // defer to the tool class
    [[self currentTool] mouseMoved:event];
    
}

- (void)mouseDown:(NSEvent *)event
{
    _mostRecentEvent = event;
    
    // if the graph mistakenly thinks the mouse is NOT in its bounds, correct the situation
    if( _mouseExited ) {
	[self mouseEntered:event];
	[self mouseMoved:event];
    }
    
    [[self currentTool] mouseDown:event];
    
    // Make sure the toolbar items are updated right away
    [[[self window] toolbar] validateVisibleItems];
    
    _mouseIsDown = YES;
}

- (void)mouseDragged:(NSEvent *)event
{
    // If the user is dragging the window around by holding on to the toolbar, but they drag so quickly that the cursor moves down into the graph area before the window "catches up", then mistaken mouseDragged: events get sent, leading to crazy weird behavior.  That's right, crazy AND weird.  AND totally bizarre.  Whoa.  Craziest bug ever.
    if (!_mouseIsDown) {
	DEBUG_RS(@"You're dragging the mouse too fast...");
	return;
    }
    
    // Don't follow drag behavior if a label is being edited
    if (![self isEditingLabel]) {
        [[self currentTool] mouseDragged:event];
    }
    
    [_m setMouseDragging:YES];
}

- (void)mouseUp:(NSEvent *)event
{
    _mouseIsDown = NO;
    
    _mostRecentEvent = event;
    
    [[self currentTool] mouseUp:event];
    
    [_m setMouseDragging:NO];  // this affects what RSMode does
    
    // update mode with new key flag information:
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSFlagsChanged" object:event];
    
    // New actions after a mouseUp should get new undo items, unless in the middle of editing a label
    if (!_textView) {
        [_editor.undoer endRepetitiveUndo];
    }
    
    // half-select something new, if applicable:
    [self mouseMoved:event];
}


//////////////////////////////////////
#pragma mark -
#pragma mark Key handling (NSResponder)
//////////////////////////////////////
//
// Really awesome Cocoa key bindings reference is at:
// http://www.hcs.harvard.edu/~jrus/Site/System%20Bindings.html
//

BOOL showWhaBam = NO;

- (BOOL)disregardKeyDown:(NSEvent *)event;
// Don't beep annoyingly when the user accidentally holds down a letter key that's not actually a hotkey.
{
    NSString *chars = [event charactersIgnoringModifiers];
    
    if (![chars length] || ([event modifierFlags] & (NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask)))
        return NO;
    
    unichar theChar = [chars characterAtIndex:0];
    
    // Wha-BAM easter egg
    if (theChar == 'w' && !showWhaBam) {
	showWhaBam = YES;
	[[[self window] toolbar] validateVisibleItems];
    } else {
	showWhaBam = NO;
    }
    
    // Tufte easter egg
    if (theChar == 't' && !_editor.graph.tufteEasterEgg) {
        _editor.graph.tufteEasterEgg = YES;
    }
    
    NSInteger index = theChar - 'a';
    if (index >= 0 && index <= 25)  // disregard (don't beep) if it's a letter a-z
	return YES;
    
    index = theChar - '0';
    if (index >= 0 && index <= 9)  // also disregard the numbers 0-9
	return YES;
    
    return NO;
}

- (void)keyDown:(NSEvent *)event;
{
    Log3(@"RSGraphView keyDown");
    //_lastEvent = event;
    
    if ([_m handleKeyDown:event])
	return;
    
    if ([self disregardKeyDown:event])
	return;
    
    [self interpretKeyEvents:[NSArray arrayWithObject:event]];
    // All (or some of?) the methods the previous command ends up calling
    // are listed in the NSResponder documentation.
    
    // end undo grouping
    //[_editor.undoer endUndoGroupingIfNecessary];
}

- (void)keyUp:(NSEvent *)event;
{
    showWhaBam = NO;
    if (_editor.graph.tufteEasterEgg) {
        _editor.graph.tufteEasterEgg = NO;
    }
    
    // Make sure the toolbar items are updated right away, if needed
    [[[self window] toolbar] validateVisibleItems];
    
    if ([_m mode] == RS_text)
	return;
    
    if ([_m handleKeyUp:event])
	return;
    
    else
	[super keyUp:event];
}


- (void)insertText:(NSString *)aString {
    // called automatically when a user types character keys
    // aString is the string they typed
    //RSTextLabel *TL;
    //RSLine *L;
    //NSLog(@"RSGraphView insertText called");
    
    NSBeep();
    // I could never get the following code to work.  The problem was that
    // the first key pressed was inserted, then selected so that the second
    // key typed erased the first one.  yuck.
    /*
    if ( [_s selected] ) {
	    TL = [[_s selection] label];
	    if (!TL) {
		    //TL = [[RSTextLabel alloc] init];
		    //[_graph addElement:[TL autorelease]];
		    //[TL setOwner:[_s selection]];
		    //[[_s selection] setText:aString];
		    if ( [_s context] == [RSVertex class] || [_s context] == [RSLine class] ) {
			    [_renderer positionLabel:nil forOwner:[_s selection]];
			    [self setSelection:[[_s selection] label]];
			    [[_s selection] setText:aString];
			    [self startEditingLabel:[_s selection]];
			    //didn't work//[_subview setStringValue:aString];
			    //[[_subview cell] moveToEndOfLine:self];
			    //[_subview moveToEndOfLine:self];
			    //[_subview insertText:aString];
			    NSLog(@"hi hi hi hi hi hi hi");
			    [_subview keyDown:_lastEvent];
		    }
		    else if ( [_s context] == [RSGroup class] && [[_s selection] isLine] ) {
			    L = [[_s selection] isLine];
			    [_renderer positionLabel:nil forOwner:L];
			    [self setSelection:[L label]];
			    [[_s selection] setText:aString];
			    [self startEditingLabel:[_s selection]];
		    }
		    [_s sendChange:nil];
	    }
	    else NSBeep();
    }
    else {
	    NSBeep();
    }
    */
}

- (void)flagsChanged:(NSEvent *)event;
// Automatically called whenever a modifier key is pressed or released
{
    // send notification out (for RSMode)
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSFlagsChanged" object:event];
    
    // changed flags could affect the drag -- e.g. snap to 90-degree
    if ( [_m mouseDragging] ) {
	[self mouseDragged:event];
    }
    else if (!_mouseExited) {
	[self mouseMoved:event];
    }
    
    // Make sure the toolbar items are updated right away, if needed
    [[[self window] toolbar] validateVisibleItems];
    
    //no// if mouse has exited the window, ignore flagsChanged
}


//////////////
// arrow keys
- (void)moveUp:(id)sender {
    // shift selection up by one pixel
    [self moveSelectionBy:CGPointMake(0, RS_NUDGE_DISTANCE_SHORT)];
}
- (void)moveDown:(id)sender {
    // shift selection down by one pixel
    [self moveSelectionBy:CGPointMake(0, -RS_NUDGE_DISTANCE_SHORT)];
}
- (void)moveLeft:(id)sender {
    // shift selection up by one pixel
    [self moveSelectionBy:CGPointMake(-RS_NUDGE_DISTANCE_SHORT, 0)];
}
- (void)moveRight:(id)sender {
    // shift selection up by one pixel
    [self moveSelectionBy:CGPointMake(RS_NUDGE_DISTANCE_SHORT, 0)];
}

/////////////////
// arrow keys with shift held down
- (void)moveUpAndModifySelection:(id)sender {
    if ([[_graph yAxis] axisType] == RSAxisTypeLinear) {
        [self moveSelectionInLinearSpaceBy:RSDataPointMake(0, [[_graph yAxis] spacing])];
    } else {
        [self moveSelectionBy:CGPointMake(0, RS_NUDGE_DISTANCE_LONG)];
    }
}
- (void)moveDownAndModifySelection:(id)sender {
    if ([[_graph yAxis] axisType] == RSAxisTypeLinear) {
        [self moveSelectionInLinearSpaceBy:RSDataPointMake(0, -[[_graph yAxis] spacing])];
    } else {
        [self moveSelectionBy:CGPointMake(0, -RS_NUDGE_DISTANCE_LONG)];
    }
}
- (void)moveLeftAndModifySelection:(id)sender {
    if ([[_graph xAxis] axisType] == RSAxisTypeLinear) {
        [self moveSelectionInLinearSpaceBy:RSDataPointMake(-[[_graph xAxis] spacing], 0)];
    } else {
        [self moveSelectionBy:CGPointMake(-RS_NUDGE_DISTANCE_LONG, 0)];
    }
}
- (void)moveRightAndModifySelection:(id)sender {
    if ([[_graph xAxis] axisType] == RSAxisTypeLinear) {
        [self moveSelectionInLinearSpaceBy:RSDataPointMake([[_graph xAxis] spacing], 0)];
    } else {
        [self moveSelectionBy:CGPointMake(RS_NUDGE_DISTANCE_LONG, 0)];
    }
}

- (void)_moveElement:(RSGraphElement *)GE toPosition:(RSDataPoint)newPos;
{
    // If we're undoing, set up for Redo
    if ([[_editor undoer] firstUndoWithObject:GE key:@"moveSelectionBy"]) {
        RSDataPoint oldPos = [GE position];
        [[[_graph undoManager] prepareWithInvocationTarget:self] _moveElement:GE toPosition:oldPos];
        [[_editor undoer] setActionName:NSLocalizedStringFromTable(@"Nudge Selection", @"UndoActions", @"Undo action name")];
    }
    
    [_mapper moveElement:GE toPosition:newPos];
}

// The mother of move methods
- (void)moveSelectionBy:(CGPoint)delta;
{
    RSGraphElement *selection = [_s selection];
    
    if ( [selection locked] ) {
	[_s setStatusMessage:NSLocalizedString(@"The selection is locked in place. To move it, first choose \"Unlock\".", @"Status bar warning for locked selection")];
        return;
    }
    else if ( ![_s selected] || ![[_s selection] isMovable] ) {
        NSBeep();
        return;
    }
    
    RSGroup *elementsToMove = [RSTool elementsToMove:selection];
    
    if ([[_editor undoer] firstUndoWithObject:selection key:@"moveSelectionBy"]) {
//        CGPoint reverseDelta = CGPointMake(-delta.x, -delta.y);
//        [[[_graph undoManager] prepareWithInvocationTarget:_mapper] shiftElement:elementsToMove byDelta:reverseDelta];
        RSDataPoint oldPos = [elementsToMove position];
        [[[_graph undoManager] prepareWithInvocationTarget:self] _moveElement:elementsToMove toPosition:oldPos];
        [[_editor undoer] setActionName:NSLocalizedStringFromTable(@"Nudge Selection", @"UndoActions", @"Undo action name")];
    }
    
    [_mapper shiftElement:elementsToMove byDelta:delta];
    
    // update status message:
    [_s setStatusMessage:[selection infoString]];
    
    [_editor modelChangeRequires:RSUpdateConstraints];
}

- (void)moveSelectionInLinearSpaceBy:(RSDataPoint)amount;
{
    if ( [[_s selection] locked] ) {
	[_s setStatusMessage:NSLocalizedString(@"The selection is locked in place. To move it, first choose \"Unlock\".", @"Status bar warning for locked selection")];
        return;
    }
    else if ( ![_s selected] || ![[_s selection] isMovable] ) {
        NSBeep();
        return;
    }
    
    // set up undo
    [_editor.undoer registerRepetitiveUndoWithObject:[_s selection] 
                                  action:@"setPosition" 
                                   state:NSValueFromDataPoint([[_s selection] position])
                                    name:NSLocalizedStringFromTable(@"Move Selection", @"UndoActions", @"Undo action name")];
    
    RSDataPoint new = [[_s selection] position];
    new.x += amount.x;
    new.y += amount.y;
    
    // do the moving:
    [[RSTool elementsToMove:[_s selection]] setPosition:new];
    
    // update status message:
    [_s setStatusMessage:[[_s selection] infoString]];
    
    [_editor modelChangeRequires:RSUpdateConstraints];
}



/////////////
// a hack to set the screen to default size
// the key combo is ctrl-option-delete
- (void)deleteWordBackward:(id)sender {
    NSRect frame = [[self window] frame];
    frame.origin.y += frame.size.height - 500;
    frame.size.width = 600;
    frame.size.height = 500;
    [[self window] setFrame:frame display:YES];
}

// Temporary hack to add fake data
// the key combo is command-shift-up
- (void)moveToBeginningOfDocumentAndModifySelection:(id)sender;
{
    [self generateStandardNormalData:sender];
}


// "Escape" key pressed
- (void)cancelOperation:(NSEvent *)event {
    DEBUG_RS(@"escape key pressed");
    
    [self discardEditing];
    
    [[self currentTool] cancelOperation:event];
}

- (void)deleteBackward:(id)sender {
    //NSLog(@"Delete backwards called");
    [self delete:sender];
}
- (void)deleteForward:(id)sender {
    [self delete:sender];
}

- (IBAction)delete:(id)sender;
{
    if ( [_s selected] ) {
        // Delete child vertices too if they will be invisible without the parent
        RSGraphElement *toDelete = [RSGraph elementsToDelete:[_s selection]];
        
	// Only delete vertices if all of their parents or none of their parents are also selected
	toDelete = [RSGraph omitVerticesWithSomeParentsNotInGroup:toDelete];
	
	// remove selection from graph:
	[_editor.graph removeElement:toDelete];
	
	[self deselect];
	[self mouseMoved:nil];	// update everything
    }
    
    else if( [_m mode] == RS_draw || [_m mode] == RS_fill ) {
	[[self currentTool] delete:sender];
    }
    
    [_editor.undoer endRepetitiveUndo];
}

- (void)insertNewline:(id)sender;
{
    DEBUG_RS(@"insertNewline: called");
    
    [[self currentTool] insertNewline:sender];
}

- (void)insertTab:(id)sender;
{
    DEBUG_RS(@"insertTab: called");
    
    RSTextLabel *next = [_editor.renderer nextLabel:[_s selection]];
    if (next) {
        [self setSelection:next];
    }
}

- (void)insertBacktab:(id)sender;  // (shift-tab)
{
    DEBUG_RS(@"insertBacktab: called");
    
    RSTextLabel *next = [_editor.renderer previousLabel:[_s selection]];
    if (next) {
        [self setSelection:next];
    }
}



//////////////////////////////////////////
#pragma mark -
#pragma mark Text handling
//////////////////////////////////////////

// OBFinishPorting: There is likely a utility method here that can be moved into shared code for the iPad's use, depending on how label editing works there.
- (void)_updateFrameOfTextViewForLabel:(RSTextLabel *)TL;
{
    if (!TL) {
        OBASSERT_NOT_REACHED("No text label specified.");
        return;
    }
    if (!_textView) {
        OBASSERT_NOT_REACHED("There is no field editor");
        return;
    }
    
    //
    // Calculate frame size
    NSSize insetSize = [_textView textContainerInset];
    NSSize textSize = [TL size];
    NSSize viewSize = NSMakeSize(textSize.width + insetSize.width*2+10, textSize.height + insetSize.height*2);
    
    CGPoint p = [_editor updatedLocationForEditedTextLabel:TL withSize:[TL size]];
    
    // Adjust for the apparent offsets of the text within the NSTextView
    if ([_textView frameRotation] == 90) {  // (different if label is rotated 90 degrees (as on the y-axis)
        p.x += insetSize.height + 1;
        p.y -= insetSize.width + 2;
    } else {
        p.x -= insetSize.width + 2;
        p.y -= insetSize.height + 1;
    }
    
    //
    // Set the text view's frame
    NSRect oldFrame = [_textView frame];
    NSRect frame;
    frame.size = viewSize;
    frame.origin = p;
    [_textView setFrame:frame];
    
    if (!NSEqualRects(oldFrame, frame)) {
	[_textView setNeedsDisplay:YES];
        
        //if (!NSContainsRect(frame, oldFrame)) {
            [self setNeedsDisplay:YES];
        //}
    }
}

- (NSTextView *)_setupFieldEditorForLabel:(RSTextLabel *)TL;
{
    NSWindow *myWindow = [self window];
    BOOL madeFirstReponder = [myWindow makeFirstResponder:myWindow];
    if (!madeFirstReponder) {
        // Force first responder to resign.
        DEBUG_RS(@"Using endEditingFor: to force first responder to resign.");
        [myWindow endEditingFor:nil];
    }
    
    // All fields are now valid; it’s safe to use fieldEditor:forObject: to claim the field editor.
    NSTextView *fieldEditor = (NSTextView *)[myWindow fieldEditor:YES forObject:TL];
    OBASSERT([fieldEditor isKindOfClass:[NSTextView class]]);
    
    [fieldEditor setDelegate:self];
    [[fieldEditor textStorage] setAttributedString:[TL attributedString]];
    [[fieldEditor textStorage] setDelegate:self];
    
    [fieldEditor setTextContainerInset:NSMakeSize(0, 1)];
    [[fieldEditor textContainer] setLineFragmentPadding:2];
    
    if ( [TL rotation] == 90 ) {  // special case for Y axis
        [fieldEditor setFrameRotation:90];
    }
    else {
        [fieldEditor setFrameRotation:0];
    }
    
    return fieldEditor;
}

- (void)processTextChange;
{
    _textViewNeedsUpdate = NO;
    
    if (!_textView) {
	OBASSERT_NOT_REACHED("textDidChange: shouldn't be called if there is no textView");
	return;
    }
    
    NSAttributedString *attributedString = [(NSTextView *)_textView textStorage];
    
    // No need to update the frame if the string hasn't actually changed.
    if ([[[_s selection] attributedString] isEqual:attributedString])
        return;
    
    //DEBUG_RS(@"processTextChange");
    
    if ( [_graph axisOfElement:[_s selection]] ) {
	if (![attributedString length]) {
	    return;
	}
	
	[[_s selection] setAttributedString:attributedString];
        
        if ([_editor.graph isAxisEndLabel:[_s selection]]) {
            // axis range will probably change, so register the undo events now so they get grouped together with the text change.  <bug://bugs/53291>
            [_editor.graph prepareUndoForAxisRanges];
        }
	
        // OBFinishPorting: Why don't these happen in response to KVO/notifications triggered by -setAttributedString: above?
	[_editor setNeedsUpdateWhitespace];
	[_editor updateDisplayNow];  // (So subsequent data mapper conversions are correct)
    }
    else {
	[[_s selection] setAttributedString:attributedString];
    }
    
    //[(NSText *)_textView sizeToFit];
    [self _updateFrameOfTextViewForLabel:(RSTextLabel *)[_s selection]];
    
    [_s sendChange:self];
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification;
// This is called whenever the text storage changes at all, including as tentative characters are displayed when using chinese/japanese input methods. (e.g. Hiragana)
{
    // The frame cannot be changed until after the text layout has completed (otherwise an exception is thrown).
    // Delaying with [self queueSelectorOnce:@selector(processTextChange)]; results in a flicker as the tentative characters are displayed in their wrapped position before the frame change is called.
    
    _textViewNeedsUpdate = YES;
}

//- (void)textDidChange:(NSNotification *)note;
//// This is called when a character is confirmed into the text string.
//{
//    [self processTextChange];
//}

- (void)textDidEndEditing:(NSNotification *)note;
{
    //DEBUG_RS(@"RSGraphView handling textDidEndEditing");
    RSTextLabel *TL = (RSTextLabel *)[_s selection];
    RSGraph *graph = _editor.graph;
    
    if ( _textView && [graph isAxisEndLabel:TL] ) {
	
	NSString *stringValue = [(RSTextLabel *)[_s selection] text];
        [self stopEditingLabel];
        
        [_editor processText:stringValue forEditedLabel:TL];
        
	[_s sendChange:self];
    }
    
    [self stopEditingLabel];
    if (!_discardingEditing) {
        [self removeLabelIfEmpty:TL];
    }
    
    [_editor.undoer endRepetitiveUndo];
    
    // Potentially move on to the next/previous label
    NSInteger movementCode = [[note userInfo] integerForKey:@"NSTextMovement"];
    if (movementCode == NSTabTextMovement) {
        // ended editing with a tab
        RSTextLabel *next = [_editor.renderer nextLabel:TL];
        if (next) {
            [self setSelection:next];
            [self startEditingLabel];
        }
    }
    else if (movementCode == NSBacktabTextMovement) {
        // ended editing with a shift-tab
        RSTextLabel *next = [_editor.renderer previousLabel:TL];
        if (next) {
            [self setSelection:next];
            [self startEditingLabel];
        }
    }
}

- (void)startEditingLabel;
{
    if (_textView) {
        OBASSERT_NOT_REACHED("Can only edit one label at a time");
        return;
    }
    
    if (![_s selected] || ![[_s selection] isKindOfClass:[RSTextLabel class]]) {
        OBASSERT_NOT_REACHED("Selection must be a single text label in order to edit");
        return;
    }
    RSTextLabel *TL = (RSTextLabel *)[_s selection];
    
    [_editor.undoer endRepetitiveUndo];
    
    [self setTextSnapshot:[[[TL attributedString] copy] autorelease]];
    
    _textView = [self _setupFieldEditorForLabel:TL];
    [self _updateFrameOfTextViewForLabel:TL];
    
    [self addSubview:_textView];
    [[self window] makeFirstResponder:_textView];
    [_textView selectAll:self];
    
    [self setNeedsDisplay:YES];
}

- (RSTextLabel *)stopEditingLabel;
{
    if ( !_textView )
	return nil;
    
    // extract any changed font info:
    // no DON'T!  THIS SCREWS THINGS UP MAJORLY!
    //if ( [[_s selection] isText] ) {
    //	[[_s selection] setAttributes: [[_subview attributedStringValue] 
    //		attributesAtIndex:0 effectiveRange:NULL]];
    //}
    
    //new text editing//
    OBASSERT([_s selected] && [[_s selection] isKindOfClass:[RSTextLabel class]]);
    RSTextLabel *TL = (RSTextLabel *)[_s selection];
    
    // clear out undos related to the field editor
    [[_editor.undoer undoManager] removeAllActionsWithTarget:_textView];
    [[_editor.undoer undoManager] removeAllActionsWithTarget:[_textView textStorage]];
    
    [_textView removeFromSuperviewWithoutNeedingDisplay];  // is this necessary?
    [[self window] endEditingFor:[_s selection]];
    
    _textView = nil;
    [[self window] makeFirstResponder:self];
    
    [self setWasEditingText:YES];
    [self setNeedsDisplay:YES];
    
    return TL;
}

- (void)revertEditsForLabel:(RSTextLabel *)TL;
// Replace label text with the snapshot taken before label editing commenced
{
    [TL setAttributedString:[self textSnapshot]];
    [self setTextSnapshot:nil];
}

- (void)removeLabelIfEmpty:(RSTextLabel *)TL;
{
    if ([TL length] == 0) {
        [_editor.graph removeLabel:TL];
        
        if ([_s selection] == TL) {
            [self setSelection:nil];
        }
    }
}

@synthesize wasEditingText = _wasEditingText;

@synthesize textSnapshot = _textSnapshot;

- (BOOL)isEditingLabel;
{
    if (_textView)  return YES;
    else  return NO;
}



- (void)changeFont:(id)sender
{
    NSFont *oldFont;
    NSFont *newFont;
    
    Log1(@"changeFont");
    
    //[self stopEditingLabel];  // because weird things can happen in editing mode
    
    if( ![_s selected] )
	return;
    
    RSGraphElement<RSFontAttributes> *obj = (RSGraphElement<RSFontAttributes> *)[RSGraph labelFromElement:[_s selection]];
    if (!obj)
	return;
    
    // set up undo
    [_editor.undoer registerRepetitiveUndoWithObject:obj
                                              action:@"setFontDescriptor" 
                                               state:[obj fontDescriptor]
                                                name:NSLocalizedStringFromTable(@"Change Font", @"UndoActions", @"Undo action name")];
    
    oldFont = [[obj fontDescriptor] font];
    newFont = [sender convertFont:oldFont];
    
    OAFontDescriptor *newFontDescriptor = [[[OAFontDescriptor alloc] initWithFont:newFont] autorelease];
    
    // save defaults
    for (RSGraphElement *GE in [obj elements])
    {
	if( [GE isKindOfClass:[RSTextLabel class]] ) {
	    RSTextLabel *TL = (RSTextLabel *)GE;
	    
	    if( [_editor.graph isAxisTickLabel:TL] ) {
		;//[[OFPreferenceWrapper sharedPreferenceWrapper] setFontDescriptor:newFontDescriptor forKey:@"DefaultAxisTickLabelFont"];
	    } else if( [_editor.graph isAxisTitle:TL] ) {
		;//[[OFPreferenceWrapper sharedPreferenceWrapper] setFontDescriptor:newFontDescriptor forKey:@"DefaultAxisTitleFont"];
	    } else {
		[[OFPreferenceWrapper sharedPreferenceWrapper] setFontDescriptor:newFontDescriptor forKey:@"DefaultLabelFont"];
	    }
	}
	else if( [obj isKindOfClass:[RSAxis class]] ) {
	    ;//[[OFPreferenceWrapper sharedPreferenceWrapper] setFontDescriptor:newFontDescriptor forKey:@"DefaultAxisTickLabelFont"];
	}
    }
    
    [obj setFontDescriptor:newFontDescriptor];
    [_s sendChange:nil];
    
    
    Log2(@"leaving changeFont");
}


- (void)changeFont:(NSFont *)font toSize:(CGFloat)size {
    // make sure font panel exists
    [[NSFontManager sharedFontManager] fontPanel:YES];
    // use it to convert the font
    [NSFont setUserFont:font];
    [[NSFontManager sharedFontManager] setSelectedFont:[NSFont userFontOfSize:size] isMultiple:NO];
    [[NSFontManager sharedFontManager] modifyFontViaPanel:self];
}
// this is a hack
- (void)changeFontSizeBy:(NSInteger)delta {
    NSInteger steps;
    if( delta < 0 ) {
	steps = -delta;
	_fontActionTag = NSSizeDownFontAction;
    }
    else {
	steps = delta;
	_fontActionTag = NSSizeUpFontAction;
    }
    NSInteger i;
    for(i = 0; i<steps; i++ ) {
	[[NSFontManager sharedFontManager] modifyFont:self];
    }
}
- (NSInteger)tag {
    return _fontActionTag;
}


// we're co-opting the original toggleContinuousSpellChecking message
- (void)toggleContinuousSpellCheckingRS:(id)sender {
    
    BOOL flippedState = ! [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"UseContinuousSpellChecking"];
    
    // save the new preference:
    [[OFPreferenceWrapper sharedPreferenceWrapper] setBool:flippedState forKey:@"UseContinuousSpellChecking"];
    
    // update this preference in the current text input field, if editing
    // (otherwise, it will be updated on edit when [RSGraphView viewFromLabel:] is called)
    if( _textView ) {
	[(NSTextView *)[[self window] fieldEditor:YES forObject:nil] 
	 setContinuousSpellCheckingEnabled:flippedState];
    }
    
}



//////////////////////////////////////////
#pragma mark -
#pragma mark Cut, Copy, Paste
//////////////////////////////////////////

- (NSString *)_graphIdentifierForPasteboard;
{
    return [[_document fileURL] absoluteString];
}

- (void)writeElement:(RSGraphElement *)GE toPasteboard:(NSPasteboard *)pb;
{
    Log1(@"RSGraphView -writeElement:toPasteboard: called");
    // Declare types
    [pb declareTypes: [NSArray arrayWithObjects:RSGraphElementPboardType,
                       NSTabularTextPboardType,
                       NSStringPboardType, nil] owner:self];

    //////
    // Copy data onto the pasteboard

    GE = [RSGraph prepareForPasteboard:GE];

    if (!GE)
        return;

    // Native object data pasteboard type first
    NSString *graphID = [self _graphIdentifierForPasteboard];
    DEBUG_RS(@"graphID: %@", graphID);
    NSData *xmlData = [RSGraph archivedDataWithRootObject:GE graphID:graphID error:nil];
    [pb setData: xmlData
        forType: RSGraphElementPboardType];
    
    // Special case for text labels
    if ( [GE isKindOfClass:[RSTextLabel class]] ) {
        // Rich text
        NSAttributedString *attrString = [(RSTextLabel *)GE attributedString];
        NSData *rtfData = [attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil];
        [pb setData:rtfData forType:NSRTFPboardType];
        
        // Plain text
        NSString *text = [(RSTextLabel *)GE text];
        [pb setString:text forType:NSTabularTextPboardType];
        [pb setString:text forType:NSStringPboardType];
        return;
    }

    // Tabular and string data for other graph elements
    NSString *tabularStringRep = [RSGraph tabularStringRepresentationOfPointsIn:GE];
    if (tabularStringRep) {
        [pb setString:tabularStringRep forType:NSTabularTextPboardType];
        [pb setString:tabularStringRep forType:NSStringPboardType];
    }
}

- (IBAction)cut:(id)sender;
{
    if ( [_s selected] ) {
        [self copy:sender];
        [self delete:sender];
    }

    [_editor.undoer setActionName:NSLocalizedStringFromTable(@"Cut", @"UndoActions", @"Undo action name")];
}

- (IBAction)copy:(id)sender;
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];

    if ( [_s selected] ) {
        [self writeElement:[_s selection] toPasteboard:pb];
    }
    
    // Copy doesn't make any changes, so there's no undo
}





- (RSGraphElement *)importElementsFromString:(NSString *)string;
{
    RSGraphElement *everything = [[RSDataImporter sharedDataImporter] graphElementsFromString:string forGraph:_editor.graph connectSeries:_connectNextImport];
    
    if (!everything)
        return nil;
    
    // If just a single text label, position in the center
    if ([everything isKindOfClass:[RSTextLabel class]]) {
        [_editor.renderer centerLabelInCanvas:(RSTextLabel *)everything];
    }
    else {
        _importingData = YES;
    }
    
    // Return the master group with everything in it
    return everything;
}

- (NSString *)readableTypeOnPasteboard:(NSPasteboard *)pb;
// Returns the preferred object type (if any) for this view from the pasteboard pb.  If none, returns nil;
{
    NSString *type = [pb availableTypeFromArray:[NSArray arrayWithObjects:RSGraphElementPboardType,
						 OmniDataOnlyTabularPboardType,
						 NSTabularTextPboardType,  // prefer tabular text to plain text
						 NSStringPboardType, nil]];
    return type;
}

- (RSGraphElement *)readElementFromPasteboard:(NSPasteboard *)pb;
{
    DEBUG_RS(@"RSGraphView readElementFromPasteboard called");
    
    NSString *type = [self readableTypeOnPasteboard:pb];
    
    //
    // Copy/paste within the app
    //
    if ([type isEqual: RSGraphElementPboardType]) {
	_importingData = NO;
	// Read in the RSGraphElement from the pasteboard and return it:
	NSData *xmlData = [pb dataForType:RSGraphElementPboardType];
        
        NSString *graphID = nil;
        RSGraphElement *GE = [_graph unarchiveObjectWithData:xmlData getGraphID:&graphID error:nil];
        GE = [RSGraph prepareToPaste:GE];
        
        if (!GE) {
            NSLog(@"Graph elements were not actually found on the pasteboard.");
            return nil;
        }
        
        // Shift position to the tap location under limited circumstances.
//        BOOL pastedElementIsFromThisGraph = [graphID isEqualToString:[self _graphIdentifierForPasteboard]];
//        if( pastedElementIsFromThisGraph || [GE isKindOfClass:[RSTextLabel class]]) {
//            [GE setCenterPosition:_editMenuTapPoint];
//        }
        
        if (_connectNextImport) {
            GE = [_editor.graph changeLineTypeOf:GE toConnectMethod:defaultConnectMethod() sort:NO];
        }
        
        return GE;
    }
    
    //
    // Importing data from external files
    //
    if ([type isEqual: OmniDataOnlyTabularPboardType] || type == NSTabularTextPboardType || type == NSStringPboardType) {
	// Read in the NSString from the pasteboard and attempt to parse it into vertices.  This should return an array of RSGroups.  Each group represents an imported data series.
	
	return [self importElementsFromString:[pb stringForType:type]];
    }
    
    // No recognizable types found.
    return nil;
}

- (IBAction)paste:(id)sender
{
    [self pasteAndReplace:NO];  // don't replace
}

// OBFinishPorting: Most of this should be in the model.
- (void)pasteAndReplace:(BOOL)replace;
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    RSGraphElement *object;
    
    Log1(@"paste:");
    // parsing etc:
    object = [self readElementFromPasteboard:pb];
    if ( !object ) {
	NSBeep();
	_importingData = NO;
	return;
    }
    
    RSGraph *graph = _editor.graph;
    
    // Find out if the graph is starting out empty
    BOOL graphWasEmpty = NO;
    if( [[graph userElements] count] == 0 ) {
	graphWasEmpty = YES;
    }
    
    // shift down and to the right under very limited circumstances:
    if( !_importingData && [object isKindOfClass:[RSTextLabel class]] && ![[graph Labels] containsObject:object]) {
        float offset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
        [_mapper shiftElement:object byDelta:CGPointMake(offset, -offset)];
    }
    // Add the objects to be pasted:
    //
    // Replacing the selection:
    if( replace && [_s selected] && [RSGraph hasVertices:[_s selection]] 
       && [RSGraph hasVertices:object] ) {
	
	RSGroup *newGroup = [RSGroup groupWithGraph:graph];
	NSEnumerator *oldE = nil;
	NSEnumerator *newE = nil;
	
	if( [[_s selection] isKindOfClass:[RSGroup class]] ) {
	    oldE = [[(RSGroup *)[_s selection] elementsWithClass:[RSVertex class]] 
		    objectEnumerator];
	} else {
	    oldE = [[NSArray arrayWithObject:[_s selection]] objectEnumerator];
	}
	if( [object isKindOfClass:[RSGroup class]] ) {
	    newE = [[(RSGroup *)object elementsWithClass:[RSVertex class]] objectEnumerator];
	} else {
	    newE = [[NSArray arrayWithObject:object] objectEnumerator];
	}
	
	RSVertex *oldV;
	RSVertex *newV;
	RSVertex *lastOldV = nil;
	while ((oldV = [oldE nextObject])) {  // while there are still vertices to replace
	    if ((newV = [newE nextObject])) {  // an incoming vertex to replace with
		// set up undo
		[_editor.undoer registerUndoWithObject:oldV action:@"setPosition" 
				     state:NSValueFromDataPoint([oldV position])];
		// update the position
		[oldV setPosition:[newV position]];
		[graph setGroup:newGroup forElement:oldV];
		
		lastOldV = oldV;
	    }
	    else {  // no more incoming vertices
		[graph removeVertex:oldV];
	    }
	}
	while ((newV = [newE nextObject])) { // if more incoming vertices than old ones
	    if( lastOldV ) {
		[newV setWidth:[lastOldV width]];
		[newV setColor:[lastOldV color]];
		[newV setShape:[lastOldV shape]];
	    }
	    [graph addVertex:newV];
	    //
	    [graph setGroup:newGroup forElement:newV];
	}
	[self setSelection:newGroup];
	// lock in place
	if( _importingData && [object isKindOfClass:[RSGroup class]] && [object count] > 1 ) {
	    [[_s selection] setLocked:YES];
	}
    }
    ///////
    // just adding new objects (or fancy replace conditions didn't hold)
    else {  
	if( replace && [_s selected] ) { 
	    [graph removeElement:[_s selection]];
	}
	[graph addElement:object];
	[self setSelection:object];
	
	// Group data together and lock in place
//	    if( _importingData && [object isKindOfClass:[RSGroup class]] && [object count] > 1 ) {
//		
//		[graph setGroup:[RSGroup groupWithGraph:graph] forElement:[_s selection]];
//		[[_s selection] setLocked:YES];
//	    }
    }
    
    // Auto-rescale if necessary:
    [_editor.mapper scaleAxesForNewObjects:[object elements] importingData:_importingData];
    if (graphWasEmpty) {
        [_editor.mapper scaleAxesToShrinkIfNecessary];
    }
    
    if (_importingData) {
	[RSDataImporter finishInterpretingStringDataForGraph:graph];
    }
    
    // OBFinishPorting: This should happen automatically due to KVO/notifications
    [_editor autoRescueTextLabels];
    [_editor setNeedsUpdateWhitespace];
    
    _importingData = NO;
    
    [_editor.undoer setActionName:NSLocalizedStringFromTable(@"Paste", @"UndoActions", @"Undo action name")];
    [_editor.undoer endRepetitiveUndo];
}

- (IBAction)pasteAndConnect:(id)sender;
{
    _connectNextImport = YES;
    [self paste:nil];
    _connectNextImport = NO;
}

- (RSGraphElement *)duplicateElement:(RSGraphElement *)GE;
{
    OBASSERT(GE);
    
    // Make a special private pasteboard just for this duplicate operation
    NSPasteboard *pb = [NSPasteboard pasteboardWithName:@"OmniGraphSketcherDuplicatePasteboard"];
    
    // Copy and paste
    [self writeElement:GE toPasteboard:pb];
    RSGraphElement *duplicate = [self readElementFromPasteboard:pb];
    
    if (!duplicate)
        return nil;
    
    // Add the duplicate to the graph
    [_editor.graph addElement:duplicate];
    
    return duplicate;
}

- (IBAction)duplicate:(id)sender;
{
    if (![_s selected])
        return;
    
    RSGraphElement *duplicate = [self duplicateElement:[_s selection]];
    
    if (!duplicate)
        return;
    
    // shift down and to the right under very limited circumstances:
    if( [duplicate isKindOfClass:[RSTextLabel class]] ) {
        float offset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
        [_mapper shiftElement:duplicate byDelta:CGPointMake(offset, -offset)];
    }
    
    [self setSelection:duplicate];
    
    [_editor.undoer setActionName:NSLocalizedStringFromTable(@"Duplicate", @"UndoActions", @"Undo action name")];
    [_editor.undoer endRepetitiveUndo];
}


- (void)selectAll:(id)sender;
{
    Log3(@"RSGraphView selectAll called");
    [self setSelection:[_editor.graph userElements]];
}




//////////////////////////////////////////
#pragma mark -
#pragma mark Menu Item handling
//////////////////////////////////////////
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
// determine whether a menu is grayed out
{
    SEL menuAction = [menuItem action];
    
    // Use action so don't have to worry about localization
    if ( menuAction == @selector(cut:) ) {
	return [_s selected];
    }
    else if ( menuAction == @selector(copy:) ) {
	return [_s selected];
    }
    else if ( menuAction == @selector(paste:) ) {
	return [self readableTypeOnPasteboard:[NSPasteboard generalPasteboard]] != nil;
    }
    else if ( menuAction == @selector(pasteAndConnect:) ) {
	return [self readableTypeOnPasteboard:[NSPasteboard generalPasteboard]] != nil;
    }
    else if ( menuAction == @selector(pasteAndReplace:) ) {
	return [self readableTypeOnPasteboard:[NSPasteboard generalPasteboard]] != nil;
    }
    else if ( menuAction == @selector(duplicate:) ) {
	return [_s selected];
    }
    else if ( menuAction == @selector(delete:) ) {
	return [_s selected];
    }
    else if ( menuAction == @selector(deleteBackward:) ) {
	return [_s selected];
    }
    else if ( menuAction == @selector(deleteForward:) ) {
	return [_s selected];
    }
    else if ( menuAction == @selector(deselect:) ) {
	return [_s selected];
    }
    else if (menuAction == @selector(pasteAndReplace:)) {
	if( [_s selected] )  return YES;
	else  return NO;
    }
    else if ( (menuAction == @selector(selectConnected:))
	     || (menuAction == @selector(selectConnectedPoints:)) 
	     || (menuAction == @selector(selectConnectedLines:))
	     || (menuAction == @selector(selectConnectedLabels:)) ) {
	return ( [_s selected] && ![[_s selection] isPartOfAxis] );
    }
    else if ( menuAction == @selector(selectAllPoints:) ) {
	return ([[_graph Vertices] count] > 0);
    }
    else if ( menuAction == @selector(selectAllLines:) ) {
	return ([[_graph userLineElements] count] > 0);
    }
    else if ( menuAction == @selector(selectAllLabels:) ) {
	return ([[_graph allLabels] count] > 0);
    }
//    else if ( (menuAction == @selector(connectPoints:))
//	     || (menuAction == @selector(connectPointsLeftToRight:)) 
//	     || (menuAction == @selector(connectPointsTopToBottom:)) 
//	     || (menuAction == @selector(connectPointsCircular:))
//	     || (menuAction == @selector(connectPointsWithCurve:))  ) {
//	if ( [[_graph Vertices] count] > 1 ) return YES;
//	else return NO;
//    }
    else if ( menuAction == @selector(changeLineType:) ) {
        
        // Disable best-fit lines if there is a logarithmic axis
        if ([_graph hasLogarithmicAxis]) {
            RSConnectType connectMethod = [self connectMethodFromMenuTag:[menuItem tag]];
            if (connectMethod == RSConnectLinearRegression) {
                return NO;
            }
        }
        
	if (![_s selected]) {
	    if ([[_graph Vertices] count] > 1)
		return YES;
	}
	else if ([[_s selection] isKindOfClass:[RSLine class]]) {
	    return YES;
	}
	else if ([[_s selection] isKindOfClass:[RSGroup class]]) {
	    if ([(RSGroup *)[_s selection] numberOfElementsWithClass:[RSVertex class]] > 1)
		return YES;
	    if ([(RSGroup *)[_s selection] numberOfElementsWithClass:[RSLine class]] > 0)
		return YES;
	}
	return NO;
    }
    
    else if (menuAction == @selector(snapToGrid:)) {
	if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SnapToGrid"] ) {
	    [menuItem setState:NSOnState];
	} else {
	    [menuItem setState:NSOffState];
	}
	return YES;
    }
    else if (menuAction == @selector(displayGrid:)) {
	if ( [_graph displayGrid] ) {
	    //[menuItem setTitle:@"Hide Grid"];
	    [menuItem setState:NSOnState];
	} else {
	    //[menuItem setTitle:@"Display Grid"];
	    [menuItem setState:NSOffState];
	}
	return YES;
    }
    
    else if ( menuAction == @selector(changeScientificNotationX:) || menuAction == @selector(changeScientificNotation:) ) {
        NSInteger tag = [menuItem tag];  // these should correspond with the enum RSScientificNotationSetting
        
        if (tag == (NSInteger)[[_graph xAxis] scientificNotationSetting]) {
            [menuItem setState:NSOnState];
        }
        else {
            [menuItem setState:NSOffState];
        }
        return YES;
    }
    else if ( menuAction == @selector(changeScientificNotationY:) ) {
        NSInteger tag = [menuItem tag];  // these should correspond with the enum RSScientificNotationSetting
        
        if (tag == (NSInteger)[[_graph yAxis] scientificNotationSetting]) {
            [menuItem setState:NSOnState];
        }
        else {
            [menuItem setState:NSOffState];
        }
        return YES;
    }
    
    else if ( menuAction == @selector(groupUngroup:) ) {
	if( [_s selected] ) {
	    if( [[_s selection] group] ) {
		[menuItem setTitle:NSLocalizedString(@"Ungroup", @"Menu item")];
		return YES;
	    } 
	    else if ( [[_s selection] count] > 1 ) {
		[menuItem setTitle:NSLocalizedString(@"Group", @"Menu item")];
		return YES;
	    }
	    else {
		[menuItem setTitle:NSLocalizedString(@"Group", @"Menu item")];
		return NO;
	    }
	}
	else return NO;
    }
    else if ( menuAction == @selector(lockUnlock:) ) {
	if( [_s selected] && [[_s selection] isLockable] ) {
	    NSInteger count = [[_s selection] count];
	    if( ![[_s selection] locked] ) {
		if (count > 1)
		    [menuItem setTitle:NSLocalizedString(@"Lock Positions", @"Menu item")];
		else
		    [menuItem setTitle:NSLocalizedString(@"Lock Position", @"Menu item")];
	    } 
	    else {
		if (count > 1)
		    [menuItem setTitle:NSLocalizedString(@"Unlock Positions", @"Menu item")];
		else
		    [menuItem setTitle:NSLocalizedString(@"Unlock Position", @"Menu item")];
	    }
	    return YES;
	}
	else  return NO;
    }
    else if ( menuAction == @selector(detachElements:) ) {
	if( [_s selected] && [[_s selection] canBeDetached] ) {
	    return YES;
	}
	else  return NO;
    }
    
    
    else if (menuAction == @selector(fillArea:)) {
	if (![_s selected] || [[_s selection] isKindOfClass:[RSFill class]] || ![RSGraph hasAtLeastThreeVertices:[_s selection]])
	    return NO;
	else
	    return YES;
    }
    else if (menuAction == @selector(addPointToFill:)) {
	if ( [_s selected] && [RSGraph isPointAndFill:[_s selection]] )
	    return YES;
	else return NO;
    }
    else if (menuAction == @selector(histogram:)) {
	if ( [[_graph userVertexElements] numberOfElementsWithClass:[RSVertex class]] >= 1 )
	    return YES;
	else  return NO;
    }
    else if (menuAction == @selector(exportPDF:)) {
	return YES;
    }
    else if (menuAction == @selector(exportTIFF:)) {
	return YES;
    }
    else if (menuAction == @selector(toggleContinuousSpellCheckingRS:)) {
	return YES;
    }
    else if ( menuAction == @selector(toggleSuperscript:) 
	     || menuAction == @selector(toggleSubscript:) ) {
	if( _textView ) {
	    NSTextView *TV = (NSTextView *)[[self window] firstResponder];
	    NSAttributedString *selectedRange = [TV attributedSubstringFromRange:[TV selectedRange]];
	    // >0 means superscript, <0 means subscript
	    int isSuper = [[selectedRange attribute:NSSuperscriptAttributeName 
					    atIndex:0 effectiveRange:NULL] intValue];
	    if( (isSuper > 0 && menuAction == @selector(toggleSuperscript:))
	       || (isSuper < 0 && menuAction == @selector(toggleSubscript:)) ) {
		// is superscripted or subscripted
		[menuItem setState:NSOnState];
	    }
	    else {
		[menuItem setState:NSOffState];
	    }
	    // either way, menu item is selectable
	    return YES;
	}
	// doesn't work if we're not editing a label
	else  return NO;
    }
    else if (menuAction == @selector(makeErrorBars:)) {
        return ([[self allOrSelectedVertices] count] > 0);
    }
    else if (menuAction == @selector(generateStandardNormalData:)) {
        RSLine *L = [RSGraph isLine:[_s selection]];
        if (!L || [L isCurved])
            return NO;
        else
            return YES;
    }
    else if (menuAction == @selector(interpolateLinesToData:)) {
        NSUInteger count = [[self allOrSelectedLines] count];
        if (count == 1)
            [menuItem setTitle:NSLocalizedString(@"Interpolate Line", @"Menu item")];
        else
            [menuItem setTitle:NSLocalizedString(@"Interpolate Lines", @"Menu item")];
        
        return (count > 0);
    }
    else if (menuAction == @selector(addJitterToData:)) {
        return ([[self allOrSelectedVertices] count] > 0);
    }
    else if (menuAction == @selector(toggleDottedGrid:)) {
        if ([_graph xGrid].dotted) {
            [menuItem setState:NSOnState];
        } else {
            [menuItem setState:NSOffState];
        }
        return YES;
    }
    else if (menuAction == @selector(importDataInRows:)) {
        if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"ImportDataSeriesAsRows"]) {
            [menuItem setState:NSOnState];
        } else {
            [menuItem setState:NSOffState];
        }
        return YES;
    }
    else return YES;
}

// OBFinishPorting: GraphDocument catches actions and forwards them to us. Should just ensure that we get them in the first place by becoming the first responder or using OATargetSelection.
- (void)performMenuItem:(SEL)menuAction;
{
    [self performMenuItem:menuAction withName:nil];
}
- (void)performMenuItem:(SEL)menuAction withName:(NSString *)actionName;
{
    RSFill *F;
    //RSGroup *G;
    
    [_editor.undoer endRepetitiveUndo];
    
    
    if ( menuAction == @selector(selectConnected:) ) {
	[self setSelection:[_editor.graph elementsConnectedTo:[_s selection]]];
    }
    else if ( menuAction == @selector(selectConnectedPoints:) ) {
	[self setSelection:[[_editor.graph elementsConnectedTo:[_s selection]] 
			    elementWithClass:[RSVertex class]]];
    }
    else if ( menuAction == @selector(selectConnectedLines:) ) {
	[self setSelection:[[_editor.graph elementsConnectedTo:[_s selection]] 
			    elementWithClass:[RSLine class]]];
    }
    else if ( menuAction == @selector(selectConnectedLabels:) ) {
	[self setSelection:[[_editor.graph elementsConnectedTo:[_s selection]] 
			    elementWithClass:[RSTextLabel class]]];
    }
    else if ( menuAction == @selector(deselect:) ) {
	[self deselect];
    }
//    else if ( menuAction == @selector(connectPoints:) ) {
//	if ( [_s selected] && [RSGraph hasMultipleVertices:[_s selection]]) {
//	    G = [(RSGroup *)[_s selection] groupWithClass:[RSVertex class]];
//	}
//	else {
//	    G = (RSGroup *)[_graph userVertexElements];   // connects all vertices
//	}
//	RSConnectLine *L = [_graph connect:G];
//	[self setSelection:[L groupWithVertices]];
//	[self setNeedsDisplay:YES];
//    }
//    else if ( menuAction == @selector(connectPointsLeftToRight:) ) {
//	if ( [_s selected] && [RSGraph hasMultipleVertices:[_s selection]] ) {
//	    G = [(RSGroup *)[_s selection] groupWithClass:[RSVertex class]];
//	}
//	else { // connect all vertices
//	    G = [_graph userVertexElements];
//	}
//	[G sortElementsUsingSelector:@selector(xSort:)];
//	RSConnectLine *L = [_graph connect:G];
//	[self setSelection:[L groupWithVertices]];
//	[self setNeedsDisplay:YES];
//    }
//    else if ( menuAction == @selector(connectPointsTopToBottom:) ) {
//	if ( [_s selected] && [RSGraph hasMultipleVertices:[_s selection]] ) {
//	    G = [(RSGroup *)[_s selection] groupWithClass:[RSVertex class]];
//	}
//	else { // connect all vertices
//	    G = [_graph userVertexElements];
//	}
//	[G sortElementsUsingSelector:@selector(ySort:)];
//	RSConnectLine *L = [_graph connect:G];
//	[self setSelection:[L groupWithVertices]];
//	[self setNeedsDisplay:YES];
//    }
//    else if ( menuAction == @selector(connectPointsCircular:) ) {
//	if ( [_s selected] && [RSGraph hasMultipleVertices:[_s selection]] ) {
//	    G = [(RSGroup *)[_s selection] groupWithClass:[RSVertex class]];
//	}
//	else { // connect all vertices
//	    G = [_graph userVertexElements];
//	}
//	[_graph connectCircular:G];
//	[self setNeedsDisplay:YES];
//    }
    else if ( menuAction == @selector(pasteAndReplace:) ) {
	[self pasteAndReplace:YES];
    }
    else if ( menuAction == @selector(fillArea:) ) {
	if ([_s selected] && ![[_s selection] isKindOfClass:[RSFill class]] && [RSGraph hasAtLeastThreeVertices:[_s selection]]) {
            // else, make a fill
            [_graph addFill: [[[RSFill alloc] initWithGraph:_graph vertexGroup:[(RSGroup *)[_s selection] groupWithClass:[RSVertex class]]] autorelease]];
            [self setNeedsDisplay:YES];
        }
    }
    else if ( menuAction == @selector(addPointToFill:) ) {
	if ( [_s selected] && [RSGraph isPointAndFill:[_s selection]] ) {
	    F = (RSFill *)[(RSGroup *)[_s selection] firstElementWithClass:[RSFill class]];
	    // add the point to the fill
	    RSVertex *vertexToAdd = (RSVertex *)[(RSGroup *)[_s selection] firstElementWithClass:[RSVertex class]];
	    [_editor.graph addVertex:vertexToAdd toFill:F atIndex:[_editor.mapper bestIndexInFill:F forVertex:vertexToAdd]];
	    //maybe//[F polygonize];
	    // re-position the fill's label, if any
	    if ( [F label] ) {
		[_editor.renderer positionLabel:nil forOwner:F];
	    }
	}
	[self setNeedsDisplay:YES];
    }
    else if ( menuAction == @selector(scaleToFitData:) ) {
	[_editor.mapper scaleAxesToFitData];
	[_editor autoRescueTextLabels];
	[_editor.undoer setActionName:NSLocalizedStringFromTable(@"Scale to Fit Data", @"UndoActions", @"Undo action name")];
	
	[_editor setNeedsUpdateWhitespace];
    }
    else if ( menuAction == @selector(histogram:) ) {
	if ( [_graph displayHistogram] ) {
	    [_graph setDisplayHistogram:NO];
	}
	else {
	    [_graph setDisplayHistogram:YES];
	}
	[self setNeedsDisplay:YES];
    }
    else if ( menuAction == @selector(snapToGrid:) ) {
	[[OFPreferenceWrapper sharedPreferenceWrapper] setBool: ![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SnapToGrid"]
							forKey: @"SnapToGrid"];
	[self setNeedsDisplay:YES];
    }
    else if ( menuAction == @selector(displayGrid:) ) {
	[self showHideGrid:self];
    }
    else if ( menuAction == @selector(exportPNG:) ) {
        [self runExportPanelWithFileType:@"png" fileTypeName:@"PNG"];
        return;  // no undo
    }
    else if ( menuAction == @selector(exportJPG:) ) {
        [self runExportPanelWithFileType:@"jpg" fileTypeName:@"JPEG"];
        return;  // no undo
    }
    else if ( menuAction == @selector(exportPDF:) ) {
        [self runExportPanelWithFileType:@"pdf" fileTypeName:@"PDF"];
        return;  // no undo
    }
    else if ( menuAction == @selector(exportTIFF:) ) {
        [self runExportPanelWithFileType:@"tiff" fileTypeName:@"TIFF"];
        return;  // no undo
    }
    else if ( menuAction == @selector(exportEPS:) ) {
        [self runExportPanelWithFileType:@"eps" fileTypeName:@"EPS"];
        return;  // no undo
    }
    else if ( menuAction == @selector(cut:) ) {
	[self cut:nil];
    }
    else if ( menuAction == @selector(copy:) ) {
	[self copy:nil];
    }
    else if ( menuAction == @selector(paste:) ) {
	[self paste:nil];
    }
    else if ( menuAction == @selector(delete:) ) {
	[self delete:nil];
    }
    else if ( menuAction == @selector(deleteBackward:) ) {
	[self deleteBackward:nil];
    }
    else if ( menuAction == @selector(deleteForward:) ) {
	[self deleteForward:nil];
    }
    else if ( menuAction == @selector(toggleContinuousSpellCheckingRS:) ) {
	[self toggleContinuousSpellCheckingRS:nil];
    }
    else if ( menuAction == @selector(toggleSuperscript:) ) {
	if( _textView ) {
	    NSTextView *TV = (NSTextView *)[[self window] firstResponder];
	    NSRange selectedRange = [TV selectedRange];
	    if( selectedRange.length == 0 ) 
		selectedRange = NSMakeRange([[[_s selection] attributedString] length] - 1, 1);
	    NSAttributedString *selectedString = [TV attributedSubstringFromRange:selectedRange];
	    
	    // >0 means superscript, <0 means subscript
	    int isSuper = [[selectedString attribute:NSSuperscriptAttributeName 
					     atIndex:0 effectiveRange:NULL] intValue];
	    NSFont *font = [selectedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	    CGFloat fontSize = [font pointSize];
	    //NSLog(@"isSuper: %d", isSuper);
	    //CGFloat baseline = [[selectedRange attribute:NSBaselineOffsetAttributeName 
	    //								   atIndex:0 effectiveRange:NULL] doubleValue];
	    //NSLog(@"baseline: %f", baseline);
	    if( isSuper == 0 ) {  // should be superscripted
		[TV superscript:self];
		// make the text three points smaller.  
		[self changeFont:font toSize:fontSize*2/3];
	    }
	    else if( isSuper > 0 ) {  // should be un-superscripted
		[TV unscript:self];
		// make the text three points bigger.
		[self changeFont:font toSize:fontSize*3/2];
	    }
	    else {  // isSuper < 0 // should be superscripted, but no font size change
		[TV unscript:self];
		[TV superscript:self];
	    }
	}
    }
    else if ( menuAction == @selector(toggleSubscript:) ) {
	if( _textView ) {
	    NSTextView *TV = (NSTextView *)[[self window] firstResponder];
	    NSRange selectedRange = [TV selectedRange];
	    if( selectedRange.length == 0 ) 
		selectedRange = NSMakeRange([[[_s selection] attributedString] length] - 1, 1);
	    NSAttributedString *selectedString = [TV attributedSubstringFromRange:selectedRange];
	    
	    // >0 means superscript, <0 means subscript
	    int isSuper = [[selectedString attribute:NSSuperscriptAttributeName 
					     atIndex:0 effectiveRange:NULL] intValue];
	    NSFont *font = [selectedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	    CGFloat fontSize = [font pointSize];
	    
	    if( isSuper == 0 ) {  // should be subscripted
		// save old
		//[NSFont setUserFont:font];
		//
		[TV subscript:self];
		// make the text three points smaller.  
		//[self changeFontSizeBy:(-fontSize*0.334)];
		//[[NSFontManager sharedFontManager] setSelectedFont:[NSFont userFontOfSize:fontSize*2/3]
		//										isMultiple:NO];
		//[[NSFontManager sharedFontManager] modifyFontViaPanel:self];
		[self changeFont:font toSize:fontSize*2/3];
	    }
	    else if( isSuper < 0 ) {  // should be un-superscripted
		[TV unscript:self];
		// make the text three points bigger.
		//[self changeFontSizeBy:fontSize*0.5];
		[self changeFont:font toSize:fontSize*3/2];
	    }
	    else {  // isSuper > 0 // should be subscripted, but no font size change
		[TV unscript:self];
		[TV subscript:self];
	    }
	}
    }
    else {
	NSLog(@"ERROR: RSGraphView unsupported menu action called!");
    }

    
    if (actionName) {
        [_editor.undoer setActionName:actionName];
    }
    
    [[_editor undoer] endRepetitiveUndo];
}

- (IBAction)lockUnlock:(id)sender;
{
    if( [_s selected] ) {
	// set up undo
	[_editor.undoer registerUndoWithObject:[_s selection] 
			    action:@"setLocked" 
			     state:[NSNumber numberWithBool:[[_s selection] locked]]];
	
	if( [[_s selection] locked] ) {
	    [_editor.undoer setActionName:NSLocalizedStringFromTable(@"Unlock Positions", @"UndoActions", @"Undo action name")];
	    [[_s selection] setLocked:NO];  // unlock
	}
	else {
	    // set up undo
	    [_editor.undoer setActionName:NSLocalizedStringFromTable(@"Lock Items in Place", @"UndoActions", @"Undo action name")];
	    [[_s selection] setLocked:YES];  // lock
	} 
    }
}

- (IBAction)groupUngroup:(id)sender;
{
    if( [_s selected] ) {
	if( [[_s selection] group] ) {
	    [_editor.undoer setActionName:NSLocalizedStringFromTable(@"Ungroup Items", @"UndoActions", @"Undo action name")];
	    [_graph setGroup:nil forElement:[_s selection]];  // ungroup
	}
	else {
	    [_editor.undoer setActionName:NSLocalizedStringFromTable(@"Group Items Together", @"UndoActions", @"Undo action name")];
	    [_graph setGroup:[RSGroup groupWithGraph:_graph] forElement:[_s selection]];  // make a new grouping
	} 
    }
    
    if ([sender respondsToSelector:@selector(title)])
        [_editor.undoer setActionName:[sender title]];
}

- (IBAction)detachElements:(id)sender;
{
    if ([_s selected]) {
	[_graph detachElements:[_s selection]];
    }
    
    if ([sender respondsToSelector:@selector(title)])
        [_editor.undoer setActionName:[sender title]];
    
    [_s sendChange:nil];
}

- (IBAction)showHideGrid:(id)sender;
{
    BOOL boolState;
    if ( [_editor.graph displayGrid] ) {
	boolState = NO;
    } else {  // one or both is not currently displayed
	boolState = YES;
    }
    
    // make the change:
    [_editor.graph setDisplayGrid:boolState];
    
    // set user preference:
    //[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:boolState forKey:@"DisplayVerticalGrid"];
    //[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:boolState forKey:@"DisplayHorizontalGrid"];
    
    [_s sendChange:nil];
}

- (IBAction)changeScientificNotationX:(id)sender;
{
    OBASSERT([sender isKindOfClass:[NSMenuItem class]]);
    
    NSInteger tag = [sender tag];  // the tag should correspond with the enum RSScientificNotationSetting
    RSScientificNotationSetting setting = (RSScientificNotationSetting)tag;
    
    [_graph xAxis].scientificNotationSetting = setting;
}

- (IBAction)changeScientificNotationY:(id)sender;
{
    OBASSERT([sender isKindOfClass:[NSMenuItem class]]);
    
    NSInteger tag = [sender tag];  // the tag should correspond with the enum RSScientificNotationSetting
    RSScientificNotationSetting setting = (RSScientificNotationSetting)tag;
    
    [_graph yAxis].scientificNotationSetting = setting;
}

- (IBAction)changeScientificNotation:(id)sender;
{
    [self changeScientificNotationX:sender];
    [self changeScientificNotationY:sender];
}

- (RSConnectType)connectMethodFromMenuTag:(NSInteger)tag;
{
    switch (tag) {
	case 0:
	    return RSConnectStraight;
	    break;
	case 1:
	    return RSConnectCurved;
	    break;
	case 2:
	    return RSConnectLinearRegression;
	    break;
	case 3:
	    return RSConnectNone;
	    break;
	default:
	    OBASSERT_NOT_REACHED("Unknown segment tag");
	    break;
    }
    return RSConnectCurved;
}

- (IBAction)changeLineType:(id)sender;
{
    RSConnectType connectMethod = [self connectMethodFromMenuTag:[sender tag]];
    
    if (![_s selected]) {
	// Create a line from everything on the graph
	RSGraphElement *obj = [_editor.graph userVertexElements];
	if (obj)
	    [_s setSelection:obj];
	else
	    return;
    }
    
    RSGraphElement *newSelection = [_editor.graph changeLineTypeOf:[_s selection] toConnectMethod:connectMethod];
    [_s setSelection:newSelection];
    
    if (connectMethod == RSConnectCurved || connectMethod == RSConnectStraight) {
        // set default:
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:nameFromConnectMethod(connectMethod) forKey: @"DefaultConnectMethod"];
    }
    
    [_s sendChange:nil];
}



- (IBAction)selectAllPoints:(id)sender;
{
    [self setSelection:[_graph userVertexElements]];
}
- (IBAction)selectAllLines:(id)sender;
{
    [self setSelection:[_graph graphElementFromArray:[_graph userLineElements]]];
}
- (IBAction)selectAllFills:(id)sender;
{
    [self setSelection:[_graph userFillElements]];
}
- (IBAction)selectAllLabels:(id)sender;
{
    [self setSelection:[_graph allLabelElements]];
}


static ErrorBarSheet *errorBarSheet = nil;

- (IBAction)makeErrorBars:(id)sender;
{
    RSGraphElement *selection = [_s selection];
    if (![_s selected])
        selection = [_graph userVertexElements];
    
    if (![selection count])
        return;
    
    RSGraphElement *lines = [_graph createErrorBarsWithSelection:selection];
    
    // If no error bar lines were automatically created, display a sheet asking the user if they want to make constant-delta error bars instead
    if (!lines) {
        if (!errorBarSheet) {  // Load the error bar sheet if it hasn't been loaded yet
            errorBarSheet = [[ErrorBarSheet alloc] init];
        }
        
        NSMutableDictionary *contextInfo = [[NSMutableDictionary alloc] init];  // will be released in errorBarSheetDidEnd
        [contextInfo setValue:selection forKey:@"selection"];
        
        if ([sender respondsToSelector:@selector(title)])
            [contextInfo setValue:[sender title] forKey:@"undoActionName"];

        [NSApp beginSheet:[errorBarSheet window] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(errorBarSheetDidEnd:returnCode:contextInfo:) contextInfo:contextInfo];
        return;
    }
    
    if ([sender respondsToSelector:@selector(title)])
        [_editor.undoer setActionName:[sender title]];
    [_editor.undoer endRepetitiveUndo];
    
    [_s setSelection:lines];
}

- (void)errorBarSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:self];  // Necessary to actually remove the sheet from the window

    [(id)contextInfo autorelease];  // Was retained in makeErrorBars:
    
    if (returnCode == NSCancelButton) {
        return;
    }
    //else (returnCode == NSOKButton)
    
    RSGraphElement *selection = [(NSDictionary *)contextInfo valueForKey:@"selection"];
    RSGraphElement *result = [_graph createConstantErrorBarsWithSelection:selection posOffset:[errorBarSheet posOffset] negOffset:[errorBarSheet negOffset]];
    if (!result) {
        // No error bars were created for some reason.  Error message?
        return;
    }
    
    // The added error bars may have gone outside the visible graph area
    [_editor.mapper scaleAxesForNewObjects:[result elements] importingData:NO];
    
    NSString *undoActionName = [(NSDictionary *)contextInfo valueForKey:@"undoActionName"];
    if (undoActionName)
        [_editor.undoer setActionName:undoActionName];
    [_editor.undoer endRepetitiveUndo];
    
    [_s setSelection:result];
}


- (NSArray *)_generateDataFromLine:(RSLine *)L standardDeviation:(data_p)stddev;
{
    if (!L)
        return nil;
    
    if ([L isCurved])
        return nil;
    
    RSDataPoint p1 = [L startPoint];
    RSDataPoint p2 = [L endPoint];
    
    if (nearlyEqualDataValues(p2.x, p1.x))  // avoid divide by 0 (vertical line)
        return nil;
    
    data_p m = (p2.y - p1.y) / (p2.x - p1.x);
    data_p b = m * ( 0 - p1.x) + p1.y;
    
    data_p nmofPoints = 100;
    NSMutableArray *newVertices = [NSMutableArray array];
    
    data_p ymin = MIN(p1.y, p2.y);
    data_p ymax = MAX(p1.y, p2.y);
    /*data_p */stddev = (ymax - ymin)*0.2;
    
    data_p xmin = MIN(p1.x, p2.x);
    data_p xmax = MAX(p1.x, p2.x);
    data_p step = (xmax - xmin)/nmofPoints;
    OBASSERT(step > 0);
    
    for (data_p x = xmin; x <= xmax; x += step) {
        data_p randProb = random()/(data_p)RAND_MAX;
        data_p jitter = inverseNormalProbability(randProb);
        data_p y = m*x + b + jitter*stddev;
        
        // Make a vertex
        RSVertex *V = [[RSVertex alloc] initWithGraph:_graph];
        [V setPosition:RSDataPointMake(x, y)];
        [V setShape:RS_CIRCLE];
        [newVertices addObject:V];
        [V release];
    }
    
    return newVertices;
}

- (IBAction)generateStandardNormalData:(id)sender;
{
    RSLine *L = [RSGraph isLine:[_s selection]];
    if (!L)
        return;
    
    NSArray *array = [self _generateDataFromLine:L standardDeviation:0];
    
    if (![array count])
        return;
    
    RSGroup *newVertices = [[[RSGroup alloc] initWithGraph:_graph byCopyingArray:array] autorelease];
    [_graph addElement:newVertices];
    
    [_graph setGroup:[RSGroup groupWithGraph:_graph] forElement:newVertices];
    [_s setSelection:newVertices];
    
    if ([sender respondsToSelector:@selector(title)])
        [_editor.undoer setActionName:[sender title]];
    
    [self setNeedsDisplay:YES];
}

- (IBAction)interpolateLinesToData:(id)sender;
{
    NSArray *lines = [self allOrSelectedLines];
    if (![lines count])
        return;
    
    RSGroup *newSelection = [_editor interpolateLines:lines];
    [_s setSelection:newSelection];
    
    if ([sender respondsToSelector:@selector(title)])
        [_editor.undoer setActionName:[sender title]];
    
    [self setNeedsDisplay:YES];
}

- (IBAction)addJitterToData:(id)sender;
{
    NSArray *vertices = [self allOrSelectedVertices];
    if (![vertices count])
        return;
    
    // Do this in view coordinates so that it works for both linear and logarithmic axes. <bug:///70856>
    
    // Choose a standard deviation based on the y-range
    data_p stddev = ([_mapper viewMaxes].y - [_mapper viewMins].y) * RSAddJitterToDataPercentage;
    
    for (RSVertex *V in vertices) {
        RSDataPoint p = [V position];
        
        [_editor.undoer registerUndoWithObject:V action:@"setPosition" state:NSValueFromDataPoint(p)];
        
        CGFloat viewPos = [_mapper convertToViewCoords:p.y inDimension:RS_ORIENTATION_VERTICAL];
        viewPos = (CGFloat)addJitter(viewPos, stddev);

        p.y = [_mapper convertToDataCoords:viewPos inDimension:RS_ORIENTATION_VERTICAL];
        [V setPosition:p];
    }
    
    if ([sender respondsToSelector:@selector(title)])
        [_editor.undoer setActionName:[sender title]];
    
    [self setNeedsDisplay:YES];
}

- (IBAction)swapAxes:(id)sender;
{
    [_graph swapAxes];
}

- (IBAction)toggleTickLayoutAtData:(id)sender;
{
    BOOL always = ![_s selected] || ![[_s selection] isKindOfClass:[RSAxis class]];
    if (always || [_s selection] == [_graph xAxis]) {
        [[_graph xAxis] toggleTickLayoutAtData];
    }
    if (always || [_s selection] == [_graph yAxis]) {
        [[_graph yAxis] toggleTickLayoutAtData];
    }
}

- (IBAction)toggleAxesUseDataExtent:(id)sender;
{
    BOOL always = ![_s selected] || ![[_s selection] isKindOfClass:[RSAxis class]];
    if (always || [_s selection] == [_graph xAxis]) {
        if ([_graph xAxis].extent != RSAxisExtentDataRange)
            [_graph xAxis].extent = RSAxisExtentDataRange;
        else
            [_graph xAxis].extent = RSAxisExtentFull;
    }
    if (always || [_s selection] == [_graph yAxis]) {
        if ([_graph yAxis].extent != RSAxisExtentDataRange)
            [_graph yAxis].extent = RSAxisExtentDataRange;
        else
            [_graph yAxis].extent = RSAxisExtentFull;
    }
}

- (IBAction)toggleAxesUseDataQuartiles:(id)sender;
{
    BOOL always = ![_s selected] || ![[_s selection] isKindOfClass:[RSAxis class]];
    if (always || [_s selection] == [_graph xAxis]) {
        if ([_graph xAxis].extent != RSAxisExtentDataQuartiles)
            [_graph xAxis].extent = RSAxisExtentDataQuartiles;
        else
            [_graph xAxis].extent = RSAxisExtentFull;
    }
    if (always || [_s selection] == [_graph yAxis]) {
        if ([_graph yAxis].extent != RSAxisExtentDataQuartiles)
            [_graph yAxis].extent = RSAxisExtentDataQuartiles;
        else
            [_graph yAxis].extent = RSAxisExtentFull;
    }
}

- (IBAction)toggleDottedGrid:(id)sender;
{
    [_graph xGrid].dotted = ![_graph xGrid].dotted;
    [_graph yGrid].dotted = ![_graph yGrid].dotted;
    
    [self setNeedsDisplay:YES];
}

- (IBAction)addEquationLine:(id)sender;
{
    //NSLog(@"addEquationLine");
    
    // x^2 function
    RSEquation eq = { .type=RSEquationTypeSquare, .a=0, .b=0, .c=1 };
    
    // Cubic function
    if ([[sender title] rangeOfString:@"x^3"].location != NSNotFound) {
        eq.type = RSEquationTypeCube;
    }
    
    // Sine function
    if ([[sender title] rangeOfString:@"sin"].location != NSNotFound) {
        eq.type = RSEquationTypeSine;
    }
    
    // Bell curve (gaussian)
    else if ([[sender title] rangeOfString:@"e^(-x"].location != NSNotFound) {
        eq.type = RSEquationTypeGaussian;
    }
    
    // Logistic function
    else if ([[sender title] rangeOfString:@"/(1"].location != NSNotFound) {
        eq.type = RSEquationTypeLogistic;
    }
    
    RSEquationLine *EL = [[[RSEquationLine alloc] initWithGraph:_graph identifier:nil equation:eq] autorelease];
    [_graph addLine:EL];
    
    [self setSelection:EL];
}

- (IBAction)importDataSeriesReplacingCurrent:(id)sender;
{
    NSArray *prototypes = [_graph importedDataPrototypes];
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *type = [pb availableTypeFromArray:[NSArray arrayWithObjects:OmniDataOnlyTabularPboardType, NSTabularTextPboardType, NSStringPboardType, nil]];
    
    if (!type) {
        NSLog(@"A readable pasteboard type for data importing was not found.");
        return;
    }
    
    NSString *string = [pb stringForType:type];
    NSInteger numberOfSeries = 0;
    RSGraphElement *everything = [[RSDataImporter sharedDataImporter] graphElementsFromString:string forGraph:_editor.graph prototypes:prototypes connectSeries:YES found:&numberOfSeries];
    
    // Remove all of the prototype data series that are being replaced with imported data
    for (NSInteger i = 0; i < numberOfSeries; i += 1) {
        RSVertex *V = [prototypes objectAtIndex:i];
        RSGroup *group = [V group];
        if (!group) {
            group = [RSGroup groupWithGraph:V.graph];
            [group addElement:V];
        }
        RSLine *line = [V lastParentLine];
        if (line) {
            [group addElement:line];
            [group addElement:[line vertices]];
        }
        
        [_graph removeElement:group];
    }
    
    // Add the new data series to the graph
    [_graph addElement:everything];
    [self setSelection:everything];
    
    // Auto-rescale if necessary:
    [_editor.mapper scaleAxesForNewObjects:[everything elements] importingData:YES];
    
    [RSDataImporter finishInterpretingStringDataForGraph:_graph];
    
    // OBFinishPorting: This should happen automatically due to KVO/notifications
    [_editor autoRescueTextLabels];
    [_editor setNeedsUpdateWhitespace];
    
    _importingData = NO;
    
    [_editor.undoer setActionName:NSLocalizedStringFromTable(@"Import and Replace", @"UndoActions", @"Undo action name")];
    [_editor.undoer endRepetitiveUndo];

}

- (IBAction)importDataInRows:(id)sender;
{
    OFPreferenceWrapper *prefWrapper = [OFPreferenceWrapper sharedPreferenceWrapper];
    BOOL pref = [prefWrapper boolForKey:@"ImportDataSeriesAsRows"];
    
    [prefWrapper setBool:!pref forKey:@"ImportDataSeriesAsRows"];
}

- (IBAction)pasteWithOptions:(id)sender;
{
    static DataImportOptionsSheet *sheet = nil;
    if (!sheet) {
        sheet = [[DataImportOptionsSheet alloc] init];
    }
    
    NSMutableDictionary *contextInfo = [[NSMutableDictionary alloc] init];  // will be released in sheetDidEnd
    //[contextInfo setValue:selection forKey:@"selection"];
    
    if ([sender respondsToSelector:@selector(title)])
        [contextInfo setValue:[sender title] forKey:@"undoActionName"];
    
    [NSApp beginSheet:[sheet window] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(dataImportOptionsSheetDidEnd:returnCode:contextInfo:) contextInfo:contextInfo];
    return;
}

- (void)dataImportOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    [sheet orderOut:self];  // Necessary to actually remove the sheet from the window
    
    [(id)contextInfo autorelease];  // Was retained in pasteWithOptions:
    
    if (returnCode == NSCancelButton) {
        return;
    }
    //else (returnCode == NSOKButton)
    
    NSString *undoActionName = [(NSDictionary *)contextInfo valueForKey:@"undoActionName"];
    if (undoActionName)
        [_editor.undoer setActionName:undoActionName];
    [_editor.undoer endRepetitiveUndo];
}



//////////////////////////////////////////
#pragma mark -
#pragma mark Toolbar handling
//////////////////////////////////////////
- (BOOL)validateToolbarItem:(NSToolbarItem *)item;
{
    SEL sel = [item action];
    if (sel == @selector(lockUnlock:)) {
	
	if ([_s selected] && [[_s selection] isLockable]) {
	    if( ![[_s selection] locked] ) {
		[item setLabel:NSLocalizedString(@"Lock", @"Toolbar label")];
		[item setToolTip:NSLocalizedString(@"Lock position of the selected objects.", @"Toolbar item tooltip")];
		[item setImage:[NSImage imageNamed:@"lockIcon"]];
	    }
	    else {
		[item setLabel:NSLocalizedString(@"Unlock", @"Toolbar label")];
		[item setToolTip:NSLocalizedString(@"Unlock position of the selected objects.", @"Toolbar item tooltip")];
		[item setImage:[NSImage imageNamed:@"unlockIcon"]];
	    }
	    return YES;
	}
	else
	    return NO;
    }
    
    if (sel == @selector(groupUngroup:)) {
	
	if( [_s selected] ) {
	    if( [[_s selection] group] ) {
		[item setLabel:NSLocalizedString(@"Ungroup", @"Toolbar label")];
		[item setToolTip:NSLocalizedString(@"Ungroup the selected objects.", @"Toolbar item tooltip")];
		[item setImage:[NSImage imageNamed:@"ungroupIcon"]];
		return YES;
	    } 
	    else if ( [[_s selection] count] > 1 ) {
		[item setLabel:NSLocalizedString(@"Group", @"Toolbar label")];
		[item setToolTip:NSLocalizedString(@"Group the selected objects together.", @"Toolbar item tooltip")];
		[item setImage:[NSImage imageNamed:@"groupIcon"]];
		return YES;
	    }
	    else {
		[item setLabel:NSLocalizedString(@"Group", @"Toolbar label")];
		return NO;  // can't group just one item
	    }
	}
	else
	    return NO;
    }
    
    if (sel == @selector(detachElements:)) {
	if( [_s selected] && [[_s selection] canBeDetached] ) {
	    return YES;
	}
	else
	    return NO;
    }
    
    if (sel == @selector(showHideGrid:)) {
	if ([_graph displayGrid]) {
	    [item setLabel:NSLocalizedString(@"Hide Grid", @"Toolbar label")];
	    [item setToolTip:NSLocalizedString(@"Turn off grid lines", @"Toolbar item tooltip")];
	    [item setImage:[NSImage imageNamed:@"hideGridIcon"]];
	}
	else {
	    [item setLabel:NSLocalizedString(@"Show Grid", @"Toolbar label")];
	    [item setToolTip:NSLocalizedString(@"Turn on grid lines", @"Toolbar item tooltip")];
	    [item setImage:[NSImage imageNamed:@"showGridIcon"]];
	}
	return YES;
    }
    
    if (sel == @selector(makeErrorBars:)) {
        RSGraphElement *selection = [_s selection];
        if (![_s selected])
            selection = [_graph userVertexElements];
        
        if ([selection numberOfElementsWithClass:[RSVertex class]] >=1 )
            return YES;
        else
            return NO;
    }
    
    if (sel == @selector(interpolateLinesToData:)) {
        RSGraphElement *selection = [_s selection];
        return ([selection numberOfElementsWithClass:[RSLine class]] >=1);
    }
    
    if (sel == @selector(copyAsImage:)) {
	if (showWhaBam) {
	    [item setLabel:@"Wha-BAM!"];
	}
	else {
	    [item setLabel:NSLocalizedString(@"Copy As Image", @"Toolbar label")];
	}
	return YES;
    }
    
    // If unknown
    return NO;
}



//////////////////////////////////////////
#pragma mark -
#pragma mark Exporting
//////////////////////////////////////////
- (void)runExportPanelWithFileType:(NSString *)fileType fileTypeName:(NSString *)fileTypeName;
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:fileType]];
    [savePanel setCanSelectHiddenExtension:YES];
    [savePanel setNameFieldLabel:NSLocalizedString(@"Export as:", @"Export panel name field label")];
    
    NSString *exportButtonFormat = NSLocalizedString(@"Export as %@", @"Export panel export button");
    NSString *exportButtonString = [NSString stringWithFormat:exportButtonFormat, fileTypeName];
    [savePanel setPrompt:exportButtonString];
    
    NSString *suggestedFileName = [_document displayName];
    if ([[suggestedFileName pathExtension] isEqualToString:@"ograph"]) {
        suggestedFileName = [suggestedFileName stringByDeletingPathExtension];
    }
    [savePanel setNameFieldStringValue:suggestedFileName];
    
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result)
    {
        if (result != NSFileHandlingPanelOKButton)
            return;
        
        [self commitEditing];
        [self setDrawingToScreen:NO];
        
        NSRect r = [self bounds];
        NSData *data = nil;
        
        if ([fileType isEqual:@"png"]) {
            data = [self dataWithPNGInsideRect: r];
        }
        else if ([fileType isEqual:@"jpg"]) {
            data = [self dataWithJPGInsideRect: r];
        }
        else if ([fileType isEqual:@"pdf"]) {
            data = [self dataWithPDFInsideRect: r];
        }
        else if ([fileType isEqual:@"tiff"]) {
            data = [self dataWithTIFFInsideRect: r];
        }
        else if ([fileType isEqual:@"eps"]) {
            data = [self dataWithEPSInsideRect: r];
        }
        else {
            NSLog(@"Export failed; export type was not supported!");
            return;
        }
        [data writeToURL:[savePanel URL] atomically:YES];
        
        [self setDrawingToScreen:YES];
    }];
    
}



#if 0
// Based on code in OmniGraffle's OGGraphic2Image.m
static NSData *imageIOData(NSData *sourceData, NSString *type)
{    
    if (sourceData == nil)
        return nil;
    
    CFStringRef destUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)type, kUTTypeImage);
    
    if (!destUTI)
        return nil;
    
    NSDictionary *sourceHint = [NSDictionary dictionaryWithObject:(id)kUTTypeTIFF forKey:(id)kCGImageSourceTypeIdentifierHint];
    CGImageSourceRef src = CGImageSourceCreateWithData((CFDataRef)sourceData, (CFDictionaryRef)sourceHint);
    
    if (src == NULL) {
        CFRelease(destUTI);
        return nil;
    }
    
    if (CGImageSourceGetStatus(src) != kCGImageStatusComplete || CGImageSourceGetCount(src) != 1) {
        CFRelease(destUTI);
        CFRelease(src);
        return nil;
    }
    
    CFDictionaryRef iProps = CGImageSourceCopyPropertiesAtIndex(src, 0, NULL);
    
    NSMutableDictionary *imageSettings = [NSMutableDictionary dictionaryWithDictionary: (NSDictionary *)iProps];
    NSMutableDictionary *tiffProps = [imageSettings objectForKey: (id)kCGImagePropertyTIFFDictionary];
    // Tiff properties includes kCGImagePropertyTIFFSoftware -- The name and version of the software used for image creation.
    
    if (tiffProps)
        tiffProps = [NSMutableDictionary dictionaryWithDictionary:tiffProps];
    else
        tiffProps = [NSMutableDictionary dictionary];
    [imageSettings setObject:tiffProps forKey:(id)kCGImagePropertyTIFFDictionary];
    
//    CGFloat quality = [[OAPreferenceController sharedPreferenceController] compressionFactor];
//    [imageSettings setObject:[NSNumber numberWithDouble:quality] forKey:(id)kCGImageDestinationLossyCompressionQuality];
    [tiffProps setObject:[NSNumber numberWithInt:NSTIFFCompressionLZW] forKey:(id)kCGImagePropertyTIFFCompression];    
    
//    CGFloat pixelsPerPoint = [[OAPreferenceController sharedPreferenceController] pixelsPerPoint];
    NSNumber *resolution = [NSNumber numberWithDouble:72/* * pixelsPerPoint*/];
    [imageSettings setObject:resolution forKey:(id)kCGImagePropertyDPIHeight];
    [imageSettings setObject:resolution forKey:(id)kCGImagePropertyDPIWidth];
    
    NSMutableData *dataOut = [NSMutableData data];
    CGImageDestinationRef writer = CGImageDestinationCreateWithData((CFMutableDataRef)dataOut, destUTI, 1, NULL);
    CFRelease(destUTI);
    
    CGImageDestinationAddImageFromSource(writer, src, 0, (CFDictionaryRef)imageSettings);
    BOOL status = CGImageDestinationFinalize(writer);
    CFRelease(writer);    
    CFRelease(iProps);
    CFRelease(src);
    if (!status)
        return nil;
    return dataOut;
}
#endif

- (NSImage *)bitmapImage;
{
    NSSize integralImageSize = [self bounds].size;
    NSImage *image = [[NSImage allocWithZone:[self zone]] initWithSize:integralImageSize];
    //[image setFlipped:YES];
    if (!image) {
        NSLog(@"Unable to create an image %d by %d pixels", (int)integralImageSize.width, (int)integralImageSize.height);
        return nil;
    }
    
    [self lockFocus];
    [self drawRect:[self bounds]];
    NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[self bounds]];
    [self unlockFocus];
    
    [image addRepresentation:bitmapImageRep];
    [bitmapImageRep release];
    
    return [image autorelease];
}

- (NSData *)dataWithPNGInsideRect:(NSRect)r
{
    [self lockFocus];
    [self drawRect:[self bounds]];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:r];
    [self unlockFocus];
    
    NSData *imgData = [rep representationUsingType:NSPNGFileType properties:
		       [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:NSImageInterlaced]];
    
    [rep release];
    
    [self setNeedsDisplay:YES];
    return imgData;
    
//    NSImage *image = [self bitmapImage];
//    [self setNeedsDisplay:YES];
//    return imageIOData([image TIFFRepresentation], @"PNG");
}

- (NSData *)dataWithJPGInsideRect:(NSRect)r
{
    [self lockFocus];
    [self drawRect:[self bounds]];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:r];
    [self unlockFocus];
    
    NSData *jpegData = [rep representationUsingType:NSJPEGFileType properties:
			[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:1] forKey:NSImageCompressionFactor]];
    
    [rep release];
    
    [self setNeedsDisplay:YES];
    return jpegData;
}

- (NSData *)dataWithTIFFInsideRect:(NSRect)r
{
    [self lockFocus];
    [self drawRect:[self bounds]];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:r];
    [self unlockFocus];
    
    NSData *tiffData = [rep TIFFRepresentation];
    
    [rep release];
    
    [self setNeedsDisplay:YES];
    return tiffData;
}


//////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Utility methods
/////////////////////////////////////////
// NOTE:  In the RSGraph, all coordinates are stored as "data coords" -- coords according to the current scale of the axes defined by the user.  This way, the actual size of the view isn't inherent in the data storage structure, and when the axes are changed, the objects will automatically scale with them.


- (void)deselect 
{
    [self stopEditingLabel];
    if( [_s deselect] ) {
	[_s sendChange:nil];
    }
    //[[self window] invalidateCursorRectsForView:self];
}
- (void)setSelection:(RSGraphElement *)obj 
{
    if ([_s selection] == obj)
        return;
    
    [self stopEditingLabel];
    [_s setSelection:obj];
    [_s sendChange:self];
    [self setNeedsDisplay:YES];
    //[[self window] invalidateCursorRectsForView:self];
}


- (NSArray *)allOrSelectedVertices;
{
    if ([_s selected]) {
        RSGraphElement *selection = [_s selection];
        if ([selection isKindOfClass:[RSVertex class]]) {
            return [NSArray arrayWithObject:selection];
        }        
        if ([selection isKindOfClass:[RSGroup class]]) {
            return [(RSGroup *)selection elementsWithClass:[RSVertex class]];
        }
        return nil;
    }
    
    // If no selection, return all vertices on the graph
    return [[_graph userVertexElements] elements];
}

- (NSArray *)allOrSelectedLines;
{
    if ([_s selected]) {
        RSGraphElement *selection = [_s selection];
        
        RSLine *L = [RSGraph isLine:selection];
        if (L) {
            return [NSArray arrayWithObject:L];
        }
        
        if ([selection isKindOfClass:[RSGroup class]]) {
            return [(RSGroup *)selection elementsWithClass:[RSLine class]];
        }
        return nil;
    }
    
    // If no selection, return all lines on the graph
    return [_graph userLineElements];
}





/////////////////////////////////////////////
#pragma mark -
#pragma mark EXPERIMENTAL
////

//- (int *)computeHistogramBins:(int *)bins;
//{
//    RSVertex *V;
//    
//    int i;
//    for( i=0; i<500; i++ ) {
//	bins[i] = 0;
//    }
//    float max = [_graph xMax];
//    float min = [_graph xMin];
//    float range = max - min;
//    float spacing = [[_graph xAxis] spacing];
//    
//    for (V in [_graph Vertices])
//    {
//	float x = [V position].x;
//	int bin = floor((x - min)/spacing);
//	bins[bin]++;
//    }
//    
//    int nmofBins = ceil(range/spacing);
//    bins[nmofBins] = -1; // specify the first empty bin
//    
//    NSString *s = [NSString stringWithFormat:@"bin counts: "];
//    int b;
//    for( b=0; b<nmofBins; b++ ) {
//	s = [s stringByAppendingFormat:@"%d,",bins[b]];
//    }
//    Log2(@"%@", s);
//    
//    return bins;
//}



////////////////////////////////////////////
#pragma mark -
#pragma mark DEBUGGING
////////////////////////////////////////////

#ifdef DEBUG


//- (void)drawControlPoints {
//    NSBezierPath *P;
//    
//    NSPoint p0, p1, p2, p3, r1, r2, c;
//    float extra;
//    
//    Log2(@"Drawing control points");
//    for (RSLine *L in [_graph Lines])
//    {
//	if( [L isCurved] ) {
//	    
//            // UNFINISHED
//            
//	    // calculate control points:
//	    p0 = [L startPoint];
//	    p3 = [L endPoint];
//	    c = [L curvePoint];
//	    extra = 1.3333;  // (4/3)
//	    
//	    r1.x = (c.x - p0.x)*extra;  // rays to control points
//	    r1.y = (c.y - p0.y)*extra;
//	    r2.x = (c.x - p3.x)*extra;
//	    r2.y = (c.y - p3.y)*extra;
//	    
//	    p1.x = p3.x + r2.x;  // control points
//	    p1.y = p3.y + r2.y;
//	    p2.x = p0.x + r1.x;
//	    p2.y = p0.y + r1.y;
//	    
//	    P = [NSBezierPath bezierPath];
//	    [P moveToPoint:[_mapper convertToViewCoords:p0]];
//	    [P lineToPoint:[_mapper convertToViewCoords:p2]];
//	    [P lineToPoint:[_mapper convertToViewCoords:p3]];
//	    [P lineToPoint:[_mapper convertToViewCoords:p1]];
//	    [P lineToPoint:[_mapper convertToViewCoords:p0]];
//	    [P moveToPoint:[_mapper convertToViewCoords:p1]];
//	    [P lineToPoint:[_mapper convertToViewCoords:p2]];
//	    [P moveToPoint:[_mapper convertToViewCoords:p0]];
//	    [P lineToPoint:[_mapper convertToViewCoords:p3]];
//	    [[[NSColor redColor] colorWithAlphaComponent:0.5] set];
//	    [P setLineWidth:1.0];
//	    [P stroke];
//	    
//	    //unfinished:
//	    c = [_mapper convertToViewCoords:c];
//	    NSBezierPath *P2 = [NSBezierPath bezierPath];
//	    [P2 moveToPoint:[_mapper convertToViewCoords:p0]];
//	}
//    }
//}


// for testing
//- (void)drawCurveFromVertexArray:(NSArray *)VArray {
//    RSVertex *V;
//    NSInteger n = [VArray count] - 1;  // number of points p, minus 1
//    
//    if( n < 2 )  return;  // so far this only works for 2 <= n <= 8
//    
//    NSPoint p[n+1];  // array of points p
//    // populate array of points
//    NSInteger i = 0;
//    for (V in VArray) {
//	p[i++] = [_mapper convertToViewCoords:[V position]];
//    }
//    
//    // create the a_m_k array, which "starts" at [3][1] and thus has size [16+3][7+1]
//    CGFloat a[19][8] =
//    /*a =*/ {
//	{  },
//	{  },
//	{  },
//	{ 0, 0.333f },  // n=3
//	{ 0, 0.25f },  // n=4
//	{ 0, 0.2727f, -0.0909f },  // n=5
//	{ 0, 0.2677f, -0.0667f },  // n=6
//	{ 0, 0.2683f, -0.0732f, 0.0244f },  // n=7
//	{ 0, 0.2679f, -0.0714f, 0.0179f },  // n=8
//	{ 0, 0.2680f, -0.0719f, 0.0196f, -0.0065f },  // n=9
//	{ 0, 0.2679f, -0.0718f, 0.0191f, -0.0048f },  // n=10
//	{ 0, 0.2680f, -0.0718f, 0.0193f, -0.0053f, 0.0018f },  // n=11
//	{ 0, 0.2679f, -0.0718f, 0.0192f, -0.0051f, 0.0013f },  // n=12
//	{ 0, 0.2679f, -0.0718f, 0.0192f, -0.0052f, 0.0014f, -0.0005f },  // n=13
//	{ 0, 0.2679f, -0.0718f, 0.0192f, -0.0052f, 0.0014f, -0.0003f },  // n=14
//	{ 0, 0.2679f, -0.0718f, 0.0192f, -0.0052f, 0.0014f, -0.0004f, 0.0001f },  // n=15
//	{ 0, 0.2679f, -0.0718f, 0.0192f, -0.0052f, 0.0014f, -0.0004f, 0.0001f }  // n=16
//    };
//    
//    //NSLog(@"%f, %f, %f", a[8][1], a[8][6], a[10][3]);
//    
//    //NSLog(@"%d", 13%7);
//    //return;
//    
//    
//    // choose initial/final tangent vectors d_0 and d_n
//    NSPoint d[n+1];
//    /* */
//    // do essentially the original thing from simple curves
//    CGFloat extra = 1.33333f;  // (4/3)
//    CGFloat reduce = 0.5f;
//    // first control point
//    NSPoint cp, ray, p0, p1, p2;
//    p0 = p[0];
//    p1 = p[1];
//    p2 = p[2];
//    ray.x = (p1.x - p2.x)*extra;
//    ray.y = (p1.y - p2.y)*extra;
//    cp.x = p2.x + ray.x;
//    cp.y = p2.y + ray.y;
//    // derive vector d_0
//    d[0].x = (cp.x - p0.x)*reduce;
//    d[0].y = (cp.y - p0.y)*reduce;
//    
//    [RSGraphRenderer drawCircleAt:cp];
//    
//    // second control point
//    p0 = p[n];
//    p1 = p[n - 1];
//    p2 = p[n - 2];
//    ray.x = (p1.x - p2.x)*extra;
//    ray.y = (p1.y - p2.y)*extra;
//    cp.x = p2.x + ray.x;
//    cp.y = p2.y + ray.y;
//    // derive vector d_n
//    d[n].x = (p0.x - cp.x)*reduce;
//    d[n].y = (p0.y - cp.y)*reduce;
//    
//    [RSGraphRenderer drawCircleAt:cp];
//    //[RSGraphRenderer drawCircleAt:d[1]];
//    
//    
//    //d[0] = NSMakePoint(0,0);
//    //d[n] = NSMakePoint(0,0);
//    
//    
//    // construct the t's
//    NSPoint t[2*n];
//    // the initial/final special cases
//    t[0].x = p[0].x + d[0].x;
//    t[0].y = p[0].y + d[0].y;
//    t[n].x = p[n].x - d[n].x;
//    t[n].y = p[n].y - d[n].y;
//    // the rest
//    for(i=1; i<n; i++) {
//	t[i] = p[i];  // t_i = p_i for 0 < i < n
//    }
//    for(i=1; i<n; i++) {
//	t[2*n - i] = t[i];  // t_2n-i = t_i for 0 < i < n
//    }
//    
//    
//    // calculate the array of vectors d_i
//    NSInteger k, m, row;
//    for(i=1; i<n; i++) {
//	//if( n%2 == 1 )  m = n/2;  // if odd, n = 2m + 2
//	//else  m = n/2 - 1;  // if even, n = 2m + 2
//	//NSLog(@"m = %d", m);
//	
//	m = n - 1;
//	row = n*2;
//	if( m > 7 ) {
//	    m = 7;  // never have to consider more than 7 steps away from current point
//	    row = 14;  // the k_n_m table only extends so far
//	}
//	
//	d[i].x = 0;
//	d[i].y = 0;
//	for(k=1; k<=m; k++) {
//	    //NSLog(@"a[m][k] = %f", a[m][k]);
//	    d[i].x += a[row][k]*(t[i+k].x - t[RSReflect(i-k, n)].x);
//	    d[i].y += a[row][k]*(t[i+k].y - t[RSReflect(i-k, n)].y);
//	}
//    }
//    
//    //NSLog(@"d[1]: (%f, %f)", d[1].x, d[1].y);
//    
//    // calculate the q's and the r's from the p's and the d's
//    NSPoint q[n+1];
//    NSPoint r[n+1];
//    for(i=0; i<n; i++) {
//	q[i].x = p[i].x + d[i].x;
//	q[i].y = p[i].y + d[i].y;
//	r[i].x = p[i+1].x - d[i+1].x;
//	r[i].y = p[i+1].y - d[i+1].y;
//	//r[RSReflect(i-1, n)].x = p[i].x - d[i].x;
//	//r[RSReflect(i-1, n)].y = p[i].y - d[i].y;
//    }
//    
//    // construct a bezier path
//    NSBezierPath *P = [NSBezierPath bezierPath];
//    [P moveToPoint:p[0]];
//    for( i=0; i<n; i++ ) {
//	[P curveToPoint:p[i+1] controlPoint1:q[i] controlPoint2:r[i]];
//    }
//    
//    // draw the curve
//    [P setLineWidth:2];
//    [[NSColor blueColor] set];
//    [P stroke];
//}



- (void)testMethod
{
    //BOOL new = NO;
    //NSAttributedString *AS;
    RSTextLabel *T;
    RSDataPoint p;
    //NSSize size;
    //NSRect r;
    
    Log2(@"graphView testMethod");
    
    T = [[[RSTextLabel alloc] initWithGraph:_graph] autorelease];
    p.x = 10;
    p.y = 15;
    [T setPosition:p];
    [_graph addLabel:T];
    
    [_editor modelChangeRequires:RSUpdateConstraints];
    [_editor updateDisplayNow];
}
#endif

@end
