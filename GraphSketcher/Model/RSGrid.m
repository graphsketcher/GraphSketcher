// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSGrid.h>

#import <GraphSketcherModel/RSGraphElement.h>
#import <OmniQuartz/OQColor.h>

#import <OmniFoundation/OFPreference.h>
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>
#endif

@implementation RSGrid

//////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////////////////
+ (void)initialize
{
    OBINITIALIZE;
    [self setVersion:2];
}

// Designated initializer
- (id)initWithOrientation:(int)orientation spacing:(data_p)spacing
{
    if (!(self = [super init]))
        return nil;
    
    _orientation = orientation;
    _spacing = spacing;
    _width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultGridWidth"];
    
    // defaults
    _extendsPastAxis = NO;
    if( _orientation == RS_ORIENTATION_HORIZONTAL )
	_displayGrid = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"DisplayHorizontalGrid"];
    else if( _orientation == RS_ORIENTATION_VERTICAL )
	_displayGrid = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"DisplayVerticalGrid"];
    
    _color = [[OQColor colorForPreferenceKey:@"DefaultGridColor"] retain];
    _dotted = NO;
    
    Log1(@"RSGrid initialized.");
    
    return self;
}

- (id)initWithOrientation:(int)orientation
{
    // defaults
    data_p spacing = 1;
    
    return [self initWithOrientation:orientation spacing:spacing];
}

- (id)init {
    // not allowed
    NSLog(@"ERROR: Not allowed to initialize an RSGrid without an orientation.");
    return nil;
}

- (void)dealloc
{
    Log1(@"An RSGrid is being deallocated.");
    
    [_color autorelease];
    
    [super dealloc];
}


///////////////////////////////////////////
#pragma mark -
#pragma mark Accessor methods
///////////////////////////////////////////
- (OQColor *)color {
    return _color;
}
- (void)setColor:(OQColor *)color {
    [_color autorelease];
    _color = [color retain];
}
- (CGFloat)width {
    return _width;
}
- (void)setWidth:(CGFloat)width {
    _width = width;
}

@synthesize dotted = _dotted;


- (int)orientation {
    return _orientation;
}
- (void)setOrientation:(int)orientation {
    _orientation = orientation;
}
- (data_p)spacing {
    return _spacing;
}
- (void)setSpacing:(data_p)value {
    _spacing = value;
}


- (BOOL)extendsPastAxis {
    return _extendsPastAxis;
}
- (void)setExtendsPastAxis:(BOOL)flag {
    _extendsPastAxis = flag;
}

- (BOOL)displayGrid {
    if( _width == 0 )  return NO;
    else  return _displayGrid;
}
- (void)setDisplayGrid:(BOOL)flag {
    _displayGrid = flag;
    if( _displayGrid == YES && _width == 0 ) {
	_width = 0.5f;
    }
}


- (BOOL)isPartOfAxis {
    return YES;
}
- (BOOL)isMovable {
    return NO;
}



@end
