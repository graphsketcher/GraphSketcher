// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSMode.m 200244 2013-12-10 00:11:55Z correia $

#import "RSMode.h"

#import "RSModifyTool.h"
#import "RSDrawTool.h"
#import "RSFillTool.h"
#import "RSTextTool.h"

#import <GraphSketcherModel/RSLog.h>


static NSUInteger modeFromChar(unichar theChar)
{
    // If shift key is down, event characters are in uppercase.  Convert to lowercase for proper comparison.  <bug://bugs/56347>
    if (!islower(theChar)) {
        theChar = tolower(theChar);
    }
    
    switch (theChar) {
	case RS_HOTKEY_DRAW:
	    return RS_draw;
	    break;
	case RS_HOTKEY_FILL:
	    return RS_fill;
	    break;
////Text doesn't really work because the hotkey starts getting inserted into the newly-created label
//	case RS_HOTKEY_TEXT:
//	    return RS_text;
//	    break;
	default:
	    return RS_none;
	    break;
    }
}


@interface RSMode (PrivateAPI)
- (void)setMode:(NSUInteger)newMode;

@end


@implementation RSMode

+ (RSMode *)sharedModeController
{
    static RSMode *_sharedModeController = nil;
    
    if (!_sharedModeController) {
        _sharedModeController = [[RSMode allocWithZone:[self zone]] init];
    }
    return _sharedModeController;
}


#pragma mark -
#pragma mark init/dealloc

// DESIGNATED INITIALIZER
- (id)init;
{
    if (!(self = [super init]))
        return nil;
    
    // default starting values
    _lastClickedMode = _currentMode = _lastKeyMode = RS_modify;
    
    [self resetFlags];
    _mouseDragging = NO;
    _globalViewMouseMovedPoint = NSMakePoint(0, 0);
    
    // Register to receive notifications when modifier keys are changed
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(RSFlagsChangedNotification:)
                                                 name:@"RSFlagsChanged"
                                               object:nil];
    
    Log1(@"RSMode initialized.");
    return self;
}

- (void)dealloc
{
    Log1(@"An RSMode is being deallocated.");
    
    // unregister observer from notification center
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
    
    // nothing retained
    
    [super dealloc];
}


///////////////////////////////////
#pragma mark -
#pragma mark Notifications
///////////////////////////////////
- (void)RSFlagsChangedNotification:(NSNotification *)note
{
    Log3(@"RSMode received notification: %@", note);
    
    NSEvent *event = [note object];
    _modifierFlags = [event modifierFlags];
}

//NSAlphaShiftKeyMask - Set if Caps Lock key is pressed.
//NSShiftKeyMask - Set if Shift key is pressed.
//NSControlKeyMask - Set if Control key is pressed.
//NSAlternateKeyMask - Set if Option or Alternate key is pressed.
//NSCommandKeyMask - Set if Command key is pressed.
//NSNumericPadKeyMask - Set if any key in the numeric keypad is pressed.
//NSHelpKeyMask - Set if the Help key is pressed.
//NSFunctionKeyMask - Set if any function key is pressed.




///////////////////////////////////
#pragma mark -
#pragma mark Accessor methods
///////////////////////////////////
- (NSUInteger)mode {
    return _currentMode;
}

// This method is private
- (void)setMode:(NSUInteger)newMode {
    
    if ( newMode == _currentMode )  // mode has not changed
	return;
    
    // If mode has been changed...
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSModeWillChange" object:nil userInfo: [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInteger:newMode] forKey:@"mode"]];

    _currentMode = newMode;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RSModeDidChange" object:nil userInfo:nil];
}

- (BOOL)handleKeyDown:(NSEvent *)event;
{
    NSString *chars = [event charactersIgnoringModifiers];
    
    if (![chars length] || ([event modifierFlags] & (NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask)))
        return NO;
    
    unichar theChar = [chars characterAtIndex:0];
    
    NSUInteger newMode = modeFromChar(theChar);
    if (!newMode)
	return NO;
    
    // Don't change the mode if the mouse is dragging, but still return YES to signify we handled the keyDown event.
    if ([self mouseDragging])
	return YES;
    
    _lastKeyMode = newMode;
    [self setMode:newMode];
    
    return YES;
}

- (BOOL)handleKeyUp:(NSEvent *)event;
{
    NSString *chars = [event charactersIgnoringModifiers];
    
    if (![chars length])
        return NO;
    
    unichar theChar = [chars characterAtIndex:0];
    
    NSUInteger endingMode = modeFromChar(theChar);
    if (!endingMode)
	return NO;
    
    // Only switch back to modify mode (really, the _lastClickedMode) if you released the hotkey that was most recently pressed (_lastKeyMode).  Otherwise, the user pressed the second hotkey before releasing the first, and wants to stay in the second mode when releasing that first key.
    if (_lastKeyMode == endingMode)
	_lastKeyMode = _lastClickedMode;
    
    [self setMode:_lastKeyMode];
    return YES;
}

- (void)registerClick:(NSUInteger)mode {
    
    _lastClickedMode = mode;
    
    // update if necessary
    [self setMode:mode];
    
    // tell RSGraphView and Inspector:
    [[NSNotificationCenter defaultCenter] 
     postNotificationName:@"RSToolbarClicked" object:nil];
}



- (BOOL)toolHotKeyIsDown;
{
    return NO;  //! for now
}
- (void)toolWasUsed:(NSUInteger)mode;
{
    // "normal toolbar behavior" means retaining the tool mode until user chooses a different one
    // if normal behavior is turned on, this method does nothing.
    if( ![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"UseStickyTools"] ) {
	// Not using sticky tools means: go back to modify mode after a tool is used once.
	// But don't do it if the user is using hotkeys to stay in a tool mode:
	if( ![self toolHotKeyIsDown] ) {
	    [self registerClick:RS_modify];
	}
    }
}




///////////////////////////////////
#pragma mark -
#pragma mark Non-tool convenience accessors
///////////////////////////////////

- (BOOL)mouseDragging {
    return _mouseDragging;
}
- (void)setMouseDragging:(BOOL)flag {
    _mouseDragging = flag;
}

@synthesize globalViewMouseMovedPoint = _globalViewMouseMovedPoint;

- (BOOL)commandKeyIsDown;
{
    if (_modifierFlags & NSCommandKeyMask) // apple key is down
	return YES;
    return NO;
}
- (BOOL)optionKeyIsDown;
{
    if (_modifierFlags & NSAlternateKeyMask)
	return YES;
    return NO;
}
- (void)resetFlags;
{
    _modifierFlags = 0;
}




///////////
#pragma mark -
#pragma mark Utility methods
///////////

+ (RSTool *)toolForMode:(NSUInteger)mode withView:(RSGraphView *)view;
{
    if (mode == RS_modify) {
	return [[[RSModifyTool alloc] initWithView:view] autorelease];
    }
    else if (mode == RS_draw) {
	return [[[RSDrawTool alloc] initWithView:view] autorelease];
    }
    else if (mode == RS_fill) {
	return [[[RSFillTool alloc] initWithView:view] autorelease];
    }
    else if (mode == RS_text) {
	return [[[RSTextTool alloc] initWithView:view] autorelease];
    }
    
    OBASSERT_NOT_REACHED("Unsupported tool mode");
    return nil;
}



@end
