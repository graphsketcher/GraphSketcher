// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSGraphView.h 200244 2013-12-10 00:11:55Z correia $

// RSGraphView is the main NSView at the very heart of GraphSketcher.  It handles most of the menu actions and is the point of entry for keyboard and mouse events.  Over time, much of the functionality here has moved into the Model framework, and anything remaining that is not Mac specific should follow.

#import <AppKit/NSView.h>

#import <OmniInspector/OIInspectableControllerProtocol.h>

#import <GraphSketcherModel/RSGraph.h> // RSModelUpdateRequirement

@class RSUndoer, RSDataMapper, RSGraphRenderer, RSTextLabel, RSGraphElement, RSGraphEditor;
@class RSMode, RSSelector, RSTool;

#define RS_NUDGE_DISTANCE_SHORT 1.0f  // pixels
#define RS_NUDGE_DISTANCE_LONG 20.0f  // pixels


@interface RSGraphView : NSView <OIInspectableController
#if defined(MAC_OS_X_VERSION_10_6) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6)
, NSTextFieldDelegate, NSTextViewDelegate, NSTextStorageDelegate
#endif
>
{
    IBOutlet id windowController;
    
    id _document;
    RSGraphEditor *_editor;
    RSSelector *_s;
    RSMode *_m;
    
    NSMutableArray *_tools;
    
    NSTrackingRectTag _trackingRectTag;
    NSCursor *_penCursor;
    NSCursor *_fillCursor;
    NSUInteger _cursorMode;	// keeps track of state of cursor
    
    CALayer *_halfSelectionLayer;
    
    BOOL _mouseExited;
    BOOL _importingData;
    BOOL _drawingToScreen;
    BOOL _mouseIsDown;
    
    NSTextView *_textView;
    NSAttributedString *_textSnapshot;
    BOOL _discardingEditing;
    BOOL _textViewNeedsUpdate;
    
    NSEvent *_mostRecentEvent; // beware -- not retained
    
    
    BOOL _wasEditingText;
    unsigned _fontActionTag;
    BOOL _connectNextImport;
    
    
    //int _bins[500];  // hack for histogram
}



// Init/access helper classes
@property(readonly) id document;
@property(nonatomic,retain) RSGraphEditor *editor;
@property(nonatomic,readonly) RSGraph *graph;

- (void)setRSSelector:(RSSelector *)selector;
- (RSSelector *)RSSelector;
- (void)setDrawingToScreen:(BOOL)flag;
- (RSTool *)currentTool;
- (void)windowDidResize;


// Notifications:
//- (void)IAmSelectionObjectNotification:(NSNotification *)note;
- (void)selectionChangedNotification:(NSNotification *)note;
- (void)RSToolbarClickedNotification:(NSNotification *)note;
- (void)NSSystemColorsDidChangeNotification:(NSNotification *)note;


// Cursor management
- (NSCursor *)chooseCursor;
- (void)updateCursor;


// Key handling (most methods are not listed here)
- (IBAction)delete:(id)sender;
- (void)moveSelectionBy:(CGPoint)delta;
- (void)moveSelectionInLinearSpaceBy:(RSDataPoint)amount;


// Text handling:
- (void)processTextChange;
- (void)startEditingLabel;
- (RSTextLabel *)stopEditingLabel;
- (void)revertEditsForLabel:(RSTextLabel *)TL;
- (void)removeLabelIfEmpty:(RSTextLabel *)TL;
@property(assign) BOOL wasEditingText;
@property(retain) NSAttributedString *textSnapshot;
- (BOOL)isEditingLabel;

- (void)changeFont:(NSFont *)font toSize:(CGFloat)size;
- (void)changeFontSizeBy:(NSInteger)delta;
- (void)toggleContinuousSpellCheckingRS:(id)sender;


// Cut, Copy, Paste, Duplicate:
- (RSGraphElement *)readElementFromPasteboard:(NSPasteboard *)pb;
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (void)pasteAndReplace:(BOOL)replace;
- (IBAction)pasteAndConnect:(id)sender;
- (RSGraphElement *)duplicateElement:(RSGraphElement *)GE;
- (IBAction)duplicate:(id)sender;


// Menu Item handling
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;	// determine whether a menu is grayed out
- (void)performMenuItem:(SEL)menuAction withName:(NSString *)actionName;
- (IBAction)lockUnlock:(id)sender;
- (IBAction)groupUngroup:(id)sender;
- (IBAction)detachElements:(id)sender;
- (IBAction)showHideGrid:(id)sender;
- (IBAction)changeScientificNotationX:(id)sender;
- (IBAction)changeScientificNotationY:(id)sender;
- (IBAction)changeScientificNotation:(id)sender;
- (RSConnectType)connectMethodFromMenuTag:(NSInteger)tag;
- (IBAction)changeLineType:(id)sender;
- (IBAction)selectAllPoints:(id)sender;
- (IBAction)selectAllLines:(id)sender;
- (IBAction)selectAllFills:(id)sender;
- (IBAction)selectAllLabels:(id)sender;
- (IBAction)makeErrorBars:(id)sender;
- (IBAction)generateStandardNormalData:(id)sender;
- (IBAction)interpolateLinesToData:(id)sender;
- (IBAction)addJitterToData:(id)sender;
- (IBAction)swapAxes:(id)sender;
- (IBAction)toggleTickLayoutAtData:(id)sender;
- (IBAction)importDataSeriesReplacingCurrent:(id)sender;


// Exporting
- (void)runExportPanelWithFileType:(NSString *)fileType fileTypeName:(NSString *)fileTypeName;
- (NSData *)dataWithPNGInsideRect:(NSRect)r;
- (NSData *)dataWithJPGInsideRect:(NSRect)r;
- (NSData *)dataWithTIFFInsideRect:(NSRect)r;


// Utility methods
- (void)deselect;
- (void)setSelection:(RSGraphElement *)obj;

- (NSArray *)allOrSelectedVertices;
- (NSArray *)allOrSelectedLines;


// EXPERIMENTAL
//- (int *)computeHistogramBins:(int *)bins;


// DEBUGGING
#ifdef DEBUG
//- (void)drawControlPoints;
//- (void)drawCurveFromVertexArray:(NSArray *)VArray;
- (void)testMethod;
#endif

@end
