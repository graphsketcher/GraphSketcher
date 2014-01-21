// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSLogger.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniFoundation/OFObject.h>

//#import "RSGraphElement.h"

// Note:  RSLogger was built to record quantitative data during usability testing.
// It did not prove to be very useful, but could theoretically be used in some sort
// of "how to improve your usage of graph sketcher" feature.
//
// Beware:  Besides the commented out code below, 
// some of the code in other classes that "calls back" to RSLogger with
// notifications, and thus is necessary for it to work properly, has also been disabled.
// At the very least, mouseClicks and menuAccesses are not functional.
//
// In usability testing, "steps" turned out to be really the only interesting measure.


#if 0 && defined(DEBUG_robin)
#define DEBUG_DATA_LOGGER(format, ...) NSLog( format, ## __VA_ARGS__ )
#else
#define DEBUG_DATA_LOGGER(format, ...)
#endif


@interface RSLogger : OFObject
{
    int _mouseClicks;
    int _flagsChanged;
    int _menuAccesses;
    int _undos;
    int _steps;
    
    NSMutableString *_results;
    NSString *_filePath;
}

+ (RSLogger *)sharedLogger;

// Notifications
- (void)RSLogFlagsChangedNotification:(NSNotification *)note;
- (void)RSLogMouseClickNotification:(NSNotification *)note;
- (void)RSLogMenuAccessNotification:(NSNotification *)note;
- (void)RSLogUndoNotification:(NSNotification *)note;
- (void)RSLogStepNotification:(NSNotification *)note;
- (void)RSIAmSelectionObjectNotification:(NSNotification *)note;

// Action methods
- (void)windowClosed;
- (void)saveData;


@end
