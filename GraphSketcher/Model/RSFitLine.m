// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSFitLine.h>

#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <OmniQuartz/OQColor.h>

#import <OmniFoundation/OFPreference.h>
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>
#endif

#define RS_VERTICAL_LINE_DATA_SLOPE 1e300

@implementation RSFitLine


///////////////////////////////////////////////
#pragma mark -
#pragma mark Class methods for calculating the best-fit line parameters
//////////////////

// calculate the slope _m and intercept _b
- (void)updateParameters;
{
    data_p sumx = 0, sumy = 0, sumxy = 0, sumxx = 0;
    data_p sumyy = 0, sx2 = 0, sy2 = 0;
    _r2 = 0;
    
    data_p n = (data_p)[_data count];
    if ( n < 2 ) {	// too small to be meaningful
	_m = 0;
	_b = 1;
	return;
    }
    
    for (RSVertex *V in [_data elements])
    {
	RSDataPoint p = [V position];
	sumx += p.x;
	sumy += p.y;
	sumxy += p.x*p.y;
	sumxx += p.x*p.x;
	sumyy += p.y*p.y;
    }
    
    // Formula from Kirby's sheet:
    // _m = (n*sumxy - sumx*sumy) / (n*sumxx - sumx*sumx);
    data_p denom = (n*sumxx - sumx*sumx);
    if ( denom != 0 )
	_m = (n*sumxy - sumx*sumy) / denom;
    else
	_m = RS_VERTICAL_LINE_DATA_SLOPE;
    
    // b = ybar - m*xbar :  (and n is guaranteed != 0)
    _b = sumy/n - _m*(sumx/n);
    
    //////
    // Now, to find R^2 we follow Prof De Veaux's advice:
    // Once you have the slope (b1) or m as you call it and the intercept b0 (or b),
    // then  r = b1 (sx/sy)          (s means standard deviation)
    // so r2 = b1^2 (sx^2)/(sy^2)
    // sx^2 = (sum(x^2) - (sum x)^2/n)/(n-1)
    // and
    // sy^2 = (sum(y^2) - (sum y)^2/n)/(n-1)
    
    if( n > 1 ) {
	sx2 = (sumxx - sumx*sumx/n)/(n-1);
	sy2 = (sumyy - sumy*sumy/n)/(n-1);
	if( sy2 != 0 )
	    _r2 = _m*_m * sx2/sy2;
    }
    
    // Compensate for rounding errors to improve the equation string
    //if (nearlyEqualFloats(_m, 0))  _m = 0;
    if (nearlyEqualDataValues(_b, 0))  _b = 0;
    if (nearlyEqualDataValues(_r2, 0))  _r2 = 0;
    if (nearlyEqualDataValues(_r2, 1))  _r2 = 1;
    
    //NSLog(@"FitLine: y = %.12fx + %.12f", _m, _b);
}

// Always adjusts the y-coords of the endpoints;
//   only adjusts the x-coords if the new min and max are more extreme (never mind)
// Make sure to do this only after parameters have been updated!
- (void)updateEndpoints;
{
    /*
     NSEnumerator *E;
     RSVertex *V;
     data_p min, max;	// min and max X-COORDS
     data_p cur;
     //CGPoint p1, p2;
     
     if ( [_data isEmpty] )  return;	// definitely don't try to go through the list
     
     E = [[_data elements] objectEnumerator];
     V = [E nextObject];
     min = max = [V positionx];
     while ( V = [E nextObject] ) {
     cur = [V positionx];
     if ( cur < min )  min = cur;
     else if ( cur > max)  max = cur;
     }
     // now min and max are the new min and max x-coords
     
     // possibly update x-coords:
     if ( min < [_v1 positionx] )  [_v1 setPositionx:min];
     if ( max < [_v2 positionx] )  [_v2 setPositionx:max];
     */
    
    // if the line gets too short, reset the endpoints
    //!someday

    // but always update y-coords
    
    // if a vertical line
    if (_m >= RS_VERTICAL_LINE_DATA_SLOPE) {
	data_p x = [[_data firstElement] position].x;
	[[self startVertex] setPosition:RSDataPointMake(x, [[self graph] yMin])];
	[[self endVertex] setPosition:RSDataPointMake(x, [[self graph] yMax])];
	return;
    }
    
    // if it used to be a vertical line
    if (nearlyEqualDataValues([[self startVertex] position].x, [[self endVertex] position].x)) {
	[self resetEndpoints];
	return;
    }
    
    // the normal case
    [[self startVertex] setPositiony:(_m*[[self startVertex] position].x + _b)];	// y=mx+b
    [[self endVertex] setPositiony:(_m*[[self endVertex] position].x + _b)];
    
}

// Resets endpoints to min and max x-coords of data
// Make sure to do this only after parameters have been updated!
- (void)resetEndpoints;
{
    NSEnumerator *E;
    RSVertex *V;
    data_p min, max;	// min and max X-COORDS
    data_p cur;
    //CGPoint p1, p2;
    
    if ( [_data isEmpty] )  return;	// definitely don't try to go through the list
    
    E = [[_data elements] objectEnumerator];
    V = [E nextObject];
    min = max = [V position].x;
    while ((V = [E nextObject])) {
	cur = [V position].x;
	if ( cur < min )  min = cur;
	else if ( cur > max)  max = cur;
    }
    // now min and max are the true min and max x-coords
    
    // Make a vertical line if all x-coords are the same
    if (nearlyEqualDataValues(min, max)) {
	[[self startVertex] setPosition:RSDataPointMake(min, [[self graph] yMin])];
	[[self endVertex] setPosition:RSDataPointMake(min, [[self graph] yMax])];
    }
    else {
	[[self startVertex] setPositionx:min];
	[[self startVertex] setPositiony:(_m*min + _b)];	// y=mx+b
	[[self endVertex] setPositionx:max];
	[[self endVertex] setPositiony:(_m*max + _b)];	// y=mx+b once more
    }
    
    //DEBUG_RS(@"FitLine endpoints: %@, %@", NSStringFromPoint([[self startVertex] position]), NSStringFromPoint([[self endVertex] position]));
}




//////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
////////////////

// Not sure if FitLines should be allowed to be copied
- (id)copyWithZone:(NSZone *)zone
// does not support zone
{
    RSFitLine *copy = [[RSFitLine alloc] initWithGraph:_graph identifier:nil data:[[_data copy] autorelease]];
    [copy setColor:[[[self color] copy] autorelease]];
    [copy setWidth:[self width]];
    [copy setSlide:[self slide]];
    [copy setLabelDistance:[self labelDistance]];
    
    return copy;
}


// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier data:(RSGroup *)data;
{
    // use defaults
    OQColor *color = [OQColor colorForPreferenceKey:@"DefaultLineColor"];
    CGFloat width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"];
    CGFloat dash = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultDashStyle"];
    CGFloat slide = 0.5f;
    CGFloat labelDistance = 2.0f;
    
    if (!(self = [super initWithGraph:graph identifier:identifier color:color width:width dash:dash slide:slide labelDistance:labelDistance]))
	return nil;
    
    _data = [data retain];
    _needsRecompute = NO;
    
    [_data addParent:self];	// add self as a parent to all data points
    
    [self updateParameters];
    [self resetEndpoints];
    
    Log1(@"RSFitLine initialized.");
    
    return self;
}

- (void)invalidate;
{
    for (RSVertex *V in [[_data elements] reverseObjectEnumerator]) {
        if ([[V parents] containsObjectIdenticalTo:self]) {
            [V removeParent:self];
        }
        [_data removeElement:V];
    }

    [_data invalidate];
    [_data release];
    _data = nil;

    [super invalidate];
}

- (void)dealloc
{
    [self invalidate];
    
    [super dealloc];
}


//////////////////////////////////////////////////
#pragma mark -
#pragma mark RSLine subclass
//////////////////
+ (BOOL)supportsConnectMethod:(RSConnectType)connectMethod;
{
    return (connectMethod == RSConnectLinearRegression);
}
- (RSConnectType)connectMethod {
    return RSConnectLinearRegression;
}

- (BOOL)isEmpty {
    return [_data isEmpty];
}
- (BOOL)isTooSmall {
    return ([_data count] < 2 || [self isVertex]);
}
- (BOOL)isCurved;
{
    return NO;
}

- (NSArray *)children;
// defined as "every object that should have this line as a parent"
{
    NSMutableArray *A = [NSMutableArray arrayWithArray:[[self data] elements]];
    [A addObject:[self startVertex]];
    [A addObject:[self endVertex]];
    
    return A;
}

- (BOOL)containsVertex:(RSVertex *)V;
{
    if ([super containsVertex:V])
	return YES;
    
    return [_data containsElement:V];
}

- (BOOL)dropVertex:(RSVertex *)V;
{
    OBPRECONDITION([[V parents] containsObject:self]);
    
    // Start and end vertices can't be dropped.  If we allow that it leads to bad interactions with RSGraph's removeVertex:.
    if ([self startVertex] == V) {
        //[self setStartVertex:[self endVertex]];
        return NO;
    }
    else if ([self endVertex] == V) {
        //[self setEndVertex:[self startVertex]];
        return NO;
    }
    
    // Otherwise, V is a data vertex.
    [V removeParent:self];
    
    NSUInteger index = [[_data elements] indexOfObjectIdenticalTo:V];
    if (index == NSNotFound) {
        OBASSERT_NOT_REACHED("Vertex could not be removed from the line because the vertex was not found.  It shouldn't have had this line as parent.");
        return NO;
    }
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] insertVertex:V atIndex:index];
    
    [_data removeElement:V];
    
    [self setNeedsRecompute];
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
    return YES;
}

- (BOOL)insertVertex:(RSVertex *)V atIndex:(NSUInteger)index;
{
    BOOL result = [_data addElement:V atIndex:index];
    if (result) {
        [[[_graph undoManager] prepareWithInvocationTarget:self] dropVertex:V];
        
        [V addParent:self];
    }
    
    [self setNeedsRecompute];
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
    return result;
}


//////////////////////////////////////////////////
#pragma mark -
#pragma mark Line accessors
//////////////////


- (RSGroup *)data;
{
    return _data;
}

- (RSGroup *)groupWithData;
{
    RSGroup *group = [RSGroup groupWithGraph:_graph];
    [group addElement:self];
    [group addElement:_data];
    
    return group;
}


//////////////////////////////////////////////////
#pragma mark -
#pragma mark Recomputing best-fit line parameters
////////

- (void)setNeedsRecompute {
    _needsRecompute = YES;
}

- (BOOL)recomputeNow {
    // Recompute parameters only if it has been requested previously by sending [recompute]
    
    if (!_needsRecompute) {
	return NO;
    }
    
    [self updateParameters];
    [self updateEndpoints];
    [self updateLabel];
    
    _needsRecompute = NO;
    return YES;
}

+ (NSNumberFormatter *)rSquaredNumberFormatter;
{
    static NSNumberFormatter *_rSquaredNumberFormatter = nil;
    
    if( !_rSquaredNumberFormatter ) {
        _rSquaredNumberFormatter = [[NSNumberFormatter alloc] init];
        [_rSquaredNumberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        
        [_rSquaredNumberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [_rSquaredNumberFormatter setLenient:YES];
        [_rSquaredNumberFormatter setUsesSignificantDigits:YES];
        [_rSquaredNumberFormatter setMaximumSignificantDigits:4];
        [_rSquaredNumberFormatter setZeroSymbol:@"0"];
    }
    
    return _rSquaredNumberFormatter;
}

- (NSString *)equationString;
{
    NSString *equation = [super equationString];
    
    if (_r2) {
        NSString *rSquaredValue = [[RSFitLine rSquaredNumberFormatter] stringFromNumber:[NSNumber numberWithDouble:_r2]];
        return [NSString stringWithFormat:@"%@    R%C = %@", equation, (unichar)0x00B2, rSquaredValue];
    }
    else {
        return equation;
    }
}

- (void)updateLabel;
{
    if ( !_label )  return;	// no point in continuing if there's no label
    
    [_label setText:[self equationString]];
}

- (NSString *)infoString;
{
    NSString *format = NSLocalizedStringFromTableInBundle(@"Best-fit line:   %1$@", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar description of a best-fit line");
    return [NSString stringWithFormat:format, [self equationString]];
}





@end
