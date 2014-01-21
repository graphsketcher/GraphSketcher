// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/GraphDocument.m 200244 2013-12-10 00:11:55Z correia $

#import "GraphDocument.h"

#import "GraphWindowController.h"
#import "RSGraphView.h"
#import "RSSelector.h"

#import <LinkBack/LinkBack.h>
#import <GraphSketcherModel/OFPreference-RSExtensions.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGrid.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <OmniQuartz/OQColor.h>

NSString *RSErrorDomain = @"OmniGraphSketcher Error Domain";

@implementation GraphDocument

////////////////////////////////////////////
#pragma mark -
#pragma mark Class methods
//////
- (NSWindow *)window;
{
    NSArray *controllers = [self windowControllers];
    if (!controllers || ![controllers count]) {
	OBASSERT_NOT_REACHED("No windowControllers found");
	return nil;
    }
    
    NSWindowController *windowController = [controllers objectAtIndex:0];
    NSWindow *window = [windowController window];
    return window;
}

////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
//////

- (id)init;
{
    self = [super init];
    if (!self)
	return nil;

    // Add your subclass-specific initialization here.
    // If an error occurs here, send a [self release] message and return nil.
    
    _isFromFile = NO;
    _isInAppBundle = NO;
    _isAutosaving = NO;
    _graphView = nil;  // this will be set by the windowController on awakeFromNib.
    
    _linkBack = nil;
    
    // reset "user font"
    //[NSFont setUserFont:[[OFPreferenceWrapper sharedPreferenceWrapper] fontForKey:@"DefaultLabelFont"]];
    
    // Set up Undo
    [self setHasUndoManager:YES];
    // create undo management object
    _u = [(RSUndoer *)[RSUndoer alloc] initWithOwner:self];
    _addedElements = [[NSMutableArray alloc] init];
    
    // create selection object
    _s = [(RSSelector *)[RSSelector alloc] initWithDocument:self];
    
    // Turn on autosaving by specifying the autosave delay in seconds
    [[NSDocumentController sharedDocumentController] setAutosavingDelay:[[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"AutosaveDelaySeconds"]];
    
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(undoManagerWillUndoOrRedo:) name:NSUndoManagerWillUndoChangeNotification object:[self undoManager]];
    [nc addObserver:self selector:@selector(undoManagerWillUndoOrRedo:) name:NSUndoManagerWillRedoChangeNotification object:[self undoManager]];
    [nc addObserver:self selector:@selector(undoManagerDidUndoOrRedo:) name:NSUndoManagerDidUndoChangeNotification object:[self undoManager]];
    [nc addObserver:self selector:@selector(undoManagerDidUndoOrRedo:) name:NSUndoManagerDidRedoChangeNotification object:[self undoManager]];
    
    DEBUG_RS(@"GraphDocument init");
	
    return self;
}

// This gets called only when opening a new, blank document
- (id)initWithType:(NSString *)typeName error:(NSError **)outError;
{
    if ([super initWithType:typeName error:outError] == nil)
        return nil;

    RSGraph *graph;
    [[_u undoManager] disableUndoRegistration];
    @try {
        graph = [[[RSGraph alloc] initWithIdentifier:nil undoer:_u] autorelease];
        [graph setupDefault];
    } @finally {
        [[_u undoManager] enableUndoRegistration];
    }
    
    assert(_editor == nil);
    _editor = [[RSGraphEditor alloc] initWithGraph:graph undoer:_u];
    _editor.delegate = self;
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self undoManager] removeAllActions];
    [self setUndoManager:nil];
    
    [_u invalidate];
    [_s release];
    
    [_editor invalidate];
    [_u release]; // RSGraphEditor calls -invalidate
    _u = nil;
    
    [_addedElements release];
    
    [super dealloc];
}



////////////////////////////////////////////////
#pragma mark -
#pragma mark Opening/Saving
////////////////////////////////////////////////
+ (BOOL)shouldLoadFile:(NSString *)fileName
 writtenByNewerVersion:(OFVersionNumber *)fileVersion
	    appVersion:(OFVersionNumber *)appVersion;
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
    
    NSString *titleFormat = NSLocalizedStringFromTableInBundle(@"'%1$@' was written by a newer version of '%2$@'", nil, [GraphDocument bundle], @"newer file format alert title");
    NSString *title = [NSString stringWithFormat:titleFormat, fileName, appName];
    
    NSString *messageFormat = NSLocalizedStringFromTableInBundle(@"The file was written with version %1$@ while the version of %2$@ you are running understands files written by version %3$@ and older.  Loading this file may not work correctly and might lose some data.", nil, [GraphDocument bundle], @"newer file format alert message");
    NSString *message = [NSString stringWithFormat:messageFormat, [fileVersion cleanVersionString], appName, [appVersion cleanVersionString]];
    
    NSInteger rc = NSRunAlertPanel(title, message, NSLocalizedStringFromTableInBundle(@"Open File", nil, [GraphDocument bundle], @"alert panel button title"), NSLocalizedStringFromTableInBundle(@"Cancel", nil, [GraphDocument bundle], @"alert panel button"), nil);
    return (rc == NSAlertDefaultReturn);
}

- (void)becomeUntitledWithType:(NSString *)docType;
{
    [self setFileURL:nil];
    [self setFileType:docType]; // Resetting this is important so that the document inspector will display the correct state for the 'compressed' checkbox before you've saved the document.
}

////////////////////////////////////////////////
#pragma mark -
#pragma mark NSDocument subclass
////////////////////////////////////////////////

+ (BOOL)autosavesInPlace;
{
    return YES;
}

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation;
{
    return YES;
}

- (BOOL)isDocumentEdited;
{
    // Don't pay attention to edits in bundled graphs like Getting Started.
    if ([self isInAppBundle])
        return NO;
    
    return [super isDocumentEdited];
}

- (void)makeWindowControllers;
{
    GraphWindowController *windowController = [[GraphWindowController alloc] init];
    [self addWindowController:windowController];
    [windowController release];
}



#pragma mark File writing/exporting

//#define GRAPH_DOCUMENT_QUICKLOOK_THUMBNAIL_MAX_SIZE 256

// Thumbnails are now generated from preview.pdf by the QuickLook plugin.  That way they don't take up extra space in the file, and look better in Cover Flow in the Finder.
//
//    // Generate and add a Quicklook thumbnail image
//    NSImage *thumbImage = [[[NSImage alloc] initWithData:qlData] autorelease];
//    // Scale down image if necessary
//    NSSize canvasSize = [_graph canvasSize];
//    NSSize thumbSize = canvasSize;
//    if (canvasSize.width > GRAPH_DOCUMENT_QUICKLOOK_THUMBNAIL_MAX_SIZE || canvasSize.height > GRAPH_DOCUMENT_QUICKLOOK_THUMBNAIL_MAX_SIZE) {
//        float scale = MIN(GRAPH_DOCUMENT_QUICKLOOK_THUMBNAIL_MAX_SIZE/canvasSize.width, GRAPH_DOCUMENT_QUICKLOOK_THUMBNAIL_MAX_SIZE/canvasSize.height);
//        OBASSERT(scale > 0);
//        thumbSize = NSMakeSize(nearbyint(canvasSize.width * scale),
//                               nearbyint(canvasSize.height * scale));
//    }
//    [thumbImage setSize:thumbSize];
//    DEBUG_RS(@"Creating thumbnail with size: %@", NSStringFromSize(thumbSize));
//    // Create tiff data
//    NSData *thumbnailData = [thumbImage TIFFRepresentation];//UsingCompression:NSTIFFCompressionLZW factor:0.0];
//    if (![zipArchive appendZipMemberWithData:thumbnailData preferredFilename:@"thumbnail.tiff" error:outError]) {
//        return NO;
//    }

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError;
{
    // Tell tools/editors to clean and update the model.
    if (!_isAutosaving && _graphView) {
        [_graphView commitEditing];
        [_editor prepareForSave];
    }
    
    // If autosaving, don't waste time with a zip archive.
    // Also don't use a zip archive if the relevant preference is set.
    NSData *previewPDFData = nil;
    if (!_isAutosaving && ![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SaveFilesAsPlainXML"]) {
        // Generate a Quicklook preview and add it to the zip archive
        if (!_graphView) {
            // This happens if we are upgrading a legacy graph file
            //OBASSERT_NOT_REACHED("There is no graphView to generate a pdf");
            //return NO;
        }
        else if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"IncludeQuicklookPreview"] ) {
            previewPDFData = [_graphView dataWithPDFInsideRect:[_graphView bounds]];
        }
    }
    
    NSRect frame = NSZeroRect;
    if ([[self windowControllers] count])  // this will be false during upgrading of a legacy file
        frame = [[self window] frame];
    
    NSData *xmlData = [_editor.graph generateXMLOfType:typeName frame:frame error:outError];
    if (!xmlData) {
        if (outError != NULL)
            OBASSERT(*outError);
        return NO;
    }
    
    // Now that we have all the data ready for writing, we should do the rest off the main thread.
#if defined(MAC_OS_X_VERSION_10_7) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7
    [self unblockUserInteraction];
#endif
    
    BOOL result = [_editor.graph writeToURL:absoluteURL generatedXMLData:xmlData previewPDFData:previewPDFData error:outError];
    
    //sleep(5);
    return result;
}


- (void)autosaveDocumentWithDelegate:(id)delegate didAutosaveSelector:(SEL)didAutosaveSelector contextInfo:(void *)contextInfo;
// Autosave documentation is at: http://developer.apple.com/documentation/Cocoa/Conceptual/Documents/Articles/Autosaving.html#//apple_ref/doc/uid/TP40003276
{
    if ([self isInAppBundle])
        return;
    
#ifdef DEBUG
    NSDate *startTime = [NSDate date];
#endif
    
    _isAutosaving = YES;
    [super autosaveDocumentWithDelegate:delegate didAutosaveSelector:didAutosaveSelector contextInfo:contextInfo];
    _isAutosaving = NO;
    
#ifdef DEBUG
    NSLog(@"Autosave elapsed time: %f", [startTime timeIntervalSinceNow]);
#endif
}


#if defined(MAC_OS_X_VERSION_10_7) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7
- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError *))completionHandler;
{
    if ([self isInAppBundle])
        return;
    
    return [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:completionHandler];
}
#endif

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    if ([self isInAppBundle]) {
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Cannot modify bundled example graphs.", @"error description"), NSLocalizedDescriptionKey, nil];
        if (outError != NULL)
            *outError = [NSError errorWithDomain:RSErrorDomain code:RSBundledGraphDocument userInfo:errorInfo];
	return NO;
    }
    
    return [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
}


- (void)saveDocumentWithDelegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo;
{
    // If this is a LinkBack document, don't display a "save as" panel (just send the edits back to the LinkBack client).
    if (_linkBack != nil) {
        [self sendLinkEdit];
        
        // Perform the callback so that AppKit will close the window and/or do other cleanup tasks
        //- (void)document:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void  *)contextInfo
        if (delegate) {
            void (*delegateImp)(id self, SEL _cmd, NSDocument *doc, BOOL didSave, void *contextInfo);
            delegateImp = (typeof(delegateImp))[delegate methodForSelector:didSaveSelector];
            OBASSERT(delegateImp);
            if (delegateImp)
                delegateImp(delegate, didSaveSelector, self, YES, contextInfo);
        }
        return;
    }
    
    [super saveDocumentWithDelegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}




# pragma mark File reading/importing

- (BOOL)readOGSFileFromData:(NSData *)data fileName:(NSString *)fileName error:(NSError **)outError;
// New file format XML importer
// (See useful similar code in OmniOutliner/OOXMLImporter.m)
{
    RSGraph *graph = [RSGraph graphFromData:data fileName:fileName type:RSGraphFileType undoer:_u error:outError];
    if (!graph)
        return NO;

    _isFromFile = YES;

    [self _resetEditor];
    assert(_editor == nil);
    _editor = [[RSGraphEditor alloc] initWithGraph:graph undoer:_u];
    _editor.delegate = self;
    _graphView.editor = _editor;

    return YES;
}

- (void)_resetEditor;
{
    _graphView.editor = nil;

    [[self undoManager] removeAllActions];
    
    [_u invalidate];
    [_u release];
    _u = nil;

    [_editor invalidate];
    [_editor release];
    _editor = nil;

    _u = [(RSUndoer *)[RSUndoer alloc] initWithOwner:self];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError;
// This method also gets called on "revert to saved"
{
    [self _resetEditor];

    assert(![typeName isEqual:@"com.robinstewart.graphdocument"]); // This type is no longer in our CFBundleDocumentTypes because it's not portable to 64-bit where @encode(NSPoint) is now "{CGPoint=dd}" rather than "{_NSPoint=ff}".

    RSGraph *graph = [RSGraph graphFromURL:absoluteURL type:typeName undoer:_u error:outError];
    if (!graph)
        return NO;

    _isFromFile = YES;

    [self _resetEditor];
    assert(_editor == nil);
    _editor = [[RSGraphEditor alloc] initWithGraph:graph undoer:_u];
    _editor.delegate = self;
    _graphView.editor = _editor;
    
    return YES;
}


- (NSString *)displayName;
{
    if (_linkBack) {
        return [NSString stringWithFormat: @"LinkBack from %@ (%@)", [_linkBack sourceName], [_linkBack sourceApplicationName]];
    } else
        return [super displayName];
}



////////////////////////////////////////////////
#pragma mark -
#pragma mark LinkBack
////////////////////////////////////////////////

@synthesize linkBack = _linkBack;
- (void)setLinkBack:(LinkBack *)link;
{
    if (_linkBack == link)
        return;
    
    if (_linkBack)
        [_linkBack release];
    
    _linkBack = [link retain];
    
    if (!_linkBack)
        return;
    
    // If there is a new, non-nil linkback link, then read its data into this document.
    NSDictionary *linkBackData = [[link pasteboard] propertyListForType: LinkBackPboardType];
    NSData *documentXMLData = [linkBackData linkBackAppData];
    NSError *outError = nil;
    [self readOGSFileFromData:documentXMLData fileName:[self displayName] error:&outError];
}

- (void)sendLinkEdit;
{
    NSPasteboard *pasteboard = [_linkBack pasteboard];
    [self copyAsImageWithPasteboard:pasteboard];
    
    [_linkBack sendEdit];
    
    [self updateChangeCount: NSChangeCleared] ;
}

- (void)closeLinkBackConnection;
{
    if (!_linkBack)
        return;
    
    [_linkBack closeLink];
}

- (void)linkBackConnectionDidClose:(LinkBack *)link;
{
    OBASSERT(_linkBack == link);
    
    [self retain];
    [link setRepresentedObject:nil];
    
    // If there are no unsaved changes, simply close the linkback document.
    if (![self isDocumentEdited]) {
        [self close];
        [self release];
        return;
    }
    
    // If there are unsaved changes, ask the user whether to close or convert to untitled.
    NSString *alertTitle = [NSString stringWithFormat:NSLocalizedString(@"%@ has closed the connection for this LinkBack attachment.  Do you want to keep the changes?", "broken linkback connection dialog - alert text"), [link sourceApplicationName]];
    NSString *errorDescription = NSLocalizedString(@"This document has modifications that cannot be saved because %@ has closed the connection to it or exited.  You may preserve your changes by making this document untitled and severing the link, or you may close this window and abandon your changes.", "broken linkback connection dialog - alert text");
    
    NSBeginAlertSheet(alertTitle,
                      NSLocalizedString(@"Make Untitled", "broken linkback connection dialog - alert button"),
                      NSLocalizedString(@"Don't Save", "broken linkback connection dialog - alert button"),
                      nil,
                      [self windowForSheet],
                      self,
                      @selector(_linkBackDidCloseSheetDidEnd:returnCode:contextInfo:),
                      NULL,
                      nil,
                      errorDescription,
                      [link sourceApplicationName]);
    // _linkBackDidCloseSheetDidEnd:returnCode:contextInfo: will release the document when it gets called (to match the retain at the top of this method)

}

- (void)_linkBackDidCloseSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSAlertDefaultReturn) {
        [self setLinkBack:nil];
        [[NSDocumentController sharedDocumentController] addDocument:self];
        [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeWindowTitleWithDocumentName)];
    } else  
        [self close];
    
    [self autorelease];  // matches the retain in -linkBackConnectionDidClose:
}

#pragma mark -
#pragma mark RSUndoerOwner

- (void)undoerPerformedChange:(RSUndoer *)undoer;
{
    [self updateChangeCount:NSChangeDone];
}

#pragma mark -
#pragma mark RSGraphEditorDelegate

- (void)graphEditorDidUpdate:(RSGraphEditor *)editor;
{
    //don't do this, because we are sometimes called from -drawRect:
    //[_graphView setNeedsDisplay:YES];
    
    [_s sendChange:self];
}

- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
{
    OBPRECONDITION(editor == _editor);
    [_graphView setNeedsDisplay:YES];
}

- (void)graphEditorDeselect:(RSGraphEditor *)editor;
{
    OBPRECONDITION(editor == _editor);

    [(RSGraphView *)_graphView deselect];
    //[_s deselect];
}

- (void)graphEditor:(RSGraphEditor *)editor addedElementDuringUndoOrRedo:(id)element;
{
    OBPRECONDITION(editor == _editor);

    //[_s setSelection:obj];
    [_addedElements addObject:element];
}

////////////////////////////////////////////////
#pragma mark -
#pragma mark Printing
////////////////////////////////////////////////
- (void)printDocument:(id)sender {
    NSPrintInfo *pInfo = [self printInfo];
    [pInfo setHorizontallyCentered:YES];
    [pInfo setVerticallyCentered:YES];
    [pInfo setHorizontalPagination:NSFitPagination];
    [pInfo setVerticalPagination:NSFitPagination];
    [pInfo setLeftMargin:30];
    [pInfo setRightMargin:30];
    [pInfo setTopMargin:30];
    [pInfo setBottomMargin:30];
    
    [_graphView commitEditing];
    
    NSPrintOperation *op = [NSPrintOperation
			    printOperationWithView:_graphView
			    printInfo:pInfo]; //[self printInfo]]; // default printInfo
    
    [op runOperationModalForWindow:[self windowForSheet]
			  delegate:self
		    didRunSelector:@selector(printOperationDidRun:success:contextInfo:)
		       contextInfo:NULL];
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation
		     success:(BOOL)success
		 contextInfo:(void *)info {
    if (success) {
        // Can save updated NSPrintInfo, but only if you have
        // a specific reason for doing so
        // [self setPrintInfo: [printOperation printInfo]];
	
    }
}



/////////////////////////////////////////////
#pragma mark -
#pragma mark Menu items
/////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL menuAction = [menuItem action];
    
    if (menuAction == @selector(saveDocument:)) {
	return !_isInAppBundle;
    }
    else if (menuAction == @selector(revertDocumentToSaved:)) {
        return ([self isDocumentEdited] && [self fileURL]);
    }
    else if (menuAction == @selector(connectPoints:)) {
	if ( [RSGraph hasMultipleVertices:[_s selection]] )
	    [menuItem setTitle:NSLocalizedString(@"In Selection Order", @"Menu item")];
	else
	    [menuItem setTitle:NSLocalizedString(@"In Creation Order", @"Menu item")];
    }
    else if (menuAction == @selector(bestFitLine:)) {
	if ( [_s selected] )
	    [menuItem setTitle:NSLocalizedString(@"Insert Best-Fit Line for Selection", @"Menu item")];
	else
	    [menuItem setTitle:NSLocalizedString(@"Insert Best-Fit Line", @"Menu item")];
    }
    else if (menuAction == @selector(histogram:)) {
	if ( [_editor.graph displayHistogram] ) {
	    //[menuItem setTitle:@"Hide Grid"];
	    [menuItem setState:NSOnState];
	} else {
	    //[menuItem setTitle:@"Display Grid"];
	    [menuItem setState:NSOffState];
	}
    }
    else if (menuAction == @selector(toggleContinuousSpellCheckingRS:)) {
	if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"UseContinuousSpellChecking"] ) {
	    [menuItem setState:NSOnState];
	} else {
	    [menuItem setState:NSOffState];
	}
    }
    else if (menuAction == @selector(toggleWindowOpacity:)) {
	if ( [self windowIsOpaque] )
	    [menuItem setState:NSOffState];
	else
	    [menuItem setState:NSOnState];
    }
    // now pass request along to graphView
    return [_graphView validateMenuItem:menuItem];
}
- (void)performMenuItem:(SEL)menuAction;
{
    [self performMenuItem:menuAction withName:nil];
}
- (void)performMenuItem:(SEL)menuAction withName:(NSString *)actionName;
{
    // pass request along to graphView
    [_graphView performMenuItem:menuAction withName:actionName];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item;
{
    SEL sel = [item action];
    if (sel == @selector(printDocument:)) {
        return YES;
    }
    else if (sel == @selector(toggleWindowOpacity:)) {
        if ([self windowIsOpaque]) {
            [item setLabel:NSLocalizedString(@"Transparent Window", @"Toolbar label")];
            [item setImage:[NSImage imageNamed:@"transparentWindowIcon"]];
        }
        else {
            [item setLabel:NSLocalizedString(@"Opaque Window", @"Toolbar label")];
            [item setImage:[NSImage imageNamed:@"opaqueWindowIcon"]];
        }
        return YES;
    }
    
    // pass request along to graphView
    return [_graphView validateToolbarItem:item];
}

- (IBAction)makeCurrentSettingsDefault:(id)sender;
{
    RSGraph *graph = _editor.graph;
    OFPreferenceWrapper *prefWrapper = [OFPreferenceWrapper sharedPreferenceWrapper];
    
    // Label fonts
    RSTextLabel *recentLabel = [[graph Labels] lastObject];
    [prefWrapper setFontDescriptor:[recentLabel fontDescriptor] forKey:@"DefaultLabelFont"];
    [prefWrapper setFontDescriptor:[[[graph xAxis] maxLabel] fontDescriptor] forKey:@"DefaultXAxisTickLabelFont"];
    [prefWrapper setFontDescriptor:[[[graph yAxis] maxLabel] fontDescriptor] forKey:@"DefaultYAxisTickLabelFont"];
    [prefWrapper setFontDescriptor:[[[graph xAxis] title] fontDescriptor] forKey:@"DefaultXAxisTitleFont"];
    [prefWrapper setFontDescriptor:[[[graph yAxis] title] fontDescriptor] forKey:@"DefaultYAxisTitleFont"];
    
    // Axis visibility settings
    [prefWrapper setBool:[graph displayAxes] forKey:@"DisplayAxis"];
    [prefWrapper setBool:[graph displayAxisLabels] forKey:@"DisplayAxisTickLabels"];
    [prefWrapper setBool:[graph displayAxisTicks] forKey:@"DisplayAxisTicks"];
    [prefWrapper setDouble:[[graph xAxis] tickWidthIn] forKey:@"DefaultAxisTickWidthIn"];
    [prefWrapper setDouble:[[graph xAxis] tickWidthOut] forKey:@"DefaultAxisTickWidthOut"];
    [prefWrapper setBool:[graph displayAxisTitles] forKey:@"DisplayAxisTitles"];
    [prefWrapper setObject:nameFromPlacement([[graph xAxis] placement]) forKey:@"DefaultAxisPlacement"];
    [prefWrapper setBool:[[graph xAxis] displayGrid] forKey:@"DisplayVerticalGrid"];
    [prefWrapper setBool:[[graph yAxis] displayGrid] forKey:@"DisplayHorizontalGrid"];
    [prefWrapper setBool:[[graph xAxis] shape] forKey:@"DefaultAxisShape"];
    
    // Axis style settings
    [OQColor setColor:[[graph xAxis] color] forPreferenceKey:@"DefaultAxisColor"];
    [prefWrapper setDouble:[[graph xAxis] width] forKey:@"DefaultAxisWidth"];
    [OQColor setColor:[[graph xGrid] color] forPreferenceKey:@"DefaultGridColor"];
    [prefWrapper setDouble:[[graph xGrid] width] forKey:@"DefaultGridWidth"];
    [prefWrapper setDouble:[[graph xAxis] titlePlacement] forKey:@"DefaultXAxisTitlePlacement"];
    [prefWrapper setDouble:[[graph yAxis] titlePlacement] forKey:@"DefaultYAxisTitlePlacement"];
    [prefWrapper setObject:nameFromScientificNotationSetting([[graph xAxis] scientificNotationSetting]) forKey:@"ScientificNotationSetting"];
    
    // Canvas settings
    [OQColor setColor:[graph backgroundColor] forPreferenceKey:@"DefaultBackgroundColor"];
    [prefWrapper setObject:NSStringFromSize([graph canvasSize]) forKey:@"LastCanvasSize"];
}



/////////////////////////////////////////////
#pragma mark -
#pragma mark Action methods
/////////////////////////////////////////////
- (IBAction)delete:(id)sender {
    [self performMenuItem:@selector(delete:)];
}
- (IBAction)deleteBackward:(id)sender {
    [self performMenuItem:@selector(deleteBackward:)];
}

- (IBAction)cut:(id)sender {
    [self performMenuItem:@selector(cut:)];
}
- (IBAction)copy:(id)sender {
    [self performMenuItem:@selector(copy:)];
}
- (IBAction)paste:(id)sender {
    [self performMenuItem:@selector(paste:)];
}


- (IBAction)copyAsImageWithPasteboard:(NSPasteboard *)pb;
{
    // relevant pboard types:
    // NSPDFPboardType, NSTIFFPboardType, NSPICTPboardType
    
    [_graphView commitEditing];
    [_graphView setDrawingToScreen:NO];
    
    NSRect r = [_graphView bounds];
    
    // Declare types
    NSArray *pbTypes = [NSArray arrayWithObjects:NSPDFPboardType, kUTTypePNG, NSTIFFPboardType, nil];
    if (LINKBACK_ENABLED) {
        pbTypes = [pbTypes arrayByAddingObject:LinkBackPboardType];
    }
    [pb declareTypes:pbTypes owner:_graphView];
    
    // Copy data to the pasteboard
    [pb setData: [_graphView dataWithPDFInsideRect: r]
	forType: NSPDFPboardType];
    
    [pb setData: [_graphView dataWithPNGInsideRect: r]
	forType: (NSString *)kUTTypePNG];  // NSPasteboardTypePNG is defined in Mac OS X 10.6 and up
    
    [pb setData: [_graphView dataWithTIFFInsideRect: r]
	forType: NSTIFFPboardType];
    
    // Add LinkBack data
    if (LINKBACK_ENABLED) {
        // Tell tools/editors to clean and update the model.
        if (!_isAutosaving && _graphView) {
            [_graphView commitEditing];
            [_editor prepareForSave];
        }
        
        NSRect frame = NSZeroRect;
        if ([[self windowControllers] count])
            frame = [[self window] frame];
        
        NSError *error = nil;
        NSData *documentXMLData = [_editor.graph generateXMLOfType:RSGraphFileType frame:frame error:&error];
        if (!documentXMLData)
            NSLog(@"Unable to generate XML for LinkBack: %@", [error toPropertyList]);


        // Even on error, we need to put something on the pasteboard for this type since we declared it.
        [pb setPropertyList:documentXMLData ? [NSDictionary linkBackDataWithServerName:OGSLinkBackServerName appData:documentXMLData] : nil
                    forType:LinkBackPboardType];
    }
    
    // And we're done
    [_graphView setDrawingToScreen:YES];
}

// copies the whole graph image to the clipboard
- (IBAction)copyAsImage:(id)sender;
{
    [self copyAsImageWithPasteboard:[NSPasteboard generalPasteboard]];
}




- (BOOL)windowIsOpaque;
{
    CGFloat alpha = [_editor.graph windowAlpha];
    OBASSERT(alpha <= 1 && alpha >= 0);
    
    if (alpha == 1)
        return YES;
    
    return NO;
}

- (void)setWindowOpacity:(CGFloat)alpha;
{
    NSWindow *window = [self window];
    
    if (alpha >= 1) {
        [window setOpaque:YES];
        [window setBackgroundColor:[NSColor windowBackgroundColor]];
        [_editor.graph setWindowAlpha:1];
    }
    else {
        [window setOpaque:NO];
        [window setBackgroundColor:[NSColor colorWithDeviceWhite:0 alpha:0]];
        [_editor.graph setWindowAlpha:alpha];
        
        if (alpha < 0.9) {
            // Remember as default
            [[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:(float)alpha forKey:@"DefaultTransparentWindowOpacity"];
        }
    }
    
    [_graphView.editor setNeedsDisplay];
}

- (IBAction)toggleWindowOpacity:(id)sender;
{
    if ([self windowIsOpaque]) {
        float defaultAlpha = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultTransparentWindowOpacity"];
        [self setWindowOpacity:defaultAlpha];
    }
    else {
        [self setWindowOpacity:1];
    }
}


#pragma mark -
#pragma mark Accessor methods

@synthesize editor = _editor;

- (RSGraph *)graph;
{
    return _editor.graph;
}
- (RSSelector *)selectorObject;
{
    return _s;
}
- (RSUndoer *)undoer;
{
    return _u;
}

@synthesize graphView = _graphView;

@synthesize isFromFile = _isFromFile;
@synthesize isInAppBundle = _isInAppBundle;


/////////////////////////////////////////////
#pragma mark -
#pragma mark Undo methods
/////////////////////////////////////////////

- (void)undoManagerWillUndoOrRedo:(NSNotification *)note;
{
    [_addedElements removeAllObjects];
}
- (void)undoManagerDidUndoOrRedo:(NSNotification *)note;
{
    if ([_addedElements count]) {
        RSGroup *G = [[RSGroup alloc] initWithGraph:_editor.graph byCopyingArray:_addedElements];
        [_s setSelection:G];
        [G release];
    }
    
    [_editor setNeedsDisplay];
}


///////////////////////////////////////////
#pragma mark Accessors for scripting
///////////////////////////////////////////
- (NSArray *)lines {
    return [_editor.graph userLineElements];
}

//! TO DO: 
// get name objectSpecifier method code from sketch document class
// more accessors here that route to _graph




@end
