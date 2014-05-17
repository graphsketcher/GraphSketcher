// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSTool.h"

#import "GraphView.h"
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraphElementSelector.h>

RCS_ID("$Header$");

@implementation RSTool

- (id)initWithView:(GraphView *)view;
{
    if (!(self = [super init]))
        return nil;
    
    _view = view;
    _active = NO;
    
    return self;
}

- (void)dealloc;
{
    OBASSERT(_active == NO);
    
    [super dealloc];
}


#pragma mark -
#pragma mark KVO

//- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
//{
//    if (object == self && [keyPath isEqualToString:@"view"]) {
//        // Finish setting up ivars based on the gesture recognizer's view
//        UIView *view = self.view;
//        if (view) {
//            OBASSERT([view isKindOfClass:[GraphView class]]);
//            _editor = [(GraphView *)view editor];
//        }
//    }
//}


#pragma mark -

@synthesize view = _view;

- (RSGraphEditor *)editor;
{
    return self.view.editor;
}

- (NSSet *)affectedObjects;
{
    return nil;
}

- (void)viewScaleChanged;
{
    // For subclasses
}

- (void)viewScrollPositionChanged;
{
    // For subclasses
}

- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
{
    // For subclasses that have auxiliary views.
    
    [self.view setNeedsLayout];
    [self.view setNeedsDisplay];
    [self.view.selectionView setNeedsDisplay];
}

- (void)graphEditorDidUpdate:(RSGraphEditor *)editor;
{
    // For subclasses that have auxiliary views.
}

- (void)activate;
{
    OBASSERT(_active == NO);
    _active = YES;
}

- (void)deactivate;
{
    OBASSERT(_active == YES);
    _active = NO;
}

- (NSArray *)leftBarButtonItems;
{
    return nil;
}

- (NSArray *)rightBarButtonItems;
{
    return nil;
}

- (NSString *)toolbarTitle;
{
    return nil;
}

- (BOOL)undoLastChange;
{
    return NO;
}

- (BOOL)redoLastChange;
{
    return NO;
}

- (void)completeOperationWithElement:(RSGraphElement *)GE;
{
    if (!GE)
        return;
    
    [self.view setToolMode:RSToolModeHand];
    
    self.view.selectionController.selection = GE;
    [self.view showSelectionAnimated:YES];
}


#pragma mark -
#pragma mark Touch events from view

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    //[super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
    //[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
    //[super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
{
    //[super touchesCancelled:touches withEvent:event];
}

//- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer;
//{
//    if ([preventingGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
//        return YES;
//    }
//    
//    return [super canBePreventedByGestureRecognizer:preventingGestureRecognizer];
//}



@end
