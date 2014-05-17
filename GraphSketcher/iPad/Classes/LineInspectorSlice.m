// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "LineInspectorSlice.h"

#import <OmniUI/OUISegmentedControl.h>
#import <OmniUI/OUISegmentedControlButton.h>
#import <OmniUI/OUIInspectorOptionWheel.h>
#import <OmniUI/OUIInspectorOptionWheelItem.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import "InspectorSupport.h"

RCS_ID("$Header$");

@interface LineInspectorSlice (/*Private*/)
@end

@implementation LineInspectorSlice

- (void)dealloc;
{
    [_connectionTypeSegmentedControl release];
    [_lineDashOptionWheel release];
    [super dealloc];
}

@synthesize connectionTypeSegmentedControl = _connectionTypeSegmentedControl;
@synthesize lineDashOptionWheel = _lineDashOptionWheel;

- (IBAction)changeConnectionType:(id)sender;
{
    NSNumber *connectionType = _connectionTypeSegmentedControl.selectedSegment.representedObject;
    OBASSERT(connectionType); // why are you calling the action?

    RSGraphEditor *editor = self.editor;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSGraphElement *element in self.appropriateObjectsForInspection) {
            // <bug://bugs/59359> (On the Mac, changing the connection/dash type of line can change the selection)
            // This returns a new selection and we are ignoring it
            /*RSGraphElement *newSelection = */[editor setConnectMethod:[connectionType intValue] forElement:element];
//            if (newSelection && [self.inspector.delegate respondsToSelector:@selector(inspector:wantsSelectionChanged:)]) {
//                [self.inspector.delegate performSelector:@selector(inspector:wantsSelectionChanged:) withObject:self withObject:newSelection];
//            }
        }
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (IBAction)changeLineDash:(id)option;
{
    NSNumber *dashNumber = _lineDashOptionWheel.selectedValue;
    OBASSERT(dashNumber); // why are you calling the action?
    
    RSGraphEditor *editor = self.editor;

    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSGraphElement *element in self.appropriateObjectsForInspection)
            // <bug://bugs/59359> (On the Mac, changing the connection/dash type of line can change the selection)
            // This returns a new selection and we are ignoring it
            [editor setDash:[dashNumber intValue] forElement:element];
    }
    [self.inspector didEndChangingInspectedObjects];
}

#pragma mark -
#pragma mark OUIInspectorSlice subclassed

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSGraphElement class]])
        return NO;
    return [(RSGraphElement *)object hasConnectMethod];
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    NSNumber *singleConnection = [self singleSelectedValueForIntegerSelector:@selector(connectMethod)];
    _connectionTypeSegmentedControl.selectedSegment = [_connectionTypeSegmentedControl segmentWithRepresentedObject:singleConnection];
    
    NSNumber *dashType = [self singleSelectedValueForIntegerSelector:@selector(dash)];
    if (dashType)
        [_lineDashOptionWheel setSelectedValue:dashType animated:(reason == OUIInspectorUpdateReasonObjectsEdited)];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    [_connectionTypeSegmentedControl addSegmentWithImageNamed:@"ConnectStraight.png" representedObject:[NSNumber numberWithInt:RSConnectStraight]];
    [_connectionTypeSegmentedControl addSegmentWithImageNamed:@"ConnectCurved.png" representedObject:[NSNumber numberWithInt:RSConnectCurved]];
    
    //<bug://bugs/59826> (Temporarily remove best-fit and no-line line type options)
//    [_connectionTypeSegmentedControl addSegmentWithImageNamed:@"ConnectLinearRegression.png" representedObject:[NSNumber numberWithInt:RSConnectLinearRegression]];
//    [_connectionTypeSegmentedControl addSegmentWithImageNamed:@"ConnectNone.png" representedObject:[NSNumber numberWithInt:RSConnectNone]];
    
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDashSolid.png" value:[NSNumber numberWithInt:1]];
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDash2.png" value:[NSNumber numberWithInt:2]];
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDash3.png" value:[NSNumber numberWithInt:3]];
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDash4.png" value:[NSNumber numberWithInt:4]];
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDash5.png" value:[NSNumber numberWithInt:5]];
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDash6.png" value:[NSNumber numberWithInt:6]];
    
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDashRailroad.png" value:[NSNumber numberWithInt:RS_RAILROAD_DASH]];
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDashArrows.png" value:[NSNumber numberWithInt:RS_ARROWS_DASH]];
    [_lineDashOptionWheel addItemWithImageNamed:@"LineDashReverseArrows.png" value:[NSNumber numberWithInt:RS_REVERSE_ARROWS_DASH]];

    // Without this, our first call to -setSelectedValue:animated: on OUIInspectorOptionWheel will do nothing. 
    [self.view layoutIfNeeded];
}

@end
