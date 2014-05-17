// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <UIKit/UIView.h>
#import <GraphSketcherModel/RSGraphElement.h>

#if 0 && defined(DEBUG_robin)
#define GEVLog(format, ...) NSLog( format, ## __VA_ARGS__ )
#else
#define GEVLog(format, ...)
#endif


@class RSGraphEditor, GraphView;


@interface RSGraphElementView : UIView
{
@private
    RSGraphElement *_graphElement;
    RSGraphElementSubpart _subpart;
    CGFloat _borderWidth;
    CFTimeInterval _selectionDelay;
    CFTimeInterval _fadeDuration;
    
    BOOL _drawFingerSize;
    BOOL _shouldHide;
}

@property (nonatomic, retain) RSGraphElement *graphElement;
@property (nonatomic) RSGraphElementSubpart subpart;
@property (readonly) GraphView *graphView;
@property (readonly) RSGraphEditor *editor;

@property (assign) CGFloat borderWidth;
@property (assign) CFTimeInterval selectionDelay;  // seconds
@property (assign) CFTimeInterval fadeDuration;  // seconds

// Frame setting
- (void)updateFrame;

// Animations
- (void)hideAnimated:(BOOL)animated;
- (void)showAnimated:(BOOL)animated;
- (void)makeFingerSize;
- (void)makeNormalSizeAndHide:(BOOL)hide;

// Rendering
- (void)establishAllRenderingTransforms;  // call this before performing RSGraphRenderer methods

@end
