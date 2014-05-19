// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "AxisInspector.h"

#import <GraphSketcherModel/RSAxis.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSGraphEditor.h>

#import <OmniQuartz/OQColor.h>

#import "GraphDocument.h"
#import "RSSelector.h"
#import "RSGraphView.h"
#import "OIInspector-RSExtensions.h"

#import <OmniAppKit/OATinyPopUpButton.h>

static NSInteger tagFromPlacement(RSAxisPlacement placement)
{
    switch (placement) {
	case RSEdgePlacement:
	    return 0;
	case RSOriginPlacement:
	    return 1;
	case RSBothEdgesPlacement:
	    return 2;
	default:
	    return 0;
    }
}
static NSInteger tagFromPlacementOfAxis(RSAxis *axis)
{
    if (![axis displayAxis])
	return 3;
    
    else return tagFromPlacement([axis placement]);
}

static RSAxisPlacement placementFromTag(NSInteger tag)
{
    switch (tag) {
	case 0:
	    return RSEdgePlacement;
	case 1:
	    return RSOriginPlacement;
	case 2:
	    return RSBothEdgesPlacement;
	case 3:
	    return RSHiddenPlacement;
	default:
	    return RSOriginPlacement;
    }
}


static NSInteger stateFromBool(BOOL flag)
{
    if (flag)  return NSOnState;
    else  return NSOffState;
}
static BOOL boolFromState(NSInteger state)
{
    if (state == NSOffState)
	return NO;
    else
	return YES;
}



@implementation AxisInspector

#pragma mark -
#pragma mark Class methods

- (NSArray *)convertToArrayOfAxes:(NSArray *)objects;
{
    NSMutableArray *axes = [NSMutableArray arrayWithCapacity:2];
    GraphDocument *document = nil;
    
    for (id object in objects) {
	if ([object isKindOfClass:[RSAxis class]])
	    [axes addObject:object];
	if ([object isKindOfClass:[GraphDocument class]])
	    document = object;
    }
    
    if ([axes count] == 0 && document) {
	[axes addObject:[[document graph] xAxis]];
	[axes addObject:[[document graph] yAxis]];
    }
    
    return axes;
}

- (void)setUpTickLabelPopUpMenu:(NSMenu *)menu action:(SEL)selector;
{
    [menu removeAllItems];  // Get rid of any leftovers from the nib
    
    NSMenuItem *menuItem = nil;
    
    menuItem = [menu addItemWithTitle:NSLocalizedString(@"Scientific Notation", @"Axis inspector scientific notation pop-up menu item") action:NULL keyEquivalent:@""];
    [menuItem setEnabled:NO];
    [menuItem setState:NSOffState];
    [menuItem setTarget:self];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // These actions currently get validated and performed by the RSGraphView:
    
    menuItem = [menu addItemWithTitle:NSLocalizedString(@"Auto", @"Axis inspector scientific notation pop-up menu item") action:selector keyEquivalent:@""];
    [menuItem setTag:RSScientificNotationSettingAuto];
    
    menuItem = [menu addItemWithTitle:NSLocalizedString(@"Off", @"Axis inspector scientific notation pop-up menu item") action:selector keyEquivalent:@""];
    [menuItem setTag:RSScientificNotationSettingOff];
    
    menuItem = [menu addItemWithTitle:NSLocalizedString(@"On", @"Axis inspector scientific notation pop-up menu item") action:selector keyEquivalent:@""];
    [menuItem setTag:RSScientificNotationSettingOn];
}

- (void)updateDisplay;
{
    // -setEnabled: is now handled using bindings in the xib file.
    
    if (!_s || ![_s document]) {
	
	[_axisPlacementXMatrix selectCellAtRow:-1 column:-1]; // clears the selection
	[_axisPlacementYMatrix selectCellAtRow:-1 column:-1];
	
	[_displayAxisTitleX setState:NSOffState];
	[_displayAxisTitleY setState:NSOffState];
	[_displayAxisTickMarksX setState:NSOffState];
	[_displayAxisTickMarksY setState:NSOffState];
	[_displayAxisTickLabelsX setState:NSOffState];
	[_displayAxisTickLabelsY setState:NSOffState];
	
	[_displayGridX setState:NSOffState];
	[_displayGridY setState:NSOffState];
	
	[_gridColorWell setColor:[NSColor whiteColor]];
	
	return;
    }
    
    // Otherwise, we have something to inspect
    RSGraph *graph = [_document graph];
    RSAxis *xAxis = [graph xAxis];
    RSAxis *yAxis = [graph yAxis];
    
    [_axisTypePopUpX selectItemWithTag:(NSInteger)[xAxis axisType]];
    [_axisTypePopUpY selectItemWithTag:(NSInteger)[yAxis axisType]];
    
//    [_rangeXMinField setFloatValue:[xAxis min]];
//    [_rangeXMaxField setFloatValue:[xAxis max]];
//    [_rangeYMinField setFloatValue:[yAxis min]];
//    [_rangeYMaxField setFloatValue:[yAxis max]];
//    
//    [[_graph xAxis] configureInspectorNumberFormatter:[_rangeXMinField formatter]];
//    [[_graph xAxis] configureInspectorNumberFormatter:[_rangeXMaxField formatter]];
//    [[_graph yAxis] configureInspectorNumberFormatter:[_rangeYMinField formatter]];
//    [[_graph yAxis] configureInspectorNumberFormatter:[_rangeYMaxField formatter]];
    
    [_rangeXMinField setStringValue:[xAxis formattedDataValue:[xAxis min]]];
    [_rangeXMaxField setStringValue:[xAxis formattedDataValue:[xAxis max]]];
    [_rangeYMinField setStringValue:[yAxis formattedDataValue:[yAxis min]]];
    [_rangeYMaxField setStringValue:[yAxis formattedDataValue:[yAxis max]]];
    
    [_axisPlacementXMatrix selectCellWithTag:tagFromPlacementOfAxis(xAxis)];
    [_axisPlacementYMatrix selectCellWithTag:tagFromPlacementOfAxis(yAxis)];
    
    [_displayAxisTitleX setState:stateFromBool([xAxis displayTitle])];
    [_displayAxisTitleY setState:stateFromBool([yAxis displayTitle])];
    [_displayAxisTickMarksX setState:stateFromBool([xAxis displayTicks])];
    [_displayAxisTickMarksY setState:stateFromBool([yAxis displayTicks])];
    [_displayAxisTickLabelsX setState:stateFromBool([xAxis displayTickLabels])];
    [_displayAxisTickLabelsY setState:stateFromBool([yAxis displayTickLabels])];
    
//    [_axisTickSpacingX setFloatValue:[xAxis spacing]];
//    [_axisTickSpacingY setFloatValue:[yAxis spacing]];
//    
//    [[_graph xAxis] configureInspectorNumberFormatter:[axisTickSpacingX formatter]];
//    [[_graph yAxis] configureInspectorNumberFormatter:[axisTickSpacingY formatter]];
    
    if ([xAxis axisType] == RSAxisTypeLogarithmic) {
        [_axisTickSpacingX setStringValue:NSLocalizedString(@"Auto", @"Axis inspector automatic tick spacing indication")];
        [_axisTickSpacingX setEnabled:NO];
        [_axisTickSpacingXLabel setTextColor:[NSColor disabledControlTextColor]];
    } else {
        [_axisTickSpacingX setStringValue:[xAxis formattedDataValue:[xAxis spacing]]];
        [_axisTickSpacingX setEnabled:YES];
        [_axisTickSpacingXLabel setTextColor:[NSColor controlTextColor]];
    }
    
    if ([yAxis axisType] == RSAxisTypeLogarithmic) {
        [_axisTickSpacingY setStringValue:NSLocalizedString(@"Auto", @"Axis inspector automatic tick spacing indication")];
        [_axisTickSpacingY setEnabled:NO];
        [_axisTickSpacingYLabel setTextColor:[NSColor disabledControlTextColor]];
    } else {
        [_axisTickSpacingY setStringValue:[yAxis formattedDataValue:[yAxis spacing]]];
        [_axisTickSpacingY setEnabled:YES];
        [_axisTickSpacingYLabel setTextColor:[NSColor controlTextColor]];
    }
    
    [_displayGridX setState:stateFromBool([[_graph xGrid] displayGrid])];
    [_displayGridY setState:stateFromBool([[_graph yGrid] displayGrid])];
    
    [_gridWidthSlider setDoubleValue:[_graph gridWidth]];
    [_gridWidthField setDoubleValue:[_graph gridWidth]];
    [_gridWidthStepper setDoubleValue:[_graph gridWidth]];
    
    [_gridColorWell setColor:[_graph gridColor].toColor];
    
    
// For future reference if we decide to go back to this type of behavior
//    // individual axis settings if an axis or axis element is selected
//    if (axis) {
//	// set axis display checkboxes:
//	if ( [axis displayAxis] )  [displayAxis setState:NSOnState];
//	else  [displayAxis setState:NSOffState];
//    }
//    // if no axis is selected, apply to both axes
//    else {
//	if ( [_graph displayAxes] )  [displayAxis setState:NSOnState];
//	else  [displayAxis setState:NSOffState];
//	[displayAxis setTitle:@"Axes"];
//    }
    
}


#pragma mark -
#pragma mark init/dealloc

- (id)initWithDictionary:(NSDictionary *)dict inspectorRegistry:(OIInspectorRegistry *)inspectorRegistry bundle:(NSBundle *)sourceBundle;
{
    self = [super initWithDictionary:dict inspectorRegistry:inspectorRegistry bundle:sourceBundle];
    if (!self)
        return nil;
    
    _s = nil;
    _graph = nil;
    
    return self;
}

- (void)dealloc;
{
    // unregister observer from notification center
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];

    [super dealloc];
}

- (NSString *)nibName;
{
    return NSStringFromClass([self class]);
}

- (NSBundle *)nibBundle;
{
    return OMNI_BUNDLE;
}

- (void)awakeFromNib;
{
    // add default number formatters
//    [_rangeXMinField setFormatter:[RSAxis inspectorNumberFormatter]];
//    [_rangeXMaxField setFormatter:[RSAxis inspectorNumberFormatter]];
//    [_rangeYMinField setFormatter:[RSAxis inspectorNumberFormatter]];
//    [_rangeYMaxField setFormatter:[RSAxis inspectorNumberFormatter]];
//    
//    [_axisTickSpacingX setFormatter:[RSAxis inspectorNumberFormatter]];
//    [_axisTickSpacingY setFormatter:[RSAxis inspectorNumberFormatter]];
    
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    // Register to receive notifications about selection changes
    [nc addObserver:self 
           selector:@selector(selectionChangedNotification:)
               name:@"RSSelectionChanged"
             object:nil]; // don't care who sent it
    
    // Register to receive notifications about context changes
    [nc addObserver:self 
           selector:@selector(contextChangedNotification:)
               name:@"RSContextChanged"
             object:nil]; // don't care who sent it
    
    // Register to receive notifications when the toolbar is clicked
    [nc addObserver:self 
           selector:@selector(toolbarClickedNotification:)
               name:@"RSToolbarClicked"
             object:nil]; // don't care who sent it
    
    
    [self setUpTickLabelPopUpMenu:[_tickLabelPopUpX menu] action:@selector(changeScientificNotationX:)];
    [self setUpTickLabelPopUpMenu:[_tickLabelPopUpY menu] action:@selector(changeScientificNotationY:)];
    
    [self updateDisplay];
}


#pragma mark -
#pragma mark Notifications

- (void)selectionChangedNotification:(NSNotification *)note
// sent by selection object when any object modifies the selection in any way
{
    // if the inspector sent the change notification, ignore it
    if ([note object] == self)  return;
    
    // otherwise, take heed:
    else {
	// remove keyboard focus from any fields
	//[panel makeFirstResponder:nil];
	
        // this will display the new values directly from the selection:
        [self updateDisplay];
    }
}
- (void)contextChangedNotification:(NSNotification *)note
{
    [self updateDisplay];
}
- (void)toolbarClickedNotification:(NSNotification *)note
{
    // deselect any selected fields (otherwise, a new unwanted (0,0) point could get created)
    [self.view.window makeFirstResponder:nil];
}



#pragma mark -
#pragma mark OIConcreteInspector protocol

- (NSPredicate *)inspectedObjectsPredicate;
// Return a predicate to filter the inspected objects down to what this inspector wants sent to its -inspectObjects: method
{
    static NSPredicate *predicate = nil;
    if (!predicate)
	predicate = [[NSComparisonPredicate isKindOfClassPredicate:[GraphDocument class]] retain];
    return predicate;
}

- (void)inspectObjects:(NSArray *)objects;
// This method is called whenever the selection changes
{
    GraphDocument *newDocument = nil;
    
    for (id obj in objects) {
	if ([obj isKindOfClass:[GraphDocument class]]) {
	    newDocument = obj;
	    break;
	}
    }
    
    // The graph can change on "revert to saved", even if the document is the same.
    RSGraph *newGraph = [newDocument graph];
    if (newGraph == _graph)
        return;
    
    if (_graph) {
	// stop observing changes to the old graph
	[_graph removeObserver:self forKeyPath:@"displayGrid"];
    }
    
    [self setDocument:newDocument];
    _s = [[self document] selectorObject];
    _graph = newGraph;
    
    if (newGraph) {
	// start observing changes to the new graph
	[_graph addObserver:self forKeyPath:@"displayGrid" options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    [self updateDisplay];
}



#pragma mark -
#pragma mark KVO (instead of cocoa bindings)

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
{
    // for now we'll take the brute-force approach of just updating the entire display
    [self updateDisplay];
}



#pragma mark -
#pragma mark Accessors

@synthesize document = _document;

- (BOOL)documentExists;
{
    return [self document] != nil;
}



#pragma mark -
#pragma mark IBActions

- (IBAction)changeAxisType:(id)sender;
{
    RSGraph *graph = [_document graph];
    RSAxis *axis = nil;
    if (sender == _axisTypePopUpX)
        axis = [graph xAxis];
    else
        axis = [graph yAxis];

    NSInteger tag = [[sender selectedItem] tag];
    [axis setAxisType:(RSAxisType)tag];
}


- (IBAction)changeXMin:(id)sender;
{
    RSGraph *graph = [_document graph];
    RSAxis *axis = [graph xAxis];
    data_p value = [axis dataValueFromFormat:[sender stringValue]];
    
    [graph setMin:value forAxis:axis];
    
    [[_graph undoer] endRepetitiveUndo];
    [self updateDisplay];
}
- (IBAction)changeXMax:(id)sender;
{
    RSGraph *graph = [_document graph];
    RSAxis *axis = [graph xAxis];
    data_p value = [axis dataValueFromFormat:[sender stringValue]];
    
    [graph setMax:value forAxis:axis];
    
    [[_graph undoer] endRepetitiveUndo];
    [self updateDisplay];
}
- (IBAction)changeYMin:(id)sender;
{
    RSGraph *graph = [_document graph];
    RSAxis *axis = [graph yAxis];
    data_p value = [axis dataValueFromFormat:[sender stringValue]];
    
    [graph setMin:value forAxis:axis];
    
    [[_graph undoer] endRepetitiveUndo];
    [self updateDisplay];
}
- (IBAction)changeYMax:(id)sender;
{
    RSGraph *graph = [_document graph];
    RSAxis *axis = [graph yAxis];
    data_p value = [axis dataValueFromFormat:[sender stringValue]];
    
    [graph setMax:value forAxis:axis];
    
    [[_graph undoer] endRepetitiveUndo];
    [self updateDisplay];
}



- (IBAction)changeAxisPlacement:(id)sender;
// "sender" is the matrix
{
    RSGraph *graph = [_document graph];
    RSAxis *axis = nil;
    if (sender == _axisPlacementXMatrix)
	axis = [graph xAxis];
    else
	axis = [graph yAxis];
    
    
    NSInteger tag = [[sender selectedCell] tag];
    RSAxisPlacement placement = placementFromTag(tag);
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    [_document.editor setPlacement:placement forAxis:axis];
    [_s sendChange:nil];
}


- (IBAction)changeDisplayAxisTitle:(id)sender;
{
    BOOL boolState = boolFromState([sender state]);
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    RSGraph *graph = [_document graph];
    RSAxis *axis = nil;
    if (sender == _displayAxisTitleX)
	axis = [graph xAxis];
    else
	axis = [graph yAxis];
        
    [_document.editor setDisplayTitle:boolState forAxis:axis];
    [_s sendChange:nil];
}

- (IBAction)changeDisplayAxisTickMarks:(id)sender;
{
    BOOL boolState = boolFromState([sender state]);
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    RSGraph *graph = [_document graph];
    RSAxis *axis = nil;
    if (sender == _displayAxisTickMarksX)
	axis = [graph xAxis];
    else
	axis = [graph yAxis];
    
    [_document.editor setDisplayTickMarks:boolState forAxis:axis];
    [_s sendChange:nil];
}

- (IBAction)changeDisplayAxisTickLabels:(id)sender;
{
    BOOL boolState = boolFromState([sender state]);
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    RSGraph *graph = [_document graph];
    RSAxis *axis = nil;
    if (sender == _displayAxisTickLabelsX)
	axis = [graph xAxis];
    else
	axis = [graph yAxis];
    
    [_document.editor setDisplayTickLabels:boolState forAxis:axis];
    
    // get rid of possible hidden selection
    if (![_graph shouldDisplayLabel:[_s selection]])
	[_s deselect];
    
    [_s sendChange:nil];
}

- (IBAction)changeTickSpacing:(id)sender;
{
    RSGraph *graph = [_document graph];
    RSAxis *axis = nil;
    if (sender == _axisTickSpacingX)
	axis = [graph xAxis];
    else
	axis = [graph yAxis];
    
    data_p value = [axis dataValueFromFormat:[sender stringValue]];
    
    // Don't set the user spacing if the entered value is the same as the default and no user spacing has been set previously.  <bug:///71064>
    if (![axis userSpacing] && value == [axis spacing])
        return;
    
    [_document.editor setTickSpacing:value forAxis:axis];
    [[_graph undoer] endRepetitiveUndo];
    [self updateDisplay];
}


- (IBAction)changeDisplayGrid:(id)sender;
{
    BOOL boolState = boolFromState([sender state]);
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    RSGraph *graph = [_document graph];
    RSAxis *axis = nil;
    if (sender == _displayGridX)
	axis = [graph xAxis];
    else
	axis = [graph yAxis];
    
    // set user preference:
    //[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:boolState forKey:@"DisplayVerticalGrid"];
    
    [axis setDisplayGrid:boolState];
    [_s sendChange:nil];
}


- (IBAction)changeGridWidth:(id)sender;
{
    float width = [sender floatValue];
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    // Input validation
    if (width < 0 || width > 10) {
	[self updateDisplay];
	return;
    }
    
    [_gridWidthStepper setDoubleValue:width];
    
    // This sets the grid width and sets up undo:
    [_graph setGridWidth:width];
    
    // set user preference:
    //[[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:[sender floatValue] forKey: @"DefaultGridWidth"];
    
    [_s sendChange:nil];
}

- (IBAction)changeGridColor:(id)sender;
{
    if (![[[NSApp mainWindow] firstResponder] isKindOfClass:[RSGraphView class]]) {
        [_gridColorWell deactivate];
        return;
    }
    
    NSColor *newColor = [sender color];
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    // Set up Undo:
    [[_s undoer] registerRepetitiveUndoWithObject:_graph
					   action:@"setGridColor" 
					    state:[_graph gridColor]
					     name:NSLocalizedStringFromTable(@"Change Grid Color", @"UndoActions", @"Undo action name")];
    // set user preference:
    //[[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newColor forKey: @"DefaultGridColor"];
    
    [_graph setGridColor:[OQColor colorWithPlatformColor:newColor]];
    
    // also, turn on the grid if it's currently off!
    [_graph displayGridIfNotAlready];
    
    [_s sendChange:nil];
}



///////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark old
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

// (For reference if we decide to switch back to behavior more like this for parts of the axis inspector.)
//
//- (IBAction)changeDisplayAxes:(id)sender;
//{
//    RSAxis *axis;
//    
//    BOOL boolState = boolFromState([sender state]);
//    
//    // If a specific axis is selected, only change its display settings
//    if ( [_graph axisOfElement:[_s selection]] ) {
//	axis = [_graph axisOfElement:[_s selection]];
//	// Set up Undo:
//	if ( boolState == NO ) {
//	    [[_s undoer] registerUndoWithObject:axis 
//					 action:@"setDisplayAxis" 
//					  state:[NSNumber numberWithBool:[axis displayAxis]]
//					   name:@"Hide Axis"];
//	    // can't show tick marks if axis is hidden
//	    //[[_s undoer] registerRepetitiveUndoWithObject:axis 
//	    //					   action:@"setDisplayTicks" 
//	    //					state:[NSNumber numberWithBool:[axis displayTicks]]];
//	    //[axis setDisplayTicks:boolState];
//	}
//	else  [[_s undoer] registerUndoWithObject:axis
//					   action:@"setDisplayAxis" 
//					    state:[NSNumber numberWithBool:[axis displayAxis]]
//					     name:@"Show Axis"];
//	
//	[axis setDisplayAxis:boolState];
//	[_s deselect];
//    }
//    // otherwise, turn on or off both axes together
//    else {
//	// Set up Undo:
//	if ( boolState == NO ) {
//	    [[_s undoer] registerUndoWithObject:_graph 
//					 action:@"setDisplayAxes" 
//					  state:[NSNumber numberWithBool:[_graph displayAxes]]
//					   name:@"Hide Axes"];
//	    // can't show tick marks if axis is hidden
//	    //[[_s undoer] registerRepetitiveUndoWithObject:_graph 
//	    //				   action:@"setDisplayAxisTicks" 
//	    //					state:[NSNumber numberWithBool:[_graph displayAxisTicks]]];
//	    //[_graph setDisplayAxisTicks:boolState];
//	}
//	else  [[_s undoer] registerUndoWithObject:_graph 
//					   action:@"setDisplayAxes" 
//					    state:[NSNumber numberWithBool:[_graph displayAxes]]
//					     name:@"Show Axes"];
//	// set user preference:
//	[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:boolState forKey:@"DisplayAxis"];
//	
//	[_graph setDisplayAxes:boolState];
//    }
//    
//    [_document.editor setNeedsUpdateWhitespace];
//    [_s sendChange:nil];
//}



@end
