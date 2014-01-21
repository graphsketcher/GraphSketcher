// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/ButtonRibbonCell.h 200244 2013-12-10 00:11:55Z correia $

#import <AppKit/NSButtonCell.h>

extern const CGFloat ButtonRibbonCellCellHeight;

typedef enum {
    ButtonRibbonCellFull, // default
    ButtonRibbonCellLeft,
    ButtonRibbonCellMiddle,
    ButtonRibbonCellRight,
} ButtonRibbonCellPosition;

@interface ButtonRibbonCell : NSButtonCell
{
    ButtonRibbonCellPosition _position;
    
    // NSCell's masks for this are bizarre. Also it seems like NSMatrix resets them or something.  We just want two behaviors; radio matrix & press button.
    BOOL _pressButton;
}

- (ButtonRibbonCellPosition)position;
- (void)setPosition:(ButtonRibbonCellPosition)position;

- (BOOL)pressButton;
- (void)setPressButton:(BOOL)pressButton;

@end
