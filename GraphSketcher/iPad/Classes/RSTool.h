// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// The RSTool subclasses do important setup and teardown in -activate and -deactivate, mainly setting up gesture recognizers.

#import <OmniFoundation/OFObject.h>

#if 0 && defined(DEBUG_robin)
    #define GestureLog(format, ...) NSLog( format, ## __VA_ARGS__ )
#else
    #define GestureLog(format, ...)
#endif

@class RSDataMapper, RSGraphRenderer, RSGraph, RSGraphEditor, RSGraphElement;
@class GraphView;

@interface RSTool : OFObject
{
@private
    GraphView *_view;  // non-retained
    
    BOOL _active;
}

@property(readonly) GraphView *view;
@property(readonly,nonatomic) RSGraphEditor *editor;

@property(readonly,nonatomic) NSSet *affectedObjects;

- (id)initWithView:(GraphView *)view;

- (void)viewScaleChanged;
- (void)viewScrollPositionChanged;

- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
- (void)graphEditorDidUpdate:(RSGraphEditor *)editor;

- (void)activate;
- (void)deactivate;

- (NSArray *)leftBarButtonItems;
- (NSArray *)rightBarButtonItems;
- (NSString *)toolbarTitle; // Will replace the document name when non-nil

- (BOOL)undoLastChange;
- (BOOL)redoLastChange;
- (void)completeOperationWithElement:(RSGraphElement *)GE;

// Touch events from view
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;

@end
