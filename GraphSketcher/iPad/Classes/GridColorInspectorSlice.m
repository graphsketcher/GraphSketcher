// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/GridColorInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "GridColorInspectorSlice.h"

#import "InspectorSupport.h"
#import <OmniUI/OUIColorSwatchPicker.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/GridColorInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $");

@implementation GridColorInspectorSlice

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    return [object isKindOfClass:[RSGraph class]];
}

- (OQColor *)colorForObject:(id)object;
{
    RSGraph *graph = object;
    return graph.gridColor;
}

- (void)setColor:(OQColor *)color forObject:(id)object;
{
    RSGraph *graph = object;
    graph.gridColor = color;
}

- (void)loadColorSwatchesForObject:(id)object;
{
    self.swatchPicker.palettePreferenceKey = @"LineColorPalette";
}

@end
