// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGrid.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniFoundation/OFObject.h>

#import <GraphSketcherModel/RSGraphElement.h>

@class OQColor;

@interface RSGrid : OFObject
{
    int _orientation;  // horizontal or vertical
    data_p _spacing;  // space between subsequent grid lines
    CGFloat _width;  // width of grid lines
    BOOL _extendsPastAxis;  // determines whether the grid extends past the graph rectangle
    
    OQColor *_color;  // color of grid lines
    BOOL _dotted;  // whether to display as dotted lines
    
    BOOL _displayGrid;  // whether or not to draw the grid
}

// New initialization
- (id)initWithOrientation:(int)orientation spacing:(data_p)spacing;
- (id)initWithOrientation:(int)orientation;


// Accessor methods:
- (OQColor *)color;
- (void)setColor:(OQColor *)color;
- (CGFloat)width;
- (void)setWidth:(CGFloat)width;

@property BOOL dotted;

- (int)orientation;
- (void)setOrientation:(int)orientation;
- (data_p)spacing;
- (void)setSpacing:(data_p)spacing;
- (BOOL)extendsPastAxis;
- (void)setExtendsPastAxis:(BOOL)flag;

- (BOOL)displayGrid;
- (void)setDisplayGrid:(BOOL)flag;

- (BOOL)isPartOfAxis;
- (BOOL)isMovable;


@end
