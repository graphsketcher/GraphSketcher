// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <AppKit/NSDocument.h>
#import <GraphSketcherModel/RSGraphEditorDelegate.h>
#import <GraphSketcherModel/RSUndoerOwner.h>

#define LINKBACK_ENABLED YES
#define OGSLinkBackServerName @"OmniGraphSketcher"

#define WINDOW_TITLE_HEIGHT 18
#define WINDOW_BOTTOM_BAR_HEIGHT 20

typedef enum _RSErrorCodes {
    RSErrorFileLoad = 99,
    RSErrorIncorrectFileTypeForRead = 1,
    RSErrorIncorrectFileTypeForWrite = 2,
    OPErrorDuplicateCustomDataKey = 3,
    OPErrorNothingToPrint = 4,
    OPUserCancelled = 5,
    OPErrorNothingToExport = 6,
    OPErrorWrongFileType = 7,
    RSArchiveFailedError = 8,
    RSBundledGraphDocument = 9,
} RSErrorCodes;

extern NSString *RSErrorDomain;

@class RSGraphEditor, RSGraphView, RSGraph, RSSelector, RSUndoer, LinkBack;

@interface GraphDocument : OADocument <RSGraphEditorDelegate, RSUndoerOwner>
{
    RSGraphEditor *_editor;
    RSGraphView *_graphView;
    
    RSSelector *_s;  // The selection object for this document
    RSUndoer *_u;   // The Undo management object for this document
    
    NSMutableArray *_addedElements;  // Keeps track of graph elements brought back during an undo/redo operation
    
    LinkBack *_linkBack;
    
    BOOL _isFromFile;
    BOOL _isInAppBundle;
    BOOL _isAutosaving;
}


// LinkBack
@property(nonatomic,retain) LinkBack *linkBack;
- (void)sendLinkEdit;
- (void)closeLinkBackConnection;
- (void)linkBackConnectionDidClose:(LinkBack *)link;
- (IBAction)copyAsImageWithPasteboard:(NSPasteboard *)pb;


// Menu and Toolbar items
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
- (void)performMenuItem:(SEL)menuAction;
- (void)performMenuItem:(SEL)menuAction withName:(NSString *)actionName;
- (BOOL)validateToolbarItem:(NSToolbarItem *)item;
- (IBAction)makeCurrentSettingsDefault:(id)sender;
- (IBAction)copyAsImage:(id)sender;

- (BOOL)windowIsOpaque;
- (void)setWindowOpacity:(CGFloat)alpha;
- (IBAction)toggleWindowOpacity:(id)sender;


// Accessor methods
@property(nonatomic,readonly) RSGraphEditor *editor;
- (RSGraph *)graph;
- (RSSelector *)selectorObject;
- (RSUndoer *)undoer;
@property(assign) RSGraphView *graphView;
@property(readonly) BOOL isFromFile;
@property(assign) BOOL isInAppBundle;

@end
