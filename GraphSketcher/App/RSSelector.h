// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSSelector keeps track of what objects are selected and also has some convenience methods for sending out various notifications.  Those are legacy and should probably be moved to RSGraphEditor or something.

#import <OmniFoundation/OFObject.h>

@class RSUndoer, RSGraphElement;

@interface RSSelector : OFObject
{
    bool _selected;
    Class _context;
    RSGraphElement * _selection;
    RSGraphElement * _halfSelection;
    id _document;
}

// Designated initializer:
- (id)initWithDocument:(id)document;


// Selecting actions:
- (RSGraphElement *)selection;
- (void)setSelection:(RSGraphElement *)obj;
- (BOOL)deselect; // returns YES if a deselect was actually necessary
- (BOOL)selected;

- (void)setContext:(Class)context; // don't use this
- (Class)context;

@property(retain) RSGraphElement *halfSelection;


// Convenience methods:
- (void)sendChange:(id)obj;
- (void)autoScaleIfWanted;
- (void)setStatusMessage:(NSString *)message;

- (id)document;
- (RSUndoer *)undoer;

@end
