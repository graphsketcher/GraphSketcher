// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSModifyTool.h 200244 2013-12-10 00:11:55Z correia $

// RSModify tool is the main "hand" mode and is the most complex; it coordinates dragging, snapping, and multi-selection operations. Some of the functionality has been migrating into RSGraphEditor and more should follow.

#import "RSTool.h"

#import <GraphSketcherModel/RSGraph.h> // RSAxisEnd

@class RSVertex, RSGroup, RSGraphElement;

@interface RSModifyTool : RSTool
{
    RSVertex *_movingVertex;
    RSGroup *_movers;
    NSArray *_vertexCluster;
    RSGraphElement *_originalSelection;
    RSGraphElement *_newLabelOwner;
    
    RSVertex *_overBarEnd;
    BOOL _overOrigin;
    RSAxisEnd _overAxisEnd;
    data_p _downTick;
    CGPoint _viewMins;
    CGPoint _viewMaxes;
    RSAxisEnd _behaveLikeAxisEnd;
    NSUInteger _overMarginGuide;
    
    RSDataPoint _closestGridPoint;
    RSDataPoint _startDrawPoint;
    CGPoint _cursorOffset;
    CGPoint _prevMouseDraggedPoint;
    
    RSDataPoint _dataAxisMins;
    RSDataPoint _dataAxisMaxes;
    
    BOOL _rectangularSelect;
    BOOL _startEditingNextLabel;
    BOOL _dragMarginGuide;
}

@property(retain) RSGraphElement *originalSelection;
@property(retain) RSGroup *movers;
@property(retain) NSArray *vertexCluster;

@end
