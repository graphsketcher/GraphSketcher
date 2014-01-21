// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGraphEditor.h 200244 2013-12-10 00:11:55Z correia $

// RSGraphEditor is a newer class whose purpose is mainly to reduce code duplication between the mac and iPad apps.  Significant computation that used to be done in RSGraphView or inspector subclasses is now here instead so that it can be shared with the iPad.

#import <OmniFoundation/OFObject.h>
#import <GraphSketcherModel/RSGraphEditorDelegate.h>
#import <GraphSketcherModel/RSGraphDelegate.h>
#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSAxis.h>

@class RSDataMapper, RSGraphRenderer, RSUndoer, RSHitTester, RSGraphElement;

@interface RSGraphEditor : OFObject <RSGraphDelegate>
{
@private
    RSUndoer *_undoer;
    RSGraph *_graph;
    RSDataMapper *_mapper;
    RSGraphRenderer *_renderer;
    RSHitTester *_hitTester;
    id <RSGraphEditorDelegate> _nonretained_delegate;

    BOOL _needsUpdateDisplay;
    BOOL _needsUpdateWhitespace;
    BOOL _needsUpdateConstraints;
}

- initWithGraph:(RSGraph *)graph undoer:(RSUndoer *)undoer;

- (void)invalidate;

@property(readonly,nonatomic) RSGraph *graph;
@property(readonly,nonatomic) RSUndoer *undoer;
@property(assign,nonatomic) id <RSGraphEditorDelegate> delegate;
@property(readonly,nonatomic) RSDataMapper *mapper;
@property(readonly,nonatomic) RSGraphRenderer *renderer;
@property(readonly,nonatomic) RSHitTester *hitTester;

- (void)updateBounds:(CGRect)bounds;
- (void)prepareForDisplay;

- (void)prepareForSave;

- (void)setNeedsDisplay;
- (void)setNeedsUpdateWhitespace;
- (void)autoScaleIfWanted;
- (void)updateDisplayNow;

// Inspector helpers
- (void)setDistanceValue:(CGFloat)distanceValue forElement:(RSGraphElement *)obj snapDistanceToNearestInteger:(BOOL)snapDistanceToNearestInteger;
- (void)setShape:(NSInteger)styleIndex forElement:(RSGraphElement *)obj;

- (CGFloat)widthForElement:(RSGraphElement *)obj;
- (void)setWidth:(CGFloat)width forElement:(RSGraphElement *)obj snapDistanceToNearestInteger:(BOOL)snapDistanceToNearestInteger;

- (RSGraphElement *)setConnectMethod:(RSConnectType)connectMethod forElement:(RSGraphElement *)obj;
- (RSGraphElement *)setDash:(NSInteger)styleIndex forElement:(RSGraphElement *)obj;

- (void)changeX:(data_p)value forElement:(RSGraphElement *)obj;
- (void)changeY:(data_p)value forElement:(RSGraphElement *)obj;

- (BOOL)hasMinArrow:(RSGraphElement *)obj;
- (BOOL)hasMaxArrow:(RSGraphElement *)obj;

- (void)changeArrowhead:(NSInteger)styleIndex forElement:(RSGraphElement *)obj isLeft:(BOOL)isLeft;

- (void)setCanvasSize:(CGSize)canvasSize;

- (void)setPlacement:(RSAxisPlacement)placement forAxis:(RSAxis *)axis;
- (void)setDisplayTitle:(BOOL)displaysTitle forAxis:(RSAxis *)axis;
- (void)setDisplayTickMarks:(BOOL)displaysTickMarks forAxis:(RSAxis *)axis;
- (void)setDisplayTickLabels:(BOOL)displaysTickLabels forAxis:(RSAxis *)axis;
- (void)setTickSpacing:(data_p)tickSpacing forAxis:(RSAxis *)axis;

// Axis manipulation
- (void)dragAxisEnd:(RSAxisEnd)axisEnd downTick:(data_p)downTick currentPosition:(CGFloat)viewPos viewMin:(CGFloat)viewMin viewMax:(CGFloat)viewMax;
- (void)dragAxisEnd:(RSAxisEnd)axisEnd downPoint:(RSDataPoint)downPoint currentViewPoint:(CGPoint)viewPoint viewMins:(CGPoint)viewMins viewMaxes:(CGPoint)viewMaxes;
- (RSAxisEnd)axisEndEquivalentForPoint:(RSDataPoint)startPos onAxisOrientation:(int)orientation;

// Label editing
- (void)processText:(NSString *)text forEditedLabel:(RSTextLabel *)TL;
- (CGPoint)updatedLocationForEditedTextLabel:(RSTextLabel *)TL withSize:(CGSize)size;

// Special actions
- (void)autoRescueTextLabels;
- (RSGraphElement *)interpolateLine:(RSLine *)L;
- (RSGroup *)interpolateLines:(NSArray *)lines;

@end
