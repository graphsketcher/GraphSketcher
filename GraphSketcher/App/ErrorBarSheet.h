// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/ErrorBarSheet.h 200244 2013-12-10 00:11:55Z correia $

#import <Cocoa/Cocoa.h>

#import <GraphSketcherModel/RSNumber.h>


@interface ErrorBarSheet : NSWindowController {
    IBOutlet NSTextField *posOffsetField;
    IBOutlet NSTextField *negOffsetField;
}

@property (nonatomic,readonly) data_p posOffset;
@property (nonatomic,readonly) data_p negOffset;

- (IBAction)helpButton:(id)sender;
- (IBAction)cancelButton:(id)sender;
- (IBAction)okButton:(id)sender;

@end
