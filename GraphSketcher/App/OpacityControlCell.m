// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OpacityControlCell.h"


@implementation OpacityControlCell

@synthesize color = _color;
@synthesize opacity = _opacity;


- (void)awakeFromNib;
{
    [self setColor:[NSColor redColor]];
    [self setOpacity:0.25f];
}


//////////////////////
#pragma mark -
#pragma mark NSButtonCell subclass
////////////////////

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView*)controlView;
{
    //NSLog(@"tag:%d state:%d highlit:%d showhi:%d showstate:%d", [self tag], [self state], [self isHighlighted], [self highlightsBy], [self showsStateBy]);
    
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:frame];
    
    [[[_color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] colorWithAlphaComponent:_opacity] set];
    [path fill];
    
//    float brightness = [[_color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] brightnessComponent];
    
    [[[[_color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] blendedColorWithFraction:0.2f ofColor:[NSColor blackColor]] colorWithAlphaComponent:_opacity*1.2f] set];
    [path setLineWidth:2];
    [path stroke];
    
}

@end
