// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/ArrowsInspectorSlice.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniUI/OUIInspectorSlice.h>

@class OUIInspectorButton;

@interface ArrowsInspectorSlice : OUIInspectorSlice
{
@private
    OUIInspectorButton *_minArrowEnabledButton;
    OUIInspectorButton *_maxArrowEnabledButton;
}

@property(retain) IBOutlet OUIInspectorButton *minArrowEnabledButton;
@property(retain) IBOutlet OUIInspectorButton *maxArrowEnabledButton;

- (void)changeArrow:(id)sender;

@end
