// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/GSMErrors.h>

RCS_ID("$Header$");

// Can't use OMNI_BUNDLE_IDENTIFIER since the iPad app builds only a single bundle and we need our error codes to be disjoint from others.
NSString * const GSMErrorDomain = @"com.graphsketcher.GraphSketcherModel.ErrorDomain";
