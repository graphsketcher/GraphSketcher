// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSSelector.h"

#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSLog.h>

#import <OmniInspector/OIInspectorRegistry.h>

#import "AppController.h"

@implementation RSSelector

///////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////
- (id)initWithDocument:(id)document
{
    if (!(self = [super init]))
        return nil;
    
    _document = document;
    
    // initialize things appropriately:
    _selected = NO;
    _selection = [[RSUnknown alloc] init];
    [self setContext:[_selection class]];
    
    _halfSelection = nil;
    
    return self;
}

- (void)dealloc
{
    Log1(@"An RSSelector is being deallocated.");
    
    [_selection release];  // if there is a current selection
    [self setHalfSelection:nil];
    
    [super dealloc];
}


///////////////////////////////////////
#pragma mark -
#pragma mark Main accessors
///////////////////////////////////////
- (RSGraphElement *)selection {
    return _selection;
}

- (void)setSelection:(RSGraphElement *)obj;
{
    if (_selection == obj)
        return;
    
    if ( obj ) {
	[_selection autorelease];
	_selection = [obj retain];
	_selected = YES;
	[self setContext:[_selection class]];
    }
    else { // [setSelection:nil] means [deselect]
	[self deselect];
    }
    
    [self setStatusMessage:[_selection infoString]];
}
- (BOOL)deselect {
    if ( [self selected] ) {
	// take care of the selected object:
	[_selection release];
	_selected = NO;
	
	// manage the RSSelector:
	_selection = [[RSUnknown alloc] init];
	[self setContext:[_selection class]];
	
	return YES; // indicates that a deselect occurred
    }
    else  return NO;  // no deselect happened
}
- (BOOL)selected {
    return _selected;
}

- (void)setContext:(Class)context {
    NSNotificationCenter *nc;
    Log3(@"Selector setContext");
    if ( _context != context ) {
        _context = context;
        nc = [NSNotificationCenter defaultCenter];
        Log3(@"RSSelector sending notification RSContextChanged (to class %@)", _context);
        [nc postNotificationName:@"RSContextChanged" object:nil];
    
        NSWindow *window = [NSApp mainWindow];
        [[[AppController sharedController] inspectorRegistry] updateInspectorForWindow:window];
    }
}
- (Class)context {
    return _context;
}

@synthesize halfSelection = _halfSelection;



///////////////////////////////////////
#pragma mark -
#pragma mark Convenience methods
//(since many objects have a reference to the RSSelector)
///////////////////////////////////////

- (void)sendChange:(id)obj {
    // obj == nil means the changed object is the current selection
    id object = obj;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    Log3(@"Sending notification RSSelectionChanged");
    if ( object == nil )  object = [self selection];  // hahaha!
    [nc postNotificationName:@"RSSelectionChanged" object:object];
    
    NSWindow *window = [NSApp mainWindow];
    [[[AppController sharedController] inspectorRegistry] updateInspectorForWindow:window];
}

- (void)autoScaleIfWanted {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:@"RSAutoScaleIfWanted" object:nil];
}

- (void)setStatusMessage:(NSString *)message;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSChangeToolbarMessage" object:message];
}

- (id)document {
    return _document;
}
- (RSUndoer *)undoer {
    return [_document undoer];
}




@end
