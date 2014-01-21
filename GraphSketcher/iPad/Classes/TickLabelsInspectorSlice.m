// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/TickLabelsInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "TickLabelsInspectorSlice.h"

#import "InspectorSupport.h"
#import <OmniUI/OUIDrawing.h>

@implementation TickLabelsInspectorSlice

- (void)dealloc;
{
    [_headerLabel release];
    
    [super dealloc];
}

@synthesize headerLabel = _headerLabel;


#pragma mark -
#pragma mark OUIInspectorSlice subclass

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSAxis class]])
        return NO;
    return [(RSGraphElement *)object canHaveArrows];
}


#pragma mark -
#pragma mark UIViewController subclass

- (void)loadView;
{
    CGRect frame = CGRectMake(0, 0, 100, 21); // Width doesn't matter; we'll get width-resized as we get put in the stack.
    
    _headerLabel = [[UILabel alloc] initWithFrame:frame];
    _headerLabel.textAlignment = NSTextAlignmentCenter;
    _headerLabel.textColor = [OUIInspector labelTextColor];
    _headerLabel.font = [OUIInspector labelFont];
    
    _headerLabel.opaque = NO;
    _headerLabel.backgroundColor = [UIColor clearColor];
    
    self.view = _headerLabel;
}

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    _headerLabel.text = NSLocalizedStringFromTableInBundle(@"Tick Labels", @"Inspector", OMNI_BUNDLE, @"Header label on single-axis inspector.");
    OUISetShadowOnLabel(_headerLabel, OUIShadowTypeDarkContentOnLightBackground);
}

@end
