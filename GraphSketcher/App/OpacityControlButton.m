// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/OpacityControlButton.m 200244 2013-12-10 00:11:55Z correia $

#import "OpacityControlButton.h"

#import "OpacityControlCell.h"

@implementation OpacityControlButton

+ (Class)cellClass;
{
    return [OpacityControlCell class];
}



//@synthesize floatValue = _theFloatValue;
//@synthesize stepAmount = _theIncrement;
//
//
//- (float)floatValue;
//{
//    NSLog(@"floatValue: %f", _theFloatValue);
//    return _theFloatValue;
//}
//- (void)setFloatValue:(float)value;
//{
//    NSLog(@"setFloatValue: %f", value);
//    _theFloatValue = value;
//}
//- (float)stepAmount;
//{
//    return _theIncrement;
//}
//- (void)setStepAmount:(float)value;
//{
//    _theIncrement = value;
//}
//
//
//
//- (void)mouseDown:(NSEvent *)theEvent
//{
//    //OpacityControlCell *cell = [self cell];
//    
//    NSLog(@"increment: %f", _theIncrement);
//    
//    float newValue = _theFloatValue + _theIncrement;// [self floatValue] + [self increment];
//    if (newValue > 1)
//	newValue = 1;
//    else if (newValue < 1)
//	newValue = 0;
//    
//    [self setFloatValue:newValue];
//    
//    NSLog(@"newValue: %f", newValue);
//    
//    [super mouseDown:theEvent];
//}


@end
