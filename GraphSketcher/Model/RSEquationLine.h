// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header$

#import <GraphSketcherModel/RSLine.h>


typedef enum _RSEquationType {
    RSEquationTypeLinear = 0,  // y = ax + b
    RSEquationTypeSquare = 1,  // y = (x - a)^2 + b
    RSEquationTypeCube = 2,  // y = (x - a)^3 + b
    RSEquationTypeSine = 3,  // y = sin(x - a) + b
    RSEquationTypeGaussian = 4,  // y = ce^-(x - a)^2 + b
    RSEquationTypeLogistic = 5,  // y = c/(1 + e^-(x - a)) + b
} RSEquationType;

typedef struct _RSEquation {
    RSEquationType type;
    data_p a;
    data_p b;
    data_p c;
} RSEquation;

RSEquation RSEquationZero(void);


@interface RSEquationLine : RSLine {
    RSEquation _equation;
    
    BOOL _needsRecompute;
}

// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier equation:(RSEquation)equation;

@property (nonatomic) RSEquation equation;

- (data_p)yValueForXValue:(data_p)xVal;

- (void)updateEndpoints;
- (void)updateLabel;

@end
