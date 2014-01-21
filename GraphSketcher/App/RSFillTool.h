// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSFillTool.h 200244 2013-12-10 00:11:55Z correia $

// RSFillTool supports creating fills by clicking on each corner of the desired area.

#import "RSTool.h"

@class RSFill, RSVertex, RSGraphElement;

@interface RSFillTool : RSTool
{
@private
    RSFill *_fillInProgress;
    RSVertex *_persistentVertex;
    RSVertex *_prevFillVertex;
    RSGraphElement *_objectToAdd;
    RSGraphElement *_retainedObjectToAdd;
    
    BOOL _shouldEndFill;
    
    RSDataPoint _startDrawPoint;
}

@end
