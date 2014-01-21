// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSUndoer.m 200244 2013-12-10 00:11:55Z correia $

#import "RSUndoer.h"

#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSUndoerOwner.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/NSDocument.h>
#endif

@implementation RSUndoer

///////////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////////////////////

- (id)initWithOwner:(NSObject <RSUndoerOwner> *)owner;
{
    if (!(self = [super init]))
        return nil;
    
    _nonretained_owner = owner;
    _undoManager = [[owner undoManager] retain];
    _nilSubstitute = self;
    
    _actions = [[NSMutableDictionary alloc] init];
    _undoKey = nil;
    _undoAction = nil;
    _undoObject = nil;
    
    _exemptObjects = [[NSMutableArray alloc] init];
    
    _delayedUndos = [[NSMutableArray alloc] init];
    _delayedActionName = nil;
    _performingDelayedUndos = NO;
    _delaying = NO;
    
    return self;
}

- (void)dealloc
{
    // Must have been -invalidated.
    OBPRECONDITION(_nonretained_owner == nil);
    OBPRECONDITION(_nonretained_target == nil);
    
    Log1(@"An RSUndoer is being deallocated.");
    
    [self invalidate];
    
    [_actions release];
    [_undoAction release];
    [_delayedUndos release];
    
    [_undoManager release];
    
    [super dealloc];
}

- (void)invalidate;
{
    _nonretained_owner = nil;
    [self setTarget:nil]; // has a side effect
    
    [_exemptObjects release];
    _exemptObjects = nil;
}

@synthesize target = _nonretained_target;
- (void)setTarget:(id <RSUndoerTarget>)target;
{
    // Should either be gaining a target (init) or losing one (dealloc).
    OBPRECONDITION(!_nonretained_target || !target);
    
    if (_nonretained_target)
        [_undoManager removeAllActionsWithTarget:_nonretained_target];
    _nonretained_target = target;
}

///////////////////////////////////////////////////////
#pragma mark -
#pragma mark Accessor methods
///////////////////////////////////////////////////////

- (id)nilSubstitute {
    return _nilSubstitute;
}
- (NSUndoManager *)undoManager {
    return _undoManager;
}
- (id)undoObject {
    return _undoObject;
}
- (void)setUndoObject:(id)obj {
    _undoObject = obj;
}
- (NSString *)undoAction {
    return _undoAction;
}
- (void)setUndoAction:(NSString *)action {
    [_undoAction release];
    _undoAction = [action retain];
}

- (void)addExemptObject:(id)obj;
{
    [_exemptObjects addObject:obj];
}

- (void)removeExemptObject:(id)obj;
{
    if (!_exemptObjects)
        return;
    
    [_exemptObjects removeObjectIdenticalTo:obj];
}


///////////////////////////////////////////////////////
#pragma mark -
#pragma mark Registering undo actions
///////////////////////////////////////////////////////
- (BOOL)firstUndoWithObject:(id)obj key:(NSString *)key;
// Returns YES if this is the first occurrence of the (obj, key) pair since -endRepetiveUndo was last called
{
    if (![_undoManager isUndoRegistrationEnabled])
	return NO;
    
    if ([_exemptObjects containsObjectIdenticalTo:obj]) {
	//DEBUG_UNDOER(@"Exempted object (%@, '%@')", obj, key);
        return NO;  // don't register undo with exempt objects
    }
    
    // Don't collapse undo actions after they have been created.
    NSUndoManager *undoManager = [self undoManager];
    if ([undoManager isUndoing] || [undoManager isRedoing]) {
	[self endRepetitiveUndo];
	DEBUG_UNDOER(@"Is undoing or redoing undo action (%@, '%@')", obj, key);
	return YES;
    }
    
    NSArray *identifier = [NSArray arrayWithObjects:obj, key, nil];
    if ([_actions objectForKey:identifier]) {
	return NO;
    }
    else {
        // Presumably, another undo event is about to be registered.  Before that happens, perform the delayed undo events.
        [self performDelayedUndos];
        
	[_actions setObject:obj forKey:identifier];
	
	_undoObject = obj;
	_undoKey = key;
	
	DEBUG_UNDOER(@"Registered an undo action (%@, '%@')", obj, key);
	return YES;
    }
}

//- (BOOL)firstUndoWithObject:(id)obj key:(NSString *)key;
//// Returns YES if obj and/or key are diffent from those previously passed in.
//// Can be reset with -endRepetitiveUndo
//{
//    // Don't collapse undo actions after they have been created.
//    NSUndoManager *undoManager = [self undoManager];
//    if ([undoManager isUndoing] || [undoManager isRedoing])
//	return YES;
//    
//    if (_undoObject == obj && [_undoKey isEqualToString:key]) {
//	return NO;
//    }
//    else {
//	_undoObject = obj;
//	_undoKey = key;
//	return YES;
//    }
//}

- (void)performDelayedUndos;
{
    if (_performingDelayedUndos)
        return;
    
    if (![_delayedUndos count])
        return;
    
    _performingDelayedUndos = YES;

    for (NSArray *delayed in _delayedUndos) {
        OBASSERT([delayed count] == 2);
        [self registerUndoWithSelector:NSSelectorFromString([delayed objectAtIndex:0]) object:[delayed objectAtIndex:1]];
    }
    
    [_delayedUndos removeAllObjects];
    
    if (_delayedActionName) {
        [self setActionName:_delayedActionName];
        _delayedActionName = nil;
    }
    
    _performingDelayedUndos = NO;
}

- (void)endRepetitiveUndo;
// After calling this method, any further actions will take place in a new undo event group.
{
    DEBUG_UNDOER(@"Ending repetitive undo");
    
    [self performDelayedUndos];
    
    [_actions removeAllObjects];
    _undoKey = nil;
    _undoObject = nil;
    _undoAction = nil;
}

- (void)registerRepetitiveUndoWithObject:(id)obj action:(NSString *)str state:(id)state {
    [self registerRepetitiveUndoWithObject:obj action:str state:state name:nil];
}
- (void)registerRepetitiveUndoWithObject:(id)obj action:(NSString *)str state:(id)state
				    name:(NSString *)name 
{
    if ( _undoObject != obj || _undoAction != str ) {
	//NSLog(@"undoing last change");
	Log2(@"Registering undo for action %@", str);
	[self registerUndoWithObject:obj action:str state:state];
	if ( name )  [self setActionName:name];
    }
    _undoObject = obj;
    _undoAction = str;
    _undoKey = nil;
}
- (void)registerUndoWithObject:(id)obj action:(NSString *)str state:(id)state;
{
    [self registerUndoWithObject:obj action:str state:state name:nil];
}
- (void)registerUndoWithObject:(id)obj action:(NSString *)str state:(id)state name:(NSString *)name;
{
    if (![_undoManager isUndoRegistrationEnabled])
	return;
    
    NSDictionary *D = [NSDictionary dictionaryWithObjectsAndKeys:
                       obj, @"object", state, str, nil];
    [self registerUndoWithSelector:@selector(setAttributes:) object:D];
    
    if (name)
        [self setActionName:name];
}

- (void)registerUndoWithObjectsIn:(RSGraphElement *)obj action:(NSString *)str {
    id state = nil;
    
    if( [obj isKindOfClass:[RSGroup class]] ) {
	for (RSGraphElement *GE in [obj elements])
	{
	    [self registerUndoWithObjectsIn:GE action:str];
	}
    }
    else {  // a single element
	if( [str isEqualToString:@"setGroup"] ) {
	    state = [obj group];
	}
	else if ([str isEqualToString:@"setPosition"]) {
	    state = NSValueFromDataPoint([obj position]);
	}
	else if ([str isEqualToString:@"setSnappedTos"]) {
	    if (![obj isKindOfClass:[RSVertex class]])
		return;
	    OBASSERT([obj isKindOfClass:[RSVertex class]]);
	    state = [(RSVertex *)obj snappedToInfo];
	}
	else {
	    OBASSERT_NOT_REACHED("Unrecognized action in undoWithObjectsIn");
	}
	
	if( !state )  state = [self nilSubstitute];
	[self registerUndoWithObject:obj action:str state:state];
    }
}

- (void)registerDelayedUndoWithObjectsIn:(RSGraphElement *)obj action:(NSString *)str;
// This delays the undo until either (1) another undo is registered, or (2) the undo group is ended.
{
    if (![_undoManager isUndoRegistrationEnabled])
	return;

    _delaying = YES;
    [self registerUndoWithObjectsIn:obj action:str];
    _delaying = NO;
}

- (void)registerUndoWithRemoveElement:(id)obj;
{
    [self registerUndoWithSelector:@selector(removeElement:) object:obj];
}
- (void)registerUndoWithAddElement:(id)obj;
{
    [self registerUndoWithSelector:@selector(addElement:) object:obj];
}

// Private method that does the real work
- (void)registerUndoWithSelector:(SEL)sel object:(id)obj;
{
    if (![_undoManager isUndoRegistrationEnabled])
	return;
    
    OBASSERT(_nonretained_target);
    
    if (_delaying) {
        [_delayedUndos addObject:[NSArray arrayWithObjects:NSStringFromSelector(sel), obj, nil]];
        return;
    }
    
    //[self beginUndoGroupingIfNecessary];
    
    [self performDelayedUndos];
    
    [[self undoManager] registerUndoWithTarget:_nonretained_target
				      selector:sel
					object:obj];
    _undoObject = nil;
    _undoAction = nil;
    
    [_nonretained_owner undoerPerformedChange:self];
}


- (void)setActionName:(NSString *)name;
{
    if (![_undoManager isUndoRegistrationEnabled])
	return;

    // Don't set the actionName yet if there are delayed undo events, because that would create an empty undo group which just has the name.
    if ([_delayedUndos count]) {
        _delayedActionName = name;
        return;
    }
    
    [[self undoManager] setActionName:name];
}


@end
