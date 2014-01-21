// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSFitLine.h 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSLine.h>

@interface RSFitLine : RSLine
{
    RSGroup *_data;	// the group of vertices which calculations are based on
    data_p _m;	// slope of line (cache)
    data_p _b;	// intercept of line (cache)
    data_p _r2;  // R^2 value of regression
    
    BOOL _needsRecompute;
}

// class methods -- don't call these from outside of class
- (void)updateParameters;
- (void)updateEndpoints;
- (void)resetEndpoints;


// Designated Initializer
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier data:(RSGroup *)data;


// Line accessors
- (RSGroup *)data;  // this is the data we use to calculate the fit line (as opposed to the vertices at the ends of the fit line itself).
- (RSGroup *)groupWithData;


// Recomputing best-fit line parameters
- (void)updateLabel;

@end
