// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/GraphSketcherModel_Prefix.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniFoundation/OmniFoundation.h>
#import <OmniBase/OmniBase.h>
#import <Foundation/Foundation.h>

#import <GraphSketcherModel/RSLog.h>
#import <GraphSketcherModel/GSMErrors.h>

#if 0 && defined(DEBUG)
    #define DEBUG_UNDOER(format, ...) NSLog((format), ## __VA_ARGS__)
#else
    #define DEBUG_UNDOER(format, ...)
#endif

