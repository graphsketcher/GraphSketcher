// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/AppController.m 200244 2013-12-10 00:11:55Z correia $

#import "AppController.h"

#import <GraphSketcherModel/OFPreference-RSExtensions.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSGraph-XML.h>
#import <OmniInspector/OIInspectorRegistry.h>

#import "GraphDocument.h"
#import "GraphWindowController.h"
#import "InfoPlist.h"
#import "RSMode.h"
#import "RSSelector.h"

// Cause our mdimporter to get run if it has been updated.  Note that we won't "downgrade" the index if you run an app with an older importer.
//static void RebuildSpotlightIndexIfNewerMetadataImporter(void)
//{
//    static NSString * const MetadataImporterBundleName = @"OGSSpotlightPlugin";
//    
//    NSString *mdimport = @"/usr/bin/mdimport";
//    NSFileManager *manager = [NSFileManager defaultManager];
//    if (![manager fileExistsAtPath:mdimport])
//        return;
//    
//    NSBundle *mainBundle = [NSBundle mainBundle];
//    NSString *importerPath = [[mainBundle bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"Contents/Library/Spotlight/%@.mdimporter", MetadataImporterBundleName]];
//    NSBundle *importerBundle = [NSBundle bundleWithPath:importerPath];
//    if (!importerBundle) {
//        NSLog(@"Unable to locate Spotlight import bundle in our app wrapper");
//        return;
//    }
//    
//    NSString *importerVersionString = [[importerBundle infoDictionary] objectForKey:@"CFBundleVersion"];
//    OFVersionNumber *importerVersionNumber = nil;
//    if (importerVersionString)
//        importerVersionNumber = [[[OFVersionNumber alloc] initWithVersionString:importerVersionString] autorelease];
//    if (!importerVersionNumber) {
//        NSLog(@"Unable to parse Spotlight import bundle version number '%@'", importerVersionString);
//        return;
//    }
//    
//    static NSString * const LastRunImporterVersionStringDefaultKey = @"com.omnigroup.OmniAppKit.LatestSpotlightImporterVersion";
//    NSString *latestRunImporterVersionString = [[NSUserDefaults standardUserDefaults] stringForKey:LastRunImporterVersionStringDefaultKey];
//    OFVersionNumber *latestRunImporterVersionNumber = nil;
//    if (latestRunImporterVersionString)
//        latestRunImporterVersionNumber = [[[OFVersionNumber alloc] initWithVersionString:latestRunImporterVersionString] autorelease];
//    
//    if (latestRunImporterVersionNumber && [latestRunImporterVersionNumber compareToVersionNumber:importerVersionNumber] != NSOrderedAscending) {
//#ifdef DEBUG
//        NSLog(@"Don't need to rebuild spotlight");
//#endif
//        return;
//    }
//    
//    [[NSUserDefaults standardUserDefaults] setObject:importerVersionString forKey:LastRunImporterVersionStringDefaultKey];
//    
//    // This pokes Finder into updating its list of query keys
//    if ([manager fileExistsAtPath:@"/Library/Spotlight"]) {
//        static NSString * const MagicFileName = @"/Library/Spotlight/.com.omnigroup.OmniAppKit.please.rebuild.my.metadata.keys";
//        [[NSData data] writeToFile:MagicFileName atomically:NO];
//        [manager removeFileAtPath:MagicFileName handler:nil];
//    }
//    
//    // Re-index the documents
//    NSString *appName = [[mainBundle infoDictionary] objectForKey:(id)kCFBundleNameKey];
//    NSLog(@"This version of %@ has a newer Spotlight importer (%@, version %@) than previously run (%@).  Requesting a re-index of files handled by our importer.", appName, importerPath, importerVersionString, latestRunImporterVersionString);
//    
//    // We don't wait for termination
//    [NSTask launchedTaskWithLaunchPath:mdimport arguments:[NSArray arrayWithObjects:@"-r", importerPath, nil]];
//}


@implementation AppController

///////////////////////////////
#pragma mark -
#pragma mark NSInputContext hack
// (copied from OmniOutliner 4/trunk)
// We're hoping that this will fix a crasher in NSInputContext: <bug://bugs/53268>

static id (*_original_keyBindingState)(id self, SEL _cmd) = NULL;
static id _replacement_keyBindingState(id self, SEL _cmd)
{
    id result = _original_keyBindingState(self, _cmd);
    return [[result retain] autorelease];
}

+ (void)performPosing;
{
    Class NSTSMInputContext = NSClassFromString(@"NSTSMInputContext");
    if (NSTSMInputContext) {
        SEL sel = @selector(keyBindingState);
        if ([NSTSMInputContext instancesRespondToSelector:sel])
            _original_keyBindingState = (typeof(_original_keyBindingState))OBReplaceMethodImplementation(NSTSMInputContext, sel, (IMP)_replacement_keyBindingState);
    }
}


///////////////////////////////
#pragma mark -
#pragma mark Class methods
///////////////////////////////
- (id)frontDocument
// returns a reference to the foremost document controller
{
    // Get shared document controller:
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    // Return frontmost document
    return [dc currentDocument];
}

#if 0
- (GraphDocument *)documentAtPath:(NSString *)path load:(BOOL)shouldLoad error:(NSError **)outError;
{
    path = [path stringByResolvingSymlinksInPath]; // Seem to need this in 10.1 to get the /automount prefix...
    NSURL *url = [NSURL fileURLWithPath:path];
    
    NSDocumentController *sharedDocumentController = [NSDocumentController sharedDocumentController];
    GraphDocument *document = [sharedDocumentController documentForURL:url];
    if (document == nil && shouldLoad)
	document = [sharedDocumentController openDocumentWithContentsOfURL:url display:YES error:outError];
    
    return document;
}

- (void)showDocumentNamed:(NSString *)documentName;
{
    NSString *type = @"ograph";
    NSString *documentPath = [[NSBundle mainBundle] pathForResource:documentName ofType:type];
    if (documentPath == nil) {
	NSLog(@"Could not find bundled document '%@' of type '%@'", documentName, type);
	return;
    }
    
    NSError *error = nil;
    GraphDocument *document = [self documentAtPath:documentPath load:YES error:&error];
    if (!document)
	[NSApp presentError:error];
    
    [document setIsInAppBundle:YES];
    DEBUG_RS(@"Loaded '%@' from app bundle.", documentName);
    
    [document showWindows];
}
#else
- (void)showDocumentNamed:(NSString *)documentName;
{
    NSString *extension = @"ograph";
    NSURL *documentURL = [[NSBundle mainBundle] URLForResource:documentName withExtension:extension];
    if (documentURL == nil) {
	NSLog(@"Could not find bundled document '%@' of with extension '%@'", documentName, extension);
	return;
    }
    
    NSError *error = nil;
    GraphDocument *document = [[NSDocumentController sharedDocumentController] makeDocumentForURL:nil withContentsOfURL:documentURL ofType:RSGraphFileType error:&error];
    if (!document)
	[NSApp presentError:error];

    [document makeWindowControllers];
    [document showWindows];
}
#endif

///////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////
// First message class gets sent is...
//+ (void)initialize;
//{
//    // Set up default user font:
//    [NSFont setUserFont:[[OFPreferenceWrapper sharedPreferenceWrapper] fontForKey:@"DefaultLabelFont"]];
//}

- (void)dealloc
{
    [_inspector release];
    
    [super dealloc];
}

/////////////////////////////////
#pragma mark -
#pragma mark NSApplication delegate
/////////////////////////////////

static inline void removeMenuItem(NSMenu *menu, id target, SEL action)
{
    OBPRECONDITION(menu != nil);

    NSInteger menuItemIndex = [menu indexOfItemWithTarget:target andAction:action];
    if (menuItemIndex == -1)
        menuItemIndex = [menu indexOfItemWithTarget:target andAction:NULL];
    OBASSERT(menuItemIndex != -1);
    if (menuItemIndex == -1)
        return;
    [menu removeItemAtIndex:menuItemIndex];
    if (menuItemIndex > 0 && menuItemIndex < [menu numberOfItems] && [[menu itemAtIndex:menuItemIndex] isSeparatorItem] && [[menu itemAtIndex:menuItemIndex - 1] isSeparatorItem])
        [menu removeItemAtIndex:menuItemIndex]; // If we're left with two separators in a row, remove one
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
    [NSColor setIgnoresAlpha:NO];
    
    [[OFController sharedController] didInitialize];
    
    // Add a menu of experimental features if the preference for it is turned on.
    if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"ShowExperimentalFeaturesMenu"]) {
        NSMenu *experimentalMenu = [[NSMenu alloc] initWithTitle:@"Experimental"];
        NSInteger index = -1;
        [experimentalMenu insertItemWithTitle:@"Generate Normal Data" action:@selector(generateStandardNormalData:) keyEquivalent:@"" atIndex:++index];
        
        [experimentalMenu insertItem:[NSMenuItem separatorItem] atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"Tufte Tick Marks" action:@selector(toggleTickLayoutAtData:) keyEquivalent:@"" atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"Tufte Axis Extent" action:@selector(toggleAxesUseDataExtent:) keyEquivalent:@"" atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"Show Data Quartiles" action:@selector(toggleAxesUseDataQuartiles:) keyEquivalent:@"" atIndex:++index];
        
        [experimentalMenu insertItem:[NSMenuItem separatorItem] atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"Dotted Grid Lines" action:@selector(toggleDottedGrid:) keyEquivalent:@"" atIndex:++index];
        
        [experimentalMenu insertItem:[NSMenuItem separatorItem] atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"y = x^2 + c" action:@selector(addEquationLine:) keyEquivalent:@"" atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"y = x^3 + c" action:@selector(addEquationLine:) keyEquivalent:@"" atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"y = sin(x) + c" action:@selector(addEquationLine:) keyEquivalent:@"" atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"y = e^(-x^2) + c (Bell Curve)" action:@selector(addEquationLine:) keyEquivalent:@"" atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"y = 1/(1 + e^-x) + c (Logistic)" action:@selector(addEquationLine:) keyEquivalent:@"" atIndex:++index];
        
        [experimentalMenu insertItem:[NSMenuItem separatorItem] atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"Import and Replace Data" action:@selector(importDataSeriesReplacingCurrent:) keyEquivalent:@"" atIndex:++index];
        [experimentalMenu insertItemWithTitle:@"Import Data Series In Rows" action:@selector(importDataInRows:) keyEquivalent:@"" atIndex:++index];
        
        NSMenuItem *experimentalMenuItem = [[NSMenuItem alloc] initWithTitle:@"Experimental" action:NULL keyEquivalent:@""];
        [experimentalMenuItem setImage:[NSImage imageNamed:@"experimental"]];
        [experimentalMenuItem setSubmenu:experimentalMenu];
        [[NSApp mainMenu] insertItem:experimentalMenuItem atIndex:7];
        
        [experimentalMenu release];
        [experimentalMenuItem release];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    DEBUG_RS(@"ApplicationDidFinishLaunching");
    
    BOOL firstTimeUser = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"GSFirstTimeUser"];
    if (firstTimeUser) {
	
	// Open up the bundled file "Getting Started.ograph"
	[self showDocumentNamed:@"Getting Started"];
	
	[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:NO forKey:@"GSFirstTimeUser"];
    }
    
    [self checkMessageOfTheDay];
    
    [self startedRunning];
    
    if (LINKBACK_ENABLED) {
        [LinkBack publishServerWithName:OGSLinkBackServerName bundleIdentifier:@"com.graphsketcher.GraphSketcher" delegate:self];
        [LinkBack publishServerWithName:OGSLinkBackServerName bundleIdentifier:@"com.graphsketcher.GraphSketcher.MacAppStore" delegate:self];
    }
    
    
    // I'm going to turn this off because it appears to be fixing a 10.4 bug, and I'd rather not force users' computers to rebuild metadata unnecessarily.
    //RebuildSpotlightIndexIfNewerMetadataImporter();
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
{
    // TODO: End editing in any open documents to commit any pending changes

    switch ([self requestTermination]) {
        case OFControllerTerminateCancel:
            return NSTerminateCancel;
        case OFControllerTerminateLater:
            return NSTerminateLater;
        case OFControllerTerminateNow:
        default:
	    return NSTerminateNow;
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification;
{
    [self willTerminate];
}



/////////////////////////////////////////
#pragma mark -
#pragma mark LinkBackServerDelegate protocol
/////////////////////////////////////////

- (void)linkBackClientDidRequestEdit:(LinkBack*)link ;
// When a client requests an edit of your application data, your server delegate will receive the -linkBackClientDidRequestEdit: message.  The object passed in is an instance of the LinkBack class.  This represents a single connection between the client and the server application.  You should respond to this message by either opening the data for editing or by automatically refreshing the data.
{
    // Much of this copied from OmniGraffle's LiveLinkHelper
    GraphDocument *document = [link representedObject];
    if (document == nil) {
        NSError *errBuf = nil;
        document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:NO error:&errBuf];
        if (!document) {
            // LinkBack doesn't support NSError returns, but it's DO, so it should handle exceptions
            [[NSException exceptionWithName:NSGenericException reason:[errBuf localizedDescription] userInfo:[NSDictionary dictionaryWithObject:errBuf forKey:@"NSError"]] raise];
        }
        [link setRepresentedObject:document];
        [document setLinkBack:link];
    }
    
    // display the document
    if (![[document windowControllers] count])
        [document makeWindowControllers];
    [document showWindows];
    
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)linkBackDidClose:(LinkBack*)link ;
{
    GraphDocument *document = [link representedObject];
    if ([document linkBack] == link) {
        [document linkBackConnectionDidClose:link];
    } else {
        OBASSERT_NOT_REACHED("Got linkBackDidClose: from a link that we don't think is open");
        [link setRepresentedObject:nil];
    }
}


/////////////////////////////////////////
#pragma mark -
#pragma mark Showing windows
/////////////////////////////////////////
- (IBAction)showGettingStarted:(id)sender;
{
    // Open up the bundled file "Getting Started.ograph"
    [self showDocumentNamed:@"Getting Started"];
}

/////////////
#pragma mark -
#pragma mark Menu actions implemented elsewhere
/////
- (IBAction)connectPoints:(id)sender
{
    //[[self frontDocument] connectPoints:sender];
    [[self frontDocument] performMenuItem:@selector(connectPoints:) withName:[sender title]];
}
- (IBAction)connectPointsLeftToRight:(id)sender {
    [[self frontDocument] performMenuItem:@selector(connectPointsLeftToRight:) withName:[sender title]];
}
- (IBAction)connectPointsTopToBottom:(id)sender {
    [[self frontDocument] performMenuItem:@selector(connectPointsTopToBottom:) withName:[sender title]];
}
- (IBAction)connectPointsCircular:(id)sender {
    [[self frontDocument] performMenuItem:@selector(connectPointsCircular:) withName:[sender title]];
}


- (IBAction)fillArea:(id)sender {
    [[self frontDocument] performMenuItem:@selector(fillArea:) withName:[sender title]];
}
- (IBAction)addPointToFill:(id)sender {
    [[self frontDocument] performMenuItem:@selector(addPointToFill:) withName:[sender title]];
}
- (IBAction)bestFitLine:(id)sender {
    [[self frontDocument] performMenuItem:@selector(bestFitLine:) withName:[sender title]];
}
- (IBAction)histogram:(id)sender {
    [[self frontDocument] performMenuItem:@selector(histogram:) withName:[sender title]];
}
- (IBAction)groupUngroup:(id)sender {
    [[self frontDocument] performMenuItem:@selector(groupUngroup:) withName:[sender title]];
}
- (IBAction)lockUnlock:(id)sender {
    [[self frontDocument] performMenuItem:@selector(lockUnlock:) withName:[sender title]];
}


- (IBAction)snapToGrid:(id)sender {
    [[self frontDocument] performMenuItem:@selector(snapToGrid:) withName:[sender title]];
}
- (IBAction)displayGrid:(id)sender {
    [[self frontDocument] performMenuItem:@selector(displayGrid:) withName:[sender title]];
}
- (IBAction)selectConnected:(id)sender {
    [[self frontDocument] performMenuItem:@selector(selectConnected:) withName:[sender title]];
}
- (IBAction)selectConnectedPoints:(id)sender {
    [[self frontDocument] performMenuItem:@selector(selectConnectedPoints:) withName:[sender title]];
}
- (IBAction)selectConnectedLines:(id)sender {
    [[self frontDocument] performMenuItem:@selector(selectConnectedLines:) withName:[sender title]];
}
- (IBAction)selectConnectedLabels:(id)sender {
    [[self frontDocument] performMenuItem:@selector(selectConnectedLabels:) withName:[sender title]];
}
- (IBAction)deselect:(id)sender;
{
    [[self frontDocument] performMenuItem:[sender action]];
}
- (IBAction)pasteAndConnect:(id)sender {
    [[self frontDocument] performMenuItem:@selector(pasteAndConnect:) withName:[sender title]];
}
- (IBAction)pasteAndReplace:(id)sender {
    [[self frontDocument] performMenuItem:@selector(pasteAndReplace:) withName:[sender title]];
}
- (IBAction)copyAsImage:(id)sender {
    [[self frontDocument] copyAsImage:sender];
}

- (IBAction)exportPNG:(id)sender {
    [[self frontDocument] performMenuItem:@selector(exportPNG:) withName:[sender title]];
}
- (IBAction)exportJPG:(id)sender {
    [[self frontDocument] performMenuItem:@selector(exportJPG:) withName:[sender title]];
}
- (IBAction)exportPDF:(id)sender {
    [[self frontDocument] performMenuItem:@selector(exportPDF:) withName:[sender title]];
}
- (IBAction)exportTIFF:(id)sender {
    [[self frontDocument] performMenuItem:@selector(exportTIFF:) withName:[sender title]];
}
- (IBAction)exportEPS:(id)sender {
    [[self frontDocument] performMenuItem:@selector(exportEPS:) withName:[sender title]];
}


- (IBAction)scaleToFitData:(id)sender {
    [[self frontDocument] performMenuItem:@selector(scaleToFitData:) withName:[sender title]];
}


- (IBAction)toggleContinuousSpellCheckingRS:(id)sender {
    [[self frontDocument] performMenuItem:@selector(toggleContinuousSpellCheckingRS:) withName:[sender title]];
}
- (IBAction)toggleSuperscript:(id)sender {
    [[self frontDocument] performMenuItem:@selector(toggleSuperscript:) withName:[sender title]];
}
- (IBAction)toggleSubscript:(id)sender {
    [[self frontDocument] performMenuItem:@selector(toggleSubscript:) withName:[sender title]];
}



/////////////
#pragma mark -
#pragma mark Menu actions implemented in this class
/////

- (IBAction)openProductPageInBrowser:(id)sender;
{
    NSString *productPageURLString = [[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:@"ProductPageURL"];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:productPageURLString]];
}

- (IBAction)openKeyboardShortcuts:(id)sender;
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"GraphSketcher Keyboard Shortcuts" ofType:@"pdf"];
    [[NSWorkspace sharedWorkspace] openFile:path];// withApplication:@"Preview"];
}

- (IBAction)importData:(id)sender;
    // display pop-up window explaining that you should copy/paste
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedStringFromTable(@"Importing Data", @"DataImporter", @"Alert explaining how to import data")];
    [alert setInformativeText:NSLocalizedStringFromTable(@"To import and plot data from a spreadsheet, database, or text file, copy (⌘C) the data and paste it (⌘V) directly onto your graph.\n\nThe data must be in columns. If you include column headers, they will automatically be interpreted as axis titles. If the first column is descriptive labels, each label will be associated with the data point that follows.", @"DataImporter", @"Alert explaining how to import data")];
    [alert addButtonWithTitle:NSLocalizedStringFromTable(@"Okay", @"DataImporter", @"Alert explaining how to import data")];
    [alert setShowsHelp:YES];
    [alert setHelpAnchor:@"importdata"];
    
    [alert runModal];
    [alert release];
}

- (IBAction)modifyTool:(id)sender {
    [[RSMode sharedModeController] registerClick:RS_modify];
    [[[self frontDocument] graphView] resetCursorRects];
}
- (IBAction)drawTool:(id)sender {
    [[RSMode sharedModeController] registerClick:RS_draw];
    [[[self frontDocument] graphView] resetCursorRects];
}
- (IBAction)fillTool:(id)sender {
    [[RSMode sharedModeController] registerClick:RS_fill];
    [[[self frontDocument] graphView] resetCursorRects];
}
- (IBAction)textTool:(id)sender {
    [[RSMode sharedModeController] registerClick:RS_text];
    [[[self frontDocument] graphView] resetCursorRects];
}


///////////////////////////////
#pragma mark -
#pragma mark Defaults
///////////////////////////////

//! Copied from old Preferences window.  Should expose in UI somewhere.  In the standard OmniAppKit preferences pane, when you hold down option you get a button to "reset all" prefs, but this just applies to those things controlled in the preferences panes.
- (IBAction)resetAllDefaults:(id)sender {
    // Reset all default values
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSEnumerator *E = [dict keyEnumerator];
    NSString *key;
    while ((key = [E nextObject])) {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
    
    // post notification so that Inspector updates its display too
    [[NSNotificationCenter defaultCenter] 
     postNotificationName:@"RSContextChanged" object:nil];
    [OIInspectorRegistry updateInspector];
}



/////////////
#pragma mark -
#pragma mark Menu actions for demos
/////
- (IBAction)demoCurveConstruc:(id)sender {
    [[self frontDocument] performMenuItem:@selector(demoCurveConstruc:)];
}
- (IBAction)demoPenMode:(id)sender {
    [[OFPreferenceWrapper sharedPreferenceWrapper] 
     setBool: [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"DrawCurvedLines"]
     forKey: @"DrawCurvedLines"];
}


/////////////
#pragma mark -
#pragma mark Menu validation for actions implemented in this class
/////
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];
    
    if (action == @selector(importData:)) {
	return YES;
    }
    else if (action == @selector(demoPenMode:)) {
	if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"DrawCurvedLines"] ) {
	    [menuItem setState:NSOnState];
	} else {
	    [menuItem setState:NSOffState];
	}
	
	return YES;
    }
    // seems like there should be a better way, but this does the trick without requiring a major re-write.
    else if ( action == @selector(showMessageOfTheDay:) || action == @selector(sendFeedback:) || action == @selector(openProductPageInBrowser:) || action == @selector(showAboutPanel:) || action == @selector(showPreferences:) || action == @selector(showGettingStarted:) || action == @selector(openKeyboardShortcuts:) )
    {
	return YES;
    }
    else  return [[self frontDocument] validateMenuItem:menuItem];
}

@end
