// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSMode primarily keeps track of what tool mode we are in or should be in, based on keys down and clicks on the toolbar.

#import <OmniFoundation/OFObject.h>

@class RSTool, RSGraphView;

// define tool modes:
#define RS_none 0
#define RS_modify 1
#define RS_draw 2
#define RS_fill 3
#define RS_text 4
#define RS_NUMBER_OF_TOOLS 4


// hot keys
#define RS_HOTKEY_DRAW 'd'
#define RS_HOTKEY_FILL 'f'
#define RS_HOTKEY_TEXT 't'



@interface RSMode : OFObject
{
    NSUInteger _currentMode;
    NSUInteger _lastKeyMode;
    NSUInteger _lastClickedMode;
    
    NSUInteger _modifierFlags;  // last-notified modifier flags
    BOOL _mouseDragging;
    NSPoint _globalViewMouseMovedPoint;
}

// Get the one shared mode controller
+ (RSMode *)sharedModeController;


// Notifications
- (void)RSFlagsChangedNotification:(NSNotification *)note;


// Tool mode controller
- (NSUInteger)mode;
- (BOOL)handleKeyDown:(NSEvent *)event;
- (BOOL)handleKeyUp:(NSEvent *)event;
- (void)registerClick:(NSUInteger)mode;

- (void)toolWasUsed:(NSUInteger)mode;


// Non-tool convenience accessors
- (BOOL)mouseDragging;
- (void)setMouseDragging:(BOOL)flag;
@property NSPoint globalViewMouseMovedPoint;
- (BOOL)commandKeyIsDown;
- (BOOL)optionKeyIsDown;
- (void)resetFlags;


// Utility methods
+ (RSTool *)toolForMode:(NSUInteger)mode withView:(RSGraphView *)view;


@end
