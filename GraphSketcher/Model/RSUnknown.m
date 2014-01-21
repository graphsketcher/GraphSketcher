// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSUnknown.m 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSLine.h>
#import <OmniQuartz/OQColor.h>

#import <OmniFoundation/OFPreference.h>
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>
#endif

@implementation RSUnknown

//////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
//////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
// does not support zone
{
    RSUnknown *copy;
    copy = [[RSUnknown alloc] initWithIdentifier:nil color:_color width:_width position:_position 
				      label:_label dash:_dash shape:_shape connectMethod:_connect];
    return copy;
}


- (id)init;
{
    RSDataPoint p = RSDataPointMake(0, 0);
    CGFloat width = 6;
    RSTextLabel *label = nil;
    
    // use defaults:
    OQColor *color = [OQColor colorForPreferenceKey:@"DefaultLineColor"];
    width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"];
    NSInteger dash = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultDashStyle"];
    NSInteger shape = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultVertexShape"];
    RSConnectType connect = connectMethodFromName([[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:@"DefaultConnectMethod"]);
    
    return [self initWithIdentifier:nil color:color width:width position:p label:label dash:dash shape:shape
		 connectMethod:connect];
}

// DESIGNATED INITIALIZER
- (id)initWithIdentifier:(NSString *)identifier color:(OQColor *)color width:(CGFloat)width position:(RSDataPoint)p label:(RSTextLabel *)label dash:(NSInteger)dash shape:(NSInteger)shape connectMethod:(RSConnectType)connect;
{
    if (!(self = [super initWithoutIdentifier]))
        return nil;
    
    _identifier = nil;
    
    _color = [color retain];
    _width = width;
    _position = p;
    _label = [label retain];
    _dash = dash;
    _shape = shape;
    _connect = connect;
    
    Log2(@"RSUnknown initialized.");
    return self;
}

- (void)dealloc
{
    Log2(@"An RSUnknown is being deallocated.");
    
    [_color release];
    [_label release];
    
    [super dealloc];
}



///////////////////////////////////////////////////
#pragma mark -
#pragma mark Accessor methods
///////////////////////////////////////////////////
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
- (BOOL)hasWidth;
{
    return YES;
}
- (RSDataPoint)position {
    return _position;
}
- (void)setPosition:(RSDataPoint)p {
    _position = p;
}
- (void)setPositionx:(data_p)val {
    _position.x = val;
}
- (void)setPositiony:(data_p)val {
    _position.y = val;
}
- (BOOL)isLabelable;
{
    return NO;
}
//! Does RSUnknown ever have a label?
- (RSTextLabel *)label {
    return _label;
}
- (void)setLabel:(RSTextLabel *)label {
    [_label release];
    _label = [label retain];
}
- (NSInteger)dash {
    return _dash;
}
- (void)setDash:(NSInteger)dash {
    _dash = dash;
}
- (BOOL)hasDash;
{
    return YES;
}
- (NSInteger)shape {
    return _shape;
}
- (void)setShape:(NSInteger)shape {
    _shape = shape;
}
- (BOOL)hasShape;
{
    return YES;
}
- (BOOL)canHaveArrows;
{
    return NO;
}
- (BOOL)hasUserCoords;
{
    return NO;
}

- (RSConnectType)connectMethod {
    return _connect;
}
- (void)setConnectMethod:(RSConnectType)val{
    _connect = val;
}
- (BOOL)hasConnectMethod;
{
    return YES;
}



@end
