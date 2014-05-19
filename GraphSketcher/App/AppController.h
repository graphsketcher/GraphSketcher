// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Cocoa/Cocoa.h>

#import <OmniAppKit/OAController.h>
#import <LinkBack/LinkBack.h>

@class Inspector, OIInspectorRegistry, Preferences, RSMode;


@interface AppController : OAController <LinkBackServerDelegate>
{
    Inspector *_inspector; // Controller object for the inspector panel
}

// Notifications:
- (void)applicationDidFinishLaunching:(NSNotification *)note;


// Showing windows
- (IBAction)showGettingStarted:(id)sender;


// Inspectors
- (OIInspectorRegistry *)inspectorRegistry;
- (OIInspectorRegistry *)inspectorRegistryForWindow:(NSWindow *)window;

// Menu actions implemented elsewhere
- (IBAction)connectPoints:(id)sender;
- (IBAction)connectPointsLeftToRight:(id)sender;
- (IBAction)connectPointsTopToBottom:(id)sender;
- (IBAction)connectPointsCircular:(id)sender;
- (IBAction)fillArea:(id)sender;
- (IBAction)addPointToFill:(id)sender;
- (IBAction)bestFitLine:(id)sender;
- (IBAction)histogram:(id)sender;
- (IBAction)groupUngroup:(id)sender;
- (IBAction)lockUnlock:(id)sender;

- (IBAction)snapToGrid:(id)sender;
- (IBAction)displayGrid:(id)sender;
- (IBAction)selectConnected:(id)sender;
- (IBAction)selectConnectedPoints:(id)sender;
- (IBAction)selectConnectedLines:(id)sender;
- (IBAction)selectConnectedLabels:(id)sender;
- (IBAction)deselect:(id)sender;
- (IBAction)pasteAndConnect:(id)sender;
- (IBAction)pasteAndReplace:(id)sender;
- (IBAction)copyAsImage:(id)sender;

- (IBAction)exportPNG:(id)sender;
- (IBAction)exportJPG:(id)sender;
- (IBAction)exportPDF:(id)sender;
- (IBAction)exportTIFF:(id)sender;
- (IBAction)exportEPS:(id)sender;
- (IBAction)scaleToFitData:(id)sender;

- (IBAction)toggleContinuousSpellCheckingRS:(id)sender;
- (IBAction)toggleSuperscript:(id)sender;
- (IBAction)toggleSubscript:(id)sender;


// Menu actions implemented here
- (IBAction)importData:(id)sender;
- (IBAction)modifyTool:(id)sender;
- (IBAction)drawTool:(id)sender;
- (IBAction)fillTool:(id)sender;
- (IBAction)textTool:(id)sender;


// Menu actions for demos
- (IBAction)demoCurveConstruc:(id)sender;
- (IBAction)demoPenMode:(id)sender;

- (IBAction)openProductPageInBrowser:(id)sender;
- (IBAction)openKeyboardShortcuts:(id)sender;

// Menu validation for actions implemented in this class
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;	// determines whether menus are grayed out


@end
