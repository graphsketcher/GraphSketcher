// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "DataInspector.h"

#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSLine.h>

#import "GraphDocument.h"
#import "RSSelector.h"
#import "RSGraphView.h"

#define VALUE_NOT_DEFINED_YET DBL_MIN


@implementation DataInspector

#pragma mark -
#pragma mark Class methods

- (id)_unfinishedPointValueForColumn:(id)columnKey;
{
    if (_unfinishedPoint.x != VALUE_NOT_DEFINED_YET && [columnKey isEqualToString:@"positionx"]) {
	return [NSNumber numberWithDouble:_unfinishedPoint.x];
    }
    if (_unfinishedPoint.y != VALUE_NOT_DEFINED_YET && [columnKey isEqualToString:@"positiony"]) {
	return [NSNumber numberWithDouble:_unfinishedPoint.y];
    }
    
    return nil;
}

- (void)_setUnfinishedPointValue:(id)value forColumn:(id)columnKey;
{
    if ([columnKey isEqualToString:@"positionx"]) {
	_unfinishedPoint.x = [[_graph xAxis] dataValueFromFormat:value];
    }
    else if ([columnKey isEqualToString:@"positiony"]) {
	_unfinishedPoint.y = [[_graph yAxis] dataValueFromFormat:value];
    }
}

- (void)_clearUnfinishedPoint;
{
    _unfinishedPoint = RSDataPointMake(VALUE_NOT_DEFINED_YET, VALUE_NOT_DEFINED_YET);
}

- (RSVertex *)_vertexFromUnfinishedPoint;
// Returns a new vertex at _unfinishedPoint, or nil if the point is still in fact unfinished.
{
    if (_unfinishedPoint.x == VALUE_NOT_DEFINED_YET || _unfinishedPoint.y == VALUE_NOT_DEFINED_YET)
	return nil;
    
    RSVertex *V = [[[RSVertex alloc] initWithGraph:_graph] autorelease];
    [V setShape:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultVertexShape"]];
    [V setPosition:_unfinishedPoint];
    
    return V;
}


- (void)updateDisplay;
{
    _selfChanged = YES;
    
    [_tableView reloadData];
    
    if( _s == nil ) {
	// No document windows are open.  Disable everything!
	[_tableView setEnabled:NO];
	[_connectPointsButton setEnabled:NO];
    }
    else {
	[_tableView setEnabled:YES];
        
//        NSTableColumn *xColumn = [_tableView tableColumnWithIdentifier:@"positionx"];
//        [[_graph xAxis] configureInspectorNumberFormatter:[[xColumn dataCell] formatter]];
//        
//        NSTableColumn *yColumn = [_tableView tableColumnWithIdentifier:@"positiony"];
//        [[_graph yAxis] configureInspectorNumberFormatter:[[yColumn dataCell] formatter]];
	
	
	//
	// show the selection
	//
	
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	RSVertex *V;
	NSInteger index;
	NSInteger count = 0;
	if( [[_s selection] isKindOfClass:[RSVertex class]] ) {
	    index = [[_graph Vertices] indexOfObjectIdenticalTo:[_s selection]];
	    if ( index != NSNotFound ) {
		[indexSet addIndex:index];
		count++;
	    }
	}
	else if ( [[_s selection] isKindOfClass:[RSGroup class]] ) {
	    for (V in [(RSGroup *)[_s selection] elementsWithClass:[RSVertex class]])
	    {
		index = [[_graph Vertices] indexOfObjectIdenticalTo:V];
		if ( index != NSNotFound ) {
		    [indexSet addIndex:index];
		    count++;
		}
	    }
	}
	else if ( [[_s selection] isKindOfClass:[RSUnknown class]] ) {
	    index = [[_graph Vertices] count];
	    [indexSet addIndex:index];
	}
	[_tableView selectRowIndexes:indexSet byExtendingSelection:NO];
	
	
	// "Connect" button
        BOOL acceptableSingleVertex = YES;
        if ([_s selected] && count <= 1) {
            acceptableSingleVertex = NO;
//            V = (RSVertex *)[_s selection];
//            if ([V isKindOfClass:[RSVertex class]]) {
//                acceptableSingleVertex = [V parentCount] == 0;
//            }
        }
	if ( !acceptableSingleVertex || [[_graph Vertices] count] <= 1 )
	    [_connectPointsButton setEnabled:NO];
	else
	    [_connectPointsButton setEnabled:YES];
	
    }
    
    _selfChanged = NO;
}


#pragma mark -
#pragma mark init/dealloc

- initWithDictionary:(NSDictionary *)dict bundle:(NSBundle *)sourceBundle;
{
    self = [super initWithDictionary:dict bundle:sourceBundle];
    if (!self)
        return nil;
    
    _s = nil;
    _graph = nil;
    
    _selfChanged = NO;
    
    [self _clearUnfinishedPoint];
    
    return self;
}

- (void)dealloc;
{
    // unregister observer from notification center
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
    
    [_view release];
    
    [super dealloc];
}

- (void)awakeFromNib;
{
    // add default number formatters
//    NSTableColumn *xColumn = [_tableView tableColumnWithIdentifier:@"positionx"];
//    [[xColumn dataCell] setFormatter:[RSAxis tickLabelNumberFormatter]];
//    NSTableColumn *yColumn = [_tableView tableColumnWithIdentifier:@"positiony"];
//    [[yColumn dataCell] setFormatter:[RSAxis tickLabelNumberFormatter]];
    
    
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
    
    
    [self updateDisplay];
}



#pragma mark -
#pragma mark NSResponder subclass

- (BOOL)acceptsFirstResponder;
{
    return YES;
}


#pragma mark -
#pragma mark Notifications

- (void)selectionChangedNotification:(NSNotification *)note
// sent by selection object when any object modifies the selection in any way
{
    // when the inspector is updating itself, ignore this notification
    if( _selfChanged )  return;
    
    // if the inspector sent the change notification, ignore it
    if ([note object] == self)  return;
    
    // otherwise, update the display to reflect the change:
    //[panel makeFirstResponder:nil];  // remove keyboard focus from any fields
    [self updateDisplay];
}
- (void)contextChangedNotification:(NSNotification *)note
{
    [self updateDisplay];
}
- (void)toolbarClickedNotification:(NSNotification *)note
{
    // deselect any selected fields (otherwise, a new unwanted (0,0) point could get created)
    [[_view window] makeFirstResponder:nil];
}



#pragma mark -
#pragma mark OIConcreteInspector protocol

- (NSView *)inspectorView;
// Returns the view which will be placed into a grouped Info window
{
    if (!_view) {
	if (![[self bundle] loadNibNamed:NSStringFromClass(self.class) owner:self topLevelObjects:NULL]) {
	    OBASSERT_NOT_REACHED("Error loading nib");
	}
    }
    return _view;
}

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
	//[_graph removeObserver:self forKeyPath:@"canvasSize"];
    }
    
    _s = [newDocument selectorObject];
    _graph = newGraph;
    
    if (newGraph) {
	// start observing changes to the new graph
	//[_graph addObserver:self forKeyPath:@"canvasSize" options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    [self updateDisplay];
}




#pragma mark -
#pragma mark NSTableDataSource protocol methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
// Returns the number of records managed for aTableView by the data source object.
{
    return [[_graph Vertices] count] + 1;
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
	    row:(NSInteger)rowIndex;
// "Invoked by the table view to return the data object associated with the specified row and column.  Called very frequently, so must be efficient."
{
    if ( rowIndex < (NSInteger)[[_graph Vertices] count] ) {
	RSVertex *V = [[_graph Vertices] objectAtIndex:rowIndex];
        NSString *key = [aTableColumn identifier];
	// get value of attribute named identifier:
        id objectValue = [V valueForKey:key];
        
        if ([key isEqualToString:@"positionx"]) {
            objectValue = [[_graph xAxis] inspectorFormattedDataValue:[objectValue doubleValue]];
        }
        else if ([key isEqualToString:@"positiony"]) {
            objectValue = [[_graph yAxis] inspectorFormattedDataValue:[objectValue doubleValue]];
        }
        return objectValue;
    }
    else  // a blank row ready to create new vertex
    {
	return [self _unfinishedPointValueForColumn:[aTableColumn identifier]];
    }
}

- (void)_startEditingRow:(NSInteger)rowIndex;
{
    [_tableView reloadData];
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
    [_tableView editColumn:0 row:rowIndex withEvent:nil select:YES];
    //[_tableView reloadData];
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
	      row:(NSInteger)rowIndex;
// Set the data object for an item in a given row in a given column.
{
    if (rowIndex < 0)  // This has happened; I don't know why.
	return;
    
    NSString *identifier = [aTableColumn identifier];
    RSVertex *V;
    BOOL aNewOne = NO;
    BOOL goToNextRow = NO;
    
    BOOL isBlank = (anObject == nil || [anObject isEqual:@""]);

    // Potentially add a new vertex
    if ( rowIndex >= (NSInteger)[[_graph Vertices] count] ) {
	if (!isBlank) {
	    [self _setUnfinishedPointValue:anObject forColumn:identifier];
	}
	
	V = [self _vertexFromUnfinishedPoint];
	if (V) {
	    [[_graph undoer] endRepetitiveUndo];
	    [_graph addVertex:V];
	    [self _clearUnfinishedPoint];
	    aNewOne = YES;
	}
	else {
	    // just return (don't create a new vertex if they didn't enter any text; and don't move on to the next row because there's no vertex in this row).
	    return;
	}
    }
    // Editing an existing vertex
    else {
	V = [[_graph Vertices] objectAtIndex:rowIndex];
    }
    
    // If got this far, we are successfully editing a vertex that's in the graph.
    _selfChanged = YES;
    
    // Set the value for the attribute named identifier:
    if ( [identifier isEqual:@"text"] ) {
	if (!isBlank) {
	    [_graph makeLabelForOwner:V];  // if the vertex doesn't already have a label, create one.
	}
	[V setText:anObject];
	
	goToNextRow = YES;
    }
    else {
	// we're setting "positionx" or "positiony"
	if (!isBlank) {
	    // Set up Undo:
	    NSString *newUndoName = nil;
	    if ( !aNewOne )  newUndoName = @"Move Point";
	    else  newUndoName = @"Add Point";
	    [[_graph undoer] registerRepetitiveUndoWithObject:V 
							      action:@"setPosition" 
							       state:NSValueFromDataPoint([V position])
								name:newUndoName];
            if ([identifier isEqualToString:@"positionx"]) {
                data_p value = [[_graph xAxis] dataValueFromFormat:anObject];
                [V setPositionx:value];
            }
            else if ([identifier isEqualToString:@"positiony"]) {
                data_p value = [[_graph yAxis] dataValueFromFormat:anObject];
                [V setPositiony:value];
            }
	    //NSLog(@"vertex has value: (%f,%f); object is: %@", [V positionx], [V positiony], anObject);
	    [_s autoScaleIfWanted];
	}
    }
    
    [_s setSelection:V];
    
    RSGraphEditor *editor = [[[_s document] graphView] editor];
    [editor modelChangeRequires:RSUpdateConstraints];
    [editor updateDisplayNow];  // necessary to do it "now" because of _selfChanged
//    if ( aNewOne ) {
//	[_tableView reloadData];
//    }
    
    if (goToNextRow) {
	[self _startEditingRow:rowIndex + 1];
    }
    
    _selfChanged = NO;
}


#pragma mark -
#pragma mark NSTableView delegate

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
    // when the inspector is updating itself, ignore this notification
    if( _selfChanged )  return;
    else  _selfChanged = YES;  // and ignore notifications sent during this method
    
    [self _clearUnfinishedPoint];
    
    NSUInteger lastRow = [[_graph Vertices] count];
    
    if (lastRow == 0) {
	[_s deselect];
	_selfChanged = NO;
	return;
    }
    
    NSMutableIndexSet *selectedRowIndexes = [[[_tableView selectedRowIndexes] mutableCopy] autorelease];
    [selectedRowIndexes removeIndex:lastRow];
    NSArray *selectedVertices = [[_graph Vertices] objectsAtIndexes:selectedRowIndexes];
    
    RSGroup *G = [[[RSGroup alloc] initWithGraph:_graph byCopyingArray:selectedVertices] autorelease];
    [_s setSelection:[G shake]];
    
    //[[[_s document] graphView] setSelection:GE];   // deselects if GE is nil
    [_s sendChange:self];
    
    _selfChanged = NO;
}


- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
    NSString *identifier = [tableColumn identifier];
    
    if ( [identifier isEqual:@"positionx"] ) {
	// Sort vertices by x-coordinate
	[[_graph Vertices] sortUsingSelector:@selector(xSort:)];
    }
    else if ( [identifier isEqual:@"positiony"] ) {
	// Sort vertices by y-coordinate
	[[_graph Vertices] sortUsingSelector:@selector(ySort:)];
    }
    else if ( [identifier isEqual:@"text"] ) {
	// Sort vertices alphabetically by label
	[[_graph Vertices] sortUsingSelector:@selector(labelSort:)];
    }
    
    [_tableView reloadData];
}





#pragma mark -
#pragma mark IBActions

- (IBAction)connectPoints:(id)sender;
{
    RSGraphElement *newSelection = nil;
    
    // Nothing selected
    if (![_s selected]) {
	// Create a line from everything on the graph
        RSGraphElement *obj = [_graph userElements];  //used to be//[_graph userVertexElements];
	if (obj)
            newSelection = obj;
	else
	    return;
    }
    
    // One vertex selected
    // This code is currently inactive since the Connect Points button is disabled when only one vertex is selected.
    else if ([[_s selection] isKindOfClass:[RSVertex class]]) {
        RSGraphElement *lineOrLines = [_graph graphElementFromArray:[_graph userLineElements]];
        if (!lineOrLines) {
            OBASSERT([[_graph userVertexElements] count] > 1);
            newSelection = [_graph userElements];
        }
        else {
            RSLine *winner = nil;
            
            // If the graph contains exactly one line
            if ([lineOrLines isKindOfClass:[RSLine class]]) {
                winner = (RSLine *)lineOrLines;
            }
            else {
                // If the graph contains more than one line, find the line with the most vertices and add on to that one.
                NSUInteger max = 0;
                for (RSLine *line in [[(RSGroup *)lineOrLines elements] reverseObjectEnumerator]) {
                    NSUInteger count = [line vertexCount];
                    if (count > max) {
                        max = count;
                        winner = line;
                    }
                }
            }
            OBASSERT(winner);
            if (winner) {
                RSGroup *vertexAndLine = [RSGroup groupWithGraph:_graph];
                [vertexAndLine addElement:[_s selection]];
                [vertexAndLine addElement:winner];
                newSelection = vertexAndLine;
            }
        }
    }
    
    // All other cases (the norm)
    else {
        newSelection = [_s selection];
        
        // If there is just one parent line, add it to the selection so that the connect code will add the additional vertices (if any) to it.
        RSLine *singleLine = [RSGraph singleParentLine:[newSelection elements]];
        if (singleLine) {
            newSelection = [newSelection elementWithElement:singleLine];
        }
    }
    
    newSelection = [_graph changeLineTypeOf:newSelection toConnectMethod:defaultConnectMethod() sort:NO];
    [_s setSelection:newSelection];
    
    [_s sendChange:nil];
}


@end
