// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/PositionInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "PositionInspectorSlice.h"

#import <OmniUI/OUIInspectorTextWell.h>
#import "InspectorSupport.h"
#import <GraphSketcherModel/RSGroup.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/PositionInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $");

@implementation PositionInspectorSlice

- (void)dealloc;
{
    [_xPositionTextWell release];
    [_yPositionTextWell release];
    [super dealloc];
}

@synthesize xPositionTextWell = _xPositionTextWell;
@synthesize yPositionTextWell = _yPositionTextWell;

- (IBAction)changeX:(id)sender;
{
    data_p x = [_xPositionTextWell.text doubleValue];
    RSGraphEditor *editor = self.editor;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        RSGroup *group = [[RSGroup alloc] initWithGraph:self.editor.graph byCopyingArray:self.appropriateObjectsForInspection];
        [editor changeX:x forElement:group];
        [group release];
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (IBAction)changeY:(id)sender;
{
    data_p y = [_yPositionTextWell.text doubleValue];
    RSGraphEditor *editor = self.editor;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        RSGroup *group = [[RSGroup alloc] initWithGraph:self.editor.graph byCopyingArray:self.appropriateObjectsForInspection];
        [editor changeY:y forElement:group];
        [group release];
    }
    [self.inspector didEndChangingInspectedObjects];
}

#pragma mark -
#pragma mark OUIInspectorSlice subclass

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSGraphElement class]])
        return NO;
    return [(RSGraphElement *)object hasUserCoords];
}
                                
- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    RSGroup *group = [[RSGroup alloc] initWithGraph:self.editor.graph byCopyingArray:self.appropriateObjectsForInspection];
    RSDataPoint position = [group position];
    [group release];
    
    _xPositionTextWell.text = [NSString stringWithFormat:@"%g", position.x];
    _yPositionTextWell.text = [NSString stringWithFormat:@"%g", position.y];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    CGFloat fontSize = [OUIInspectorTextWell fontSize];
    _xPositionTextWell.font = [UIFont boldSystemFontOfSize:fontSize];
    _xPositionTextWell.label = NSLocalizedStringFromTableInBundle(@"x: %@", @"Inspector", OMNI_BUNDLE, @"x position label field format string");
    _xPositionTextWell.labelFont = [OUIInspectorTextWell italicFormatFont];
    _xPositionTextWell.cornerType = OUIInspectorWellCornerTypeLargeRadius;
    _xPositionTextWell.editable = YES;
    _xPositionTextWell.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    
    _yPositionTextWell.font = [UIFont boldSystemFontOfSize:fontSize];
    _yPositionTextWell.label = NSLocalizedStringFromTableInBundle(@"y: %@", @"Inspector", OMNI_BUNDLE, @"x position label field format string");
    _yPositionTextWell.labelFont = [OUIInspectorTextWell italicFormatFont];
    _yPositionTextWell.cornerType = OUIInspectorWellCornerTypeLargeRadius;
    _yPositionTextWell.editable = YES;
    _yPositionTextWell.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
}

@end
