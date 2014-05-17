// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSLogger.h"


@implementation RSLogger

+ (RSLogger *)sharedLogger
{
    static RSLogger *_sharedLogger = nil;
    
    if (!_sharedLogger) {
        _sharedLogger = [[RSLogger allocWithZone:[self zone]] init];
    }
    return _sharedLogger;
}

// DESIGNATED INITIALIZER
- (id)init {
    if (!(self = [super init]))
        return nil;
    
    // default starting values
    _mouseClicks = 0;
    _flagsChanged = 0;
    _menuAccesses = 0;
    _undos = 0;
    _steps = 0;
    
    _filePath = [[[NSString stringWithFormat:@"~/Desktop/GSLog %@.txt",[[NSDate date] description]] 
                  stringByExpandingTildeInPath] retain];
    
    _results = [[NSMutableString stringWithFormat:@"Launched on %@\nend time\tclicks\tflags\tmenus\tundos\tsteps\n",
                 [[NSDate date] description]] retain];
    
    // Register to receive notifications when modifier keys are changed
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(RSLogFlagsChangedNotification:) name:@"RSLogFlagsChanged" object:nil];
    [nc addObserver:self selector:@selector(RSLogMouseClickNotification:) name:@"RSLogMouseClick" object:nil];
    [nc addObserver:self selector:@selector(RSLogMenuAccessNotification:) name:@"RSLogMenuAccess" object:nil];
    [nc addObserver:self selector:@selector(RSLogUndoNotification:) name:@"RSLogUndo" object:nil];
    [nc addObserver:self selector:@selector(RSLogStepNotification:) name:@"RSLogStep" object:nil];
    [nc addObserver:self selector:@selector(RSIAmSelectionObjectNotification:) name:@"RSIAmSelectionObject" object:nil];
    
    DEBUG_DATA_LOGGER(@"RSLogger initialized.");
    
    return self;
}


///////////////////////////////////
// Notifications
///////////////////////////////////
- (void)RSLogFlagsChangedNotification:(NSNotification *)note
{
    DEBUG_DATA_LOGGER(@"RSLogger received notification: %@", note);
    _flagsChanged++;
}
- (void)RSLogMouseClickNotification:(NSNotification *)note
{
    DEBUG_DATA_LOGGER(@"RSLogger received notification: %@", note);
    _mouseClicks++;
}
- (void)RSLogMenuAccessNotification:(NSNotification *)note
{
    DEBUG_DATA_LOGGER(@"RSLogger received notification: %@", note);
    _menuAccesses++;
}
- (void)RSLogUndoNotification:(NSNotification *)note
{
    DEBUG_DATA_LOGGER(@"RSLogger received notification: %@", note);
    _undos++;
}
- (void)RSLogStepNotification:(NSNotification *)note
{
    DEBUG_DATA_LOGGER(@"RSLogger received notification: %@", note);
    _steps++;
}

- (void)ApplicationShouldTerminate:(NSNotification *)note
{
    DEBUG_DATA_LOGGER(@"RSLogger received notification: %@", note);
    [self windowClosed];
    [self saveData];
}

- (void)RSIAmSelectionObjectNotification:(NSNotification *)note
{
    DEBUG_DATA_LOGGER(@"RSLogger received notification: %@", note);
    // Every time windows are opened or closed, start a new cycle and 
    // save the full results to disk
    [self windowClosed];
    [self saveData];
}




///////////////////////////////////
// Action methods
///////////////////////////////////
- (void)windowClosed {
	//[_results appendFormat:@"clicks:\t%d\nflags:\t%d\nmenus:\t%d\nundos:\t%d\n",
	//						_mouseClicks,_flagsChanged,_menuAccesses,_undos];
	
	/*usability testing is over
	if ( _mouseClicks || _flagsChanged || _menuAccesses || _undos )
		[_results appendFormat:@"%@\t%d\t%d\t%d\t%d\t%d\n",
							[[NSDate date] description],	// current date
							_mouseClicks,_flagsChanged,_menuAccesses,_undos,_steps];
	*/
    // then reset counters
    _mouseClicks = 0;
    _flagsChanged = 0;
    _menuAccesses = 0;
    _undos = 0;
    _steps = 0;
}

- (void)saveData {
    //usability testing is over!//[_results writeToFile:_filePath atomically:YES];
}


// remember dealloc!
- (void)dealloc
{
    DEBUG_DATA_LOGGER(@"An RSLogger is being deallocated.");
    
    //[self saveData];
    
    // unregister observer from notification center
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
    
    [_filePath release];
    [_results release];
    
    [super dealloc];
}


@end
