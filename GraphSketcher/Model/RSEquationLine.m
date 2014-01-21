// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header$

#import <GraphSketcherModel/RSEquationLine.h>

#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSTextLabel.h>

#import <OmniQuartz/OQColor.h>
#import <OmniFoundation/OFPreference.h>


RSEquation RSEquationZero(void) {
    RSEquation eq = { .type=RSEquationTypeLinear, .a=0, .b=0, .c=0 };
    return eq;
}


@implementation RSEquationLine

//////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
////////////////

//- (id)copyWithZone:(NSZone *)zone
//// does not support zone
//{
//    RSFitLine *copy = [[RSFitLine alloc] initWithGraph:_graph identifier:nil data:[[_data copy] autorelease]];
//    [copy setColor:[[[self color] copy] autorelease]];
//    [copy setWidth:[self width]];
//    [copy setSlide:[self slide]];
//    [copy setLabelDistance:[self labelDistance]];
//    
//    return copy;
//}

- (id)init {
    OBRejectInvalidCall([self class], _cmd, @"Use initWithGraph:");
    return nil;
}

// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier equation:(RSEquation)equation;
{
    // use defaults
    OQColor *color = [OQColor colorForPreferenceKey:@"DefaultLineColor"];
    CGFloat width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"];
    CGFloat dash = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultDashStyle"];
    CGFloat slide = 0.5f;
    CGFloat labelDistance = 2.0f;
    
    if (!(self = [super initWithGraph:graph identifier:identifier color:color width:width dash:dash slide:slide labelDistance:labelDistance]))
	return nil;
    
    _equation = equation;
    
    [self updateEndpoints];
    
    return self;
}

- (void)invalidate;
{
    
    
    [super invalidate];
}

- (void)dealloc
{
    [self invalidate];
    
    [super dealloc];
}



#pragma mark -
#pragma mark Class methods

@synthesize equation=_equation;

- (data_p)yValueForXValue:(data_p)xVal;
{
    RSEquation eq = _equation;
    
    if (_equation.type == RSEquationTypeLinear) {  // y = ax + b
        return eq.a*xVal + eq.b;
    }
    
    else if (_equation.type == RSEquationTypeSquare) {  // y = (x - a)^2 + b
        //return eq.c*xVal*xVal + eq.a*xVal + eq.b;
        return eq.c*pow(xVal - eq.a, 2) + eq.b;
    }
    
    else if (_equation.type == RSEquationTypeCube) {  // y = (x - a)^3 + b
        //return eq.c*xVal*xVal + eq.a*xVal + eq.b;
        return eq.c*pow(xVal - eq.a, 3) + eq.b;
    }
    
    else if (_equation.type == RSEquationTypeSine) {  // y = sin(x - a) + b
        //return eq.c*sin(xVal*eq.a) + eq.b;
        return eq.c*sin(xVal - eq.a) + eq.b;
    }
    
    else if (_equation.type == RSEquationTypeGaussian) {  // y = ce^-(x - a)^2 + b
        return eq.c*exp(-pow(xVal - eq.a, 2)) + eq.b;
    }
    
    else if (_equation.type == RSEquationTypeLogistic) {  // y = c/(1 + e^-(x - a)) + b
        return eq.c/(1 + exp(-(xVal - eq.a))) + eq.b;
    }
    
    NSLog(@"Unknown equation type.");
    return xVal;
}

- (void)updateEndpoints;
{
    data_p xMin = [_graph xMin];
    RSDataPoint startPos = RSDataPointMake(xMin, [self yValueForXValue:xMin]);
    data_p xMax = [_graph xMax];
    RSDataPoint endPos = RSDataPointMake(xMax, [self yValueForXValue:xMax]);
    
    [[self startVertex] setPosition:startPos];
    [[self endVertex] setPosition:endPos];
}



//////////////////////////////////////////////////
#pragma mark -
#pragma mark RSLine subclass
//////////////////
+ (BOOL)supportsConnectMethod:(RSConnectType)connectMethod;
{
    return NO;
}

- (BOOL)isEmpty {
    return NO;
}
- (BOOL)isTooSmall {
    return NO;
}
- (BOOL)isCurved;
{
    return NO;
}

- (void)setNeedsRecompute {
    _needsRecompute = YES;
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}

- (BOOL)recomputeNow {
    // Recompute parameters only if it has been requested previously
    if (!_needsRecompute) {
	return NO;
    }
    
    //[self updateParameters];
    [self updateEndpoints];
    [self updateLabel];
    
    _needsRecompute = NO;
    return YES;
}

// This is where it really gets interesting
- (BOOL)isMovable {
    return YES;  // unlike other lines, which are not movable (but based on endpoints)
}
- (RSDataPoint)position;
{
    // Make up a fake position that corresponds to constants
    RSDataPoint p;
    p.x = _equation.a;
    p.y = _equation.b;
    return p;
}
- (void)setPosition:(RSDataPoint)p;
{
    _equation.a = p.x;
    _equation.b = p.y;
    
    [self setNeedsRecompute];
}


#pragma mark Strings

- (NSString *)equationString;
{
    NSString *sa = [[_graph xAxis] formattedDataValue:fabs(_equation.a)];
    NSString *sb = [[_graph yAxis] formattedDataValue:fabs(_equation.b)];
    NSString *sc = [NSString stringWithFormat:@"%.13g", _equation.c];
    if ([sc isEqualToString:@"1"])
        sc = @"";
    
    NSString *finalString = @"";
    
    NSString *aTerm = @"x";
    if (_equation.a) {
        NSString *sign = _equation.a >= 0 ? @"+" : @"-";
        aTerm = [NSString stringWithFormat:@"x %@ %@", sign, sa];
    }
    
    if (_equation.type == RSEquationTypeSquare || _equation.type == RSEquationTypeCube) {
        NSString *power = _equation.type == RSEquationTypeSquare ? @"2" : @"3";
        if (!_equation.a) {
            finalString = [NSString stringWithFormat:@"y = %@x^%@", sc, power];
        } else {
            finalString = [NSString stringWithFormat:@"y = %@(%@)^%@", sc, aTerm, power];
        }
    }
    
    else if (_equation.type == RSEquationTypeSine) {
        finalString = [NSString stringWithFormat:@"y = %@sin(%@)", sc, aTerm];
    }
    
    else if (_equation.type == RSEquationTypeGaussian) {
        finalString = [NSString stringWithFormat:@"y = %@e^(-(%@)^2)", sc, aTerm];
    }
    
    else if (_equation.type == RSEquationTypeLogistic) {
        finalString = [NSString stringWithFormat:@"y = %.13g/(1 + e^(-(%@))", _equation.c, aTerm];
    }
    
    if (_equation.b) {
        NSString *sign = _equation.b >= 0 ? @"+" : @"-";
        finalString = [finalString stringByAppendingFormat:@" %@ %@", sign, sb];
    }
    
    return finalString;
}

- (void)updateLabel;
{
    if ( !_label )  return;	// no point in continuing if there's no label
    
    [_label setText:[self equationString]];
}

- (NSString *)infoString;
{
    NSString *format = NSLocalizedStringFromTableInBundle(@"Function:   %1$@", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar description of a function line");
    return [NSString stringWithFormat:format, [self equationString]];
}


@end
