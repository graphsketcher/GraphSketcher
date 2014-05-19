// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "GraphWindowController.h"

#import "AppController.h"
#import "GraphDocument.h"
#import "RSGraphView.h"
#import "RSMode.h"

#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSTextLabel.h>

#import <OmniInspector/OIInspectorRegistry.h>


@implementation GraphWindowController

////////////////////////////////////////////
#pragma mark -
#pragma mark Class methods
//////

- (void)saveGraphFrame {
    
    if ([[self document] isInAppBundle])  // Don't let the "Getting Started" graph affect the defaults
	return;
    
    NSString *frameString = [[self window] stringWithSavedFrame];
    //DEBUG_RS(@"%@", frameString);
    
    // make this the new default
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:frameString forKey:@"LastFrameString"];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:NSStringFromSize([[[self document] graph] canvasSize])
						      forKey:@"LastCanvasSize"];
}

- (void)setStatusMessage:(NSString *)message;
{
    if (!message)
        return;
    
    if (![[self window] isMainWindow])
	return;
    
    [_statusText setStringValue:message];
    
    //if( [message isEqualToString:@""] ) {
    //	[_statusText setBackgroundColor:[NSColor windowBackgroundColor]];
    //} else {
    //	[_statusText setBackgroundColor:
    //		[NSColor colorWithCalibratedHue:0.167 saturation:0.2 brightness:1.0 alpha:1.0] ];
    //}
}

- (void)updateWindowSize;
{
    DEBUG_RS(@"updateWindowSize");
    _updatingWindowSize = YES;
    
    NSRect frame = [[self window] frame];
    NSPoint topLeftPoint = NSMakePoint(frame.origin.x, frame.origin.y + frame.size.height);
    
    // Resize the actual window
    NSSize windowContentSize = [[[self document] graph] canvasSize];
    windowContentSize.height += WINDOW_BOTTOM_BAR_HEIGHT;  // space for the bottom status bar (setContentMinSize already takes the title bar into account)
    [[self window] setContentSize:windowContentSize];
    
    [[self window] setFrameTopLeftPoint:topLeftPoint];
    
    [_graphView.editor setNeedsUpdateWhitespace];
    
    //
    [self saveGraphFrame];
    
    // update the view
    [_graphView windowDidResize];
    
    // give user precise feedback in the status bar
    [self setStatusMessage:messageForCanvasSize([_graph canvasSize])];
    
    _updatingWindowSize = NO;
}

- (void)updateToolbarWithMode:(NSUInteger)newMode;
{
    if ( newMode == RS_none ) {
	[[self toolbar] setSelectedItemIdentifier:nil];
    }
    else if ( newMode == RS_modify ) {
	[[self toolbar] setSelectedItemIdentifier:@"ModifyTool"];
    }
    else if ( newMode == RS_draw ) {
	[[self toolbar] setSelectedItemIdentifier:@"DrawTool"];
    }
    else if ( newMode == RS_fill ) {
	[[self toolbar] setSelectedItemIdentifier:@"FillTool"];
    }
    else if ( newMode == RS_text ) {
	[[self toolbar] setSelectedItemIdentifier:@"TextTool"];
    }
}

- (void)documentGraphDidChange:(RSGraph *)newGraph;
{
    OBASSERT(newGraph != _graph);
    if (newGraph == _graph)
        return;
    
    // Clean up old graph, if it exists
    if (_graph) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        // Clear out KVO in the inspector panels
        [[[AppController sharedController] inspectorRegistry] clearInspectionSet];
        
        // KVO
        [_graph removeObserver:self forKeyPath:@"canvasSize"];
        [_graph removeObserver:self forKeyPath:@"whitespace"];
        
        [pool release];
        
        //[_graphView setGraph:nil];
        [_graph release];
    }
    
    _graph = [newGraph retain];
    
    if (_graph) {
        NSWindow *window = [self window];
        GraphDocument *document = [self document];
        
        // KVO
        [_graph addObserver:self forKeyPath:@"canvasSize" options:NSKeyValueObservingOptionNew context:NULL];
        [_graph addObserver:self forKeyPath:@"whitespace" options:NSKeyValueObservingOptionNew context:NULL];
        
        // Set window position
        // default "shouldCascadeWindows" is YES
        if ([document isFromFile]) {
            // Assume that if there is a non-zero point set, the graph wants it.
            if (!NSEqualPoints(_graph.frameOrigin, NSZeroPoint))
                [self setShouldCascadeWindows:NO];

            [window setFrameOrigin:_graph.frameOrigin];
        }
        else  // new, blank document
        {
            [window setFrameFromString:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:@"LastFrameString"]];
            [_graph setCanvasSize:[_graphView bounds].size];
        }
        
        // Set window size according to the graph's canvas size
        [self updateWindowSize];
        
        // Notify the RSGraphView
        _graphView.editor = document.editor; // this also updates the display etc.
        [_graphView mouseEntered:nil];
        
        // There should be no undos registered at this point. The document reading code should disable undos while doing its thing
        [[document undoer] endRepetitiveUndo]; // do this to ensure it is really empty (and we assert that it did nothing next).
        OBASSERT(![[document undoManager] canUndo]);
        OBASSERT(![[document undoManager] canRedo]);

        //[[[self document] undoer] setEnabled:YES];
        //[[[self document] undoManager] removeAllActions];
    }
    
}


////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
////////////////////////////////////////////////

- (id)init;
{
    self = [super initWithWindowNibName:@"GraphDocument"];
    if (self) {
        _graphView = nil;
        _statusText = nil;
        _graph = nil;
        _m = nil;
        
        _updatingWindowSize = NO;
        
        _textLabelFieldEditor = nil;
        
        DEBUG_RS(@"GraphWindowController init");
    }
    return self;
}

- (void)dealloc;
{
    // _graph should have been released in -windowDidClose:
    OBASSERT(!_graph);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}


////////////////////////////////////////////////
#pragma mark -
#pragma mark WindowController subclass
////////////////////////////////////////////////

- (void)awakeFromNib
// Anything that initializes nib elements needs to go here
// rather than in initWithFrame: above, because nib elements get
// initialized after initWithFrame: gets called.
{
    DEBUG_RS(@"awaking from nib");
    
    [[self document] setGraphView:_graphView];
    
    // save position to user defaults
    //now in IB//[[self window] setFrameAutosaveName:@"RSGraphDocumentFrame"];
    
    // Register for notifications
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self 
	   selector:@selector(changeToolbarMessageNotification:)
	       name:@"RSChangeToolbarMessage"
	     object:nil];
    // Register to receive notifications of an external change in mode
    [nc addObserver:self 
           selector:@selector(modeWillChangeNotification:)
               name:@"RSModeWillChange"
             object:nil];
    
    _m = [RSMode sharedModeController];
    [_m resetFlags];
}

- (void)windowDidLoad;
{
    [super windowDidLoad];
    
    DEBUG_RS(@"windowDidLoad");
    //[[[self document] undoer] setEnabled:NO];
    
    [self updateToolbarWithMode:[_m mode]];
    
    // setup graphView
    [_graphView setRSSelector:[[self document] selectorObject]];
    
    [self documentGraphDidChange:[[self document] graph]];
    
    // Register to receive future updates if the graph is changed, most likely because of Revert to Saved.
    [[self document] addObserver:self forKeyPath:@"graph" options:NSKeyValueObservingOptionNew context:NULL];
}



////////////////////////////////////////////////
#pragma mark -
#pragma mark OAToolbarWindowController subclass
////////////////////////////////////////////////

- (NSString *)toolbarConfigurationName; // file name to lookup .toolbar plist
{
    return @"Graph";
}
- (BOOL)shouldAllowUserToolbarCustomization;
{
    return YES;
}
- (BOOL)shouldAutosaveToolbarConfiguration;
{
    return YES;
}



////////////////////////////////////////////////
#pragma mark -
#pragma mark NSToolbar delegate
////////////////////////////////////////////////

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;
{
    NSMutableArray *identifiers = [NSMutableArray array];
    
    [identifiers addObject:@"ModifyTool"];
    [identifiers addObject:@"DrawTool"];
    [identifiers addObject:@"FillTool"];
    [identifiers addObject:@"TextTool"];
    
    return identifiers;
}

// These are called when the corresponding toolbar items are clicked.
- (void)selectModifyTool:(id)sender;
{
    [_m registerClick:RS_modify];
}
- (void)selectDrawTool:(id)sender;
{
    [_m registerClick:RS_draw];
}
- (void)selectFillTool:(id)sender;
{
    [_m registerClick:RS_fill];
}
- (void)selectTextTool:(id)sender;
{
    [_m registerClick:RS_text];
}


////////////////////////////////////////////////
#pragma mark -
#pragma mark Window delegate methods
////////////////////////////////////////////////
- (void)windowDidBecomeKey:(NSNotification *)note
{
    //DEBUG_RS(@"windowDidBecomeKey");
    
    // Tell graphView to wake up.  This has to be called both here and in -windowDidBecomeMain:, because it's not consistent which method gets called first.
    [_graphView mouseEntered:nil];
    
    // The graphView also needs to redisplay because the selection color will stop being gray.
    [_graphView setNeedsDisplay:YES];
}
- (void)windowDidResignKey:(NSNotification *)note;
{
    // The selection color should change to gray, so the graphView needs to redisplay.
    [_graphView setNeedsDisplay:YES];
}
- (void)windowDidBecomeMain:(NSNotification *)note
{
    //DEBUG_RS(@"windowDidBecomeMain");
    
    [self updateToolbarWithMode:[_m mode]];
    
    [self saveGraphFrame];
    
    [_m resetFlags];
    
    // tell graphView to wake up
    [_graphView mouseEntered:nil];
}
- (void)windowDidResignMain:(NSNotification *)note;
{
    [self updateToolbarWithMode:RS_none];
}

- (void)windowDidMove:(NSNotification *)note
// sent whenever document window is moved
{
    DEBUG_RS(@"windowDidMove");
    
    // if the window has awoken from nib...
    if( [[self window] isMainWindow] ) {
	[self saveGraphFrame];
    }
}
- (void)windowDidResize:(NSNotification *)note
// sent whenever document window resizes
{
    // This check ensures that the method does not get executed until the window has completely finished loading.  We'll have to find some other way to fix <bug://bugs/53783>
    if (![[self window] isMainWindow])
	return;
    
    if (_updatingWindowSize)
        return;
    
    DEBUG_RS(@"windowDidResize");
    
    // resize the whitespace instead of the graph area if the command key is held down
    RSGraph *graph = [[self document] graph];
    NSSize oldSize = [graph canvasSize];
    NSSize newSize = [_graphView bounds].size;
    
    // Command key -- resize whitespace instead of axis rect
    if ([[RSMode sharedModeController] commandKeyIsDown] /*&& ![graph autoMaintainsWhitespace]*/) {
        [graph setAutoMaintainsWhitespace:NO];
        
	//NSLog(@"old: %@, new: %@", NSStringFromSize(oldSize), NSStringFromSize(newSize));
	NSSize diffSize = NSMakeSize(newSize.width - oldSize.width, newSize.height - oldSize.height);
	
	// calculate new whitespace that maintains the graph size:
	RSBorder whitespace = [graph whitespace];
//	whitespace.right += diffSize.width;
//	whitespace.bottom += diffSize.height;
	whitespace.right += diffSize.width / 2;
	whitespace.left += diffSize.width / 2;
	whitespace.bottom += diffSize.height / 2;
	whitespace.top += diffSize.height / 2;
	[graph setWhitespace:whitespace];
    }
    
    // Snap to equalized tick spacing, i.e. to make the grid square (bug #50497)
    else if ([_graph displayBothGrids] && [_graph bothGridsAreEvenlySpaced]) {
        
        // This is the way to set the hypothetical bounds without sending KVO infinite loops screaming:
        NSRect newBounds = [_graphView bounds];
        newBounds.size = newSize;
        [_graphView.editor.mapper setBounds:newBounds];
        
        // This calculation depends on the hypothetical bounds
        CGPoint delta = [_graphView.editor.mapper deltaToSquareGrid];
        
        float hitOffset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
        
        if (fabs(delta.x) < hitOffset ) {
            // Calculate a new size that exactly offsets the delta
            newSize.width += delta.x;
            newSize.height += delta.y;
        }
    }
    
    
    // Set the size
    [graph setCanvasSize:newSize];
}

- (void)windowWillClose:(NSNotification *)note
// sent right before the window closes
{
    DEBUG_RS(@"windowWillClose");
    
    [self saveGraphFrame];
    
    [[self document] closeLinkBackConnection];
    
    // Unregister KVO, etc.
    [self documentGraphDidChange:nil];
    
    [[self document] removeObserver:self forKeyPath:@"graph"];
}


- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender;
{
    return [[self document] undoManager];
}


- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)anObject;
// Return a dependable field editor specifically for RSTextLabels.
{
    if (![anObject isKindOfClass:[RSTextLabel class]]) {
        return nil;  // use window's default field editor instead
    }
    
    if (!_textLabelFieldEditor) {
        NSTextView *fieldEditor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 10000, 10000)];
        [fieldEditor setRichText:YES];
        [fieldEditor setEditable:YES];
        [fieldEditor setFieldEditor:YES];  // controls behavior of return and tab keys
        [fieldEditor setAllowsUndo:YES];
        
        [fieldEditor setHorizontallyResizable:NO];  // this just didn't work
        [fieldEditor setVerticallyResizable:NO];
        [fieldEditor setMaxSize:NSMakeSize(10000, 10000)];
        
        // reflect user's continuous spell checking preference
        BOOL useSpell = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"UseContinuousSpellChecking"];
        [fieldEditor setContinuousSpellCheckingEnabled:useSpell];
        
        _textLabelFieldEditor = fieldEditor;
    }
    
    return _textLabelFieldEditor;
}


static BOOL inspectorsVisibleBeforeVersions = YES;
- (void)windowWillEnterVersionBrowser:(NSNotification *)notification;
{
    OIInspectorRegistry *inspectorRegistry = [[NSApp delegate] inspectorRegistryForWindow:self.window];
    inspectorsVisibleBeforeVersions = [inspectorRegistry hasVisibleInspector];
    if (inspectorsVisibleBeforeVersions)
        [inspectorRegistry tabShowHidePanels];
    
}

- (void)windowDidExitVersionBrowser:(NSNotification *)notification;
{
    OIInspectorRegistry *inspectorRegistry = [[NSApp delegate] inspectorRegistryForWindow:self.window];
    if (inspectorsVisibleBeforeVersions)
        [inspectorRegistry tabShowHidePanels];
}


//////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Notifications
//////////////////////////////////////////////////////////

- (void)changeToolbarMessageNotification:(NSNotification *)note;
{
    if (![[self window] isMainWindow])
	return;

    NSString *message = [note object];
    [self setStatusMessage:message];
}

- (void)modeWillChangeNotification:(NSNotification *)note;
{
    if (![[self window] isMainWindow])
	return;
    
    NSUInteger newMode = [[[note userInfo] objectForKey:@"mode"] unsignedIntegerValue];
    
    [self updateToolbarWithMode:newMode];
}


////////////////////////////////////////////////
#pragma mark -
#pragma mark KVO
////////////////////////////////////////////////

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
{
    if (object == [self document]) {
        if ( [keyPath isEqual:@"graph"] ) {
            [self documentGraphDidChange:[[self document] graph]];
        }
    }
    
    if (object == _graph) {
	if ( [keyPath isEqual:@"canvasSize"] ) {
	    [self updateWindowSize];
	}
	else if ( [keyPath isEqual:@"whitespace"] ) {
	    // Update the window's setting for its minimum size
	    NSSize windowContentMinSize = [_graph minCanvasSize];
	    windowContentMinSize.height += WINDOW_BOTTOM_BAR_HEIGHT;
	    [[self window] setContentMinSize:windowContentMinSize];
	}
    }
}



//////////////////////////////////////////////////////////
#pragma mark -
#pragma mark EXPERIMENTAL
//////////////////////////////////////////////////////////

//- (void)showModebar {
//    NSLog(@"showModeBar");
//    
//    float MODEBAR_HEIGHT = 26;
//    
//    // set the new frame and animate the change
//    NSRect windowFrame = [[self window] frame];
//    windowFrame.size.height = [_graphView frame].size.height + [_statusText frame].size.height 
//    + MODEBAR_HEIGHT + WINDOW_TITLE_HEIGHT;
//    windowFrame.size.width = [_graphView frame].size.width;
//    windowFrame.origin.y = NSMaxY([_theWindow frame]) - windowFrame.size.height;
//    
//    NSRect graphViewFrame = [_graphView frame];
//    //graphViewFrame.origin.y += MODEBAR_HEIGHT;
//    
//    //if ([[activeContentView subviews] count] != 0)
//    //	[[[activeContentView subviews] objectAtIndex:0] removeFromSuperview];
//    [_theWindow setFrame:windowFrame display:YES animate:YES];
//    
//    [_graphView setFrame:graphViewFrame];
//    
//    [[_theWindow contentView] addSubview:_modebar];
//    NSRect modebarFrame = [_graphView frame];
//    modebarFrame.origin.y = windowFrame.size.height - MODEBAR_HEIGHT - WINDOW_TITLE_HEIGHT;
//    //modebarFrame.size.height = 
//    [_modebar setFrame:modebarFrame];
//    
//    
//    // this seems to fix an IB problem with resizing during the animation...
//    //[activeContentView setFrame:NSMakeRect(0, 0, NSWidth([self frame]), NSMinY([self frame]))];
//    //[activeContentView addSubview:view];
//}

@end
