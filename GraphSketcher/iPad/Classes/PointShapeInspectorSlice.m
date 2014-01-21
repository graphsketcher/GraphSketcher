// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/PointShapeInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "PointShapeInspectorSlice.h"

#import <OmniUI/OUISegmentedControl.h>
#import <OmniUI/OUISegmentedControlButton.h>
#import <OmniUI/OUIInspectorOptionWheel.h>
#import "InspectorSupport.h"
#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSGraphEditor.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/PointShapeInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $");

@interface PointShapeInspectorSlice (/*Private*/)
- (void)_changeShape:(NSInteger)shape;
- (void)_setShapeTypeVisibile:(BOOL)visible;
@end

@implementation PointShapeInspectorSlice

- (void)dealloc;
{
    [_pointTypeSegmentedControl release];
    [_shapeTypeOptionWheel release];

    [super dealloc];
}

@synthesize pointTypeSegmentedControl = _pointTypeSegmentedControl;
@synthesize shapeTypeOptionWheel = _shapeTypeOptionWheel;

#pragma mark -
#pragma mark OUIInspectorSlice

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSGraphElement class]])
        return NO;
    RSGraphElement *element = object;
    if (![element hasShape])
        return NO;
    return YES;
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    NSNumber *shapeType = [self singleSelectedValueForIntegerSelector:@selector(shape)];
    NSInteger shape = [shapeType integerValue];
        
    if (!shapeType || shape == RS_SHAPE_MIXED) {
        [_pointTypeSegmentedControl setSelectedSegment:nil];
        [self _setShapeTypeVisibile:NO];
        return;
    }
    
    if (shape != RS_NONE && shape <= RS_LAST_STANDARD_SHAPE) {
        [_pointTypeSegmentedControl setSelectedSegment:_pointTypeSegmentedControl.firstSegment];
        [_shapeTypeOptionWheel setSelectedValue:shapeType animated:(reason == OUIInspectorUpdateReasonObjectsEdited)];
        [self _setShapeTypeVisibile:YES];
        return;
    }
    
    // One of the special shape types
    [_pointTypeSegmentedControl setSelectedSegment:[_pointTypeSegmentedControl segmentWithRepresentedObject:shapeType]];
    [self _setShapeTypeVisibile:NO];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    // This represents anything that is not NONE and is <= RS_LAST_STANDARD_SHAPE. Selecting it will make the thing a circle, though.
    _pointTypeSegmentedControl.sizesSegmentsToFit = YES;
    [_pointTypeSegmentedControl addSegmentWithImageNamed:@"PointTypeShape.png" representedObject:[NSNumber numberWithInt:RS_CIRCLE]];
    
    [_pointTypeSegmentedControl addSegmentWithImageNamed:@"PointTypeTick.png" representedObject:[NSNumber numberWithInt:RS_TICKMARK]];
    [_pointTypeSegmentedControl addSegmentWithImageNamed:@"PointTypeVerticalBar.png" representedObject:[NSNumber numberWithInt:RS_BAR_VERTICAL]];
    [_pointTypeSegmentedControl addSegmentWithImageNamed:@"PointTypeHorizontalBar.png" representedObject:[NSNumber numberWithInt:RS_BAR_HORIZONTAL]];
    [_pointTypeSegmentedControl addSegmentWithImageNamed:@"PointTypeNone.png" representedObject:[NSNumber numberWithInt:RS_NONE]];

    
    [_shapeTypeOptionWheel addItemWithImageNamed:@"PointShapeCircle.png" value:[NSNumber numberWithInt:RS_CIRCLE]];
    [_shapeTypeOptionWheel addItemWithImageNamed:@"PointShapeTriangle.png" value:[NSNumber numberWithInt:RS_TRIANGLE]];
    [_shapeTypeOptionWheel addItemWithImageNamed:@"PointShapeSquare.png" value:[NSNumber numberWithInt:RS_SQUARE]];
    [_shapeTypeOptionWheel addItemWithImageNamed:@"PointShapeStar.png" value:[NSNumber numberWithInt:RS_STAR]];
    [_shapeTypeOptionWheel addItemWithImageNamed:@"PointShapeDiamond.png" value:[NSNumber numberWithInt:RS_DIAMOND]];
    [_shapeTypeOptionWheel addItemWithImageNamed:@"PointShapeX.png" value:[NSNumber numberWithInt:RS_X]];
    [_shapeTypeOptionWheel addItemWithImageNamed:@"PointShapeCross.png" value:[NSNumber numberWithInt:RS_CROSS]];
    [_shapeTypeOptionWheel addItemWithImageNamed:@"PointShapeHollow.png" value:[NSNumber numberWithInt:RS_HOLLOW]];
    
    // Without this, our first call to -setSelectedValue:animated: on _shapeTypeOptionWheel will do nothing. 
    [self.view layoutIfNeeded];
    
    // Remember the space needed for the shape type so we can add/remove it.
    _shapeTypeSpace = CGRectGetMaxY(_shapeTypeOptionWheel.frame) - CGRectGetMaxY(_pointTypeSegmentedControl.frame);
}

- (IBAction)changePointType:(id)sender;
{
    NSNumber *selectedValue = _pointTypeSegmentedControl.selectedSegment.representedObject;
    if (!selectedValue) {
        OBASSERT_NOT_REACHED("shouldn't send the action, then");
        return;
    }
    
    [self _changeShape:[selectedValue integerValue]];
}

- (IBAction)changeShape:(id)sender;
{
    NSNumber *selectedValue = _shapeTypeOptionWheel.selectedValue;
    if (!selectedValue) {
        OBASSERT_NOT_REACHED("shouldn't send the action, then");
        return;
    }
    
    [self _changeShape:[selectedValue integerValue]];
}

#pragma mark -
#pragma mark Private

- (void)_changeShape:(NSInteger)shape;
{
    RSGraphEditor *editor = self.editor;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSGraphElement *obj in self.appropriateObjectsForInspection)
            [editor setShape:shape forElement:obj];
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (void)_setShapeTypeVisibile:(BOOL)visible;
{
    BOOL isVisible = (_shapeTypeOptionWheel.alpha > 0);
    
    if (!(visible ^ isVisible))
        return;
    
    UIView *view = self.view;
    CGRect frame = view.frame;
    
    frame.size.height += visible ? _shapeTypeSpace : -_shapeTypeSpace;

    BOOL animate = (view.window != nil);
    
    if (animate)
        [UIView beginAnimations:@"toggling shape type control" context:NULL];
    {
        view.frame = frame;
        _shapeTypeOptionWheel.alpha = visible ? 1 : 0;
        
        [self sizeChanged];
        [view layoutIfNeeded];
    }
    if (animate)
        [UIView commitAnimations];
}

@end
