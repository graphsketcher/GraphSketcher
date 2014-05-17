// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSUndoer handles GraphSketcher's more complex undo capabilities. Registering a "repetitive undo" means that only the first call in any sequence with the same action name will go on the undo stack. This is necessary for operations such as dragging points around the screen. The method -firstUndoWithObject:key: lets you find out if this is the first in a sequence, so that you can then use other NSUndoManager features.  RSUndoer also accepts "exempt objects" which are temporary graph elements used by the draw and fill tools that should not participate in undo.  And it lets you perform "delayed undos" which don't interrupt sequences of repetitive undos.

#import <OmniFoundation/OFObject.h>

@class RSAxis, RSGraphElement;
@protocol RSUndoerOwner, RSUndoerTarget;

@interface RSUndoer : OFObject
{
@private
    NSObject <RSUndoerOwner> *_nonretained_owner;
    id <RSUndoerTarget> _nonretained_target;
    NSUndoManager *_undoManager;
    id _nilSubstitute;
        
    NSMutableDictionary *_actions;
    NSString *_undoKey;
    id _undoObject;
    NSString *_undoAction;
    
    NSMutableArray *_exemptObjects;  // objects for which undo should not be registered
    
    NSMutableArray *_delayedUndos;
    NSString *_delayedActionName;
    BOOL _delaying;
    BOOL _performingDelayedUndos;
}

- (id)initWithOwner:(NSObject <RSUndoerOwner> *)owner;

- (void)invalidate;

@property(nonatomic,assign) id <RSUndoerTarget> target;

// Accessor methods
- (id)nilSubstitute;
- (NSUndoManager *)undoManager;
// Probably unnecessary accessor methods:
- (id)undoObject;
- (void)setUndoObject:(id)obj;
- (NSString *)undoAction;
- (void)setUndoAction:(NSString *)action;

- (void)addExemptObject:(id)obj;
- (void)removeExemptObject:(id)obj;


// Registering Undo actions
- (BOOL)firstUndoWithObject:(id)obj key:(NSString *)key;
- (void)performDelayedUndos;
- (void)endRepetitiveUndo;
- (void)registerRepetitiveUndoWithObject:(id)obj action:(NSString *)str state:(id)state;
- (void)registerRepetitiveUndoWithObject:(id)obj action:(NSString *)str state:(id)state
				    name:(NSString *)name;
- (void)registerUndoWithObject:(id)obj action:(NSString *)str state:(id)state;
- (void)registerUndoWithObject:(id)obj action:(NSString *)str state:(id)state name:(NSString *)name;
- (void)registerUndoWithObjectsIn:(RSGraphElement *)obj action:(NSString *)str;
- (void)registerDelayedUndoWithObjectsIn:(RSGraphElement *)obj action:(NSString *)str;
- (void)registerUndoWithRemoveElement:(id)obj;
- (void)registerUndoWithAddElement:(id)obj;

- (void)registerUndoWithSelector:(SEL)sel object:(id)obj;   // private

// Setting Undo menu item name
- (void)setActionName:(NSString *)name;

@end
