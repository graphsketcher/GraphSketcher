// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "ButtonRibbonCell.h"

#import <Foundation/NSGeometry.h>
#import <OmniQuartz/OQDrawing.h>
#import <OmniQuartz/OQColor.h>

RCS_ID("$Header$");

#define CORNER_RADIUS (3.0f)

const CGFloat ButtonRibbonCellCellHeight = 32;

static CGShadingRef NormalBackgroundShading = NULL;
static CGShadingRef SelectedBackgroundShading = NULL;
static CGColorRef ShadowColor;

static NSShadow *WhiteShadow = nil;

static CGShadingRef CreateShadingWithGrays(float lightGray, float darkGray)
{
    OQRGBAColorPair *colorPair = malloc(sizeof(OQRGBAColorPair));
    NSColor *lighterColor = [[NSColor colorWithCalibratedWhite:lightGray alpha:1] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    NSColor *darkerColor = [[NSColor colorWithCalibratedWhite:darkGray alpha:1] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    OQFillRGBAColorPair(colorPair, lighterColor, darkerColor);
    
    static const CGFloat domainAndRange[8] = {0, 1, 0, 1, 0, 1, 0, 1};
    CGFunctionRef blendFunction = CGFunctionCreate(colorPair, 1, domainAndRange, 4, domainAndRange, &OQLinearFunctionCallbacks);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGShadingRef shading = CGShadingCreateAxial(colorSpace, CGPointMake(0, 0), CGPointMake(0, ButtonRibbonCellCellHeight), blendFunction, NO, NO);
    
    CGFunctionRelease(blendFunction);
    CGColorSpaceRelease(colorSpace);
    
    return shading;
}

@implementation ButtonRibbonCell

+ (void)initialize;
{
    OBINITIALIZE;

    NormalBackgroundShading = CreateShadingWithGrays(0.98f, 0.89f);
    SelectedBackgroundShading = CreateShadingWithGrays(0.66f, 0.75f);
    
    {
        CGFloat components[] = {0.0f, 0.6f};
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
        ShadowColor = CGColorCreate(colorSpace, components);
        CGColorSpaceRelease(colorSpace);
    }

    WhiteShadow = [[NSShadow alloc] init];
    [WhiteShadow setShadowOffset:NSMakeSize(0, -1.0f)];
    [WhiteShadow setShadowColor:[NSColor whiteColor]];
}

- (void)awakeFromNib;
{
    // This causes the buttons to display the "alternate" image when in the "on" (looks pushed down) state.
    [self setShowsStateBy:NSContentsCellMask];
}

- (ButtonRibbonCellPosition)position;
{
    return _position;
}

- (void)setPosition:(ButtonRibbonCellPosition)position;
{
    _position = position;
}

- (BOOL)pressButton;
{
    return _pressButton;
}

- (void)setPressButton:(BOOL)pressButton;
{
    _pressButton = pressButton;
}

#pragma mark NSButtonCell subclass

- (void)drawImage:(NSImage*)image withFrame:(NSRect)frame inView:(NSView*)controlView;
{
    // Push the images down a bit from where AppKit would put them.
    frame.origin.y += 1;
    [super drawImage:image withFrame:frame inView:controlView];
}

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView;
{
    // Push the titles down a bit from where AppKit would put them.
    frame.origin.y += 2;
    
    // Turn on a shadow
    NSRect result;
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(ctx); {
        [WhiteShadow set];
        result = [super drawTitle:title withFrame:frame inView:controlView];
    } CGContextRestoreGState(ctx);
    
    return result;
}

static void _appendPath(CGContextRef ctx, NSRect frame, ButtonRibbonCellPosition position, BOOL forceClosed)
{
    if (position == ButtonRibbonCellLeft) {
        // Left draws 4 sides
        OQAppendRectWithRoundedLeft(ctx, NSInsetRect(frame, 0.5f, 0.5f), CORNER_RADIUS, YES/*closeRight*/);
    } else if (position == ButtonRibbonCellMiddle) {
        // Middle draws 3 sides (one done by its left neighbor)
        CGContextMoveToPoint(ctx, NSMinX(frame), NSMinY(frame) + 0.5f); 
        CGContextAddLineToPoint(ctx, NSMaxX(frame) - 0.5f, NSMinY(frame) + 0.5f);
        CGContextAddLineToPoint(ctx, NSMaxX(frame) - 0.5f, NSMaxY(frame) - 0.5f);
        CGContextAddLineToPoint(ctx, NSMinX(frame), NSMaxY(frame) - 0.5f); 
    } else if (position == ButtonRibbonCellRight) {
        // Right draws 3 sides (one done by its left neighbor)
        NSRect strokeRect = NSInsetRect(frame, 0.5f, 0.5f);
        strokeRect.origin.x -= 0.5f; // only wanted to inset on three sides
        strokeRect.size.width += 0.5f; 
        OQAppendRectWithRoundedRight(ctx, strokeRect, CORNER_RADIUS, forceClosed/*closeLeft*/);
    } else if (position == ButtonRibbonCellFull) {
        NSRect strokeRect = NSInsetRect(frame, 0.5f, 0.5f);
        OQAppendRoundedRect(ctx, strokeRect, CORNER_RADIUS);
    }
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView*)controlView;
{
    //NSLog(@"tag:%d state:%d highlit:%d showhi:%d showstate:%d", [self tag], [self state], [self isHighlighted], [self highlightsBy], [self showsStateBy]);

    
    // NSCell's masks for this are bizarre. Also it seems like NSMatrix resets them or something.  We just want two behaviors; radio matrix & press button.
    BOOL drawPressed = NO;
    if (_pressButton) {
        // We are in a normal button.
        drawPressed = [self isHighlighted];
    } else {
        // We are in the radio matrix
        drawPressed = ([self state] == NSOnState) || [self isHighlighted];
    }
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];

    // Draw the right shading
    CGShadingRef shading;
    if (drawPressed)
        shading = SelectedBackgroundShading;
    else
        shading = NormalBackgroundShading;
    
    frame.size.height -= 1; // leave room for shadow
    
    // Prepare the path for the background capsule.
    _appendPath(ctx, frame, _position, YES/*forceClosed*/);
    
    // Draw the entire capsule in a layer with a white shadow
    CGContextSaveGState(ctx); {
        
        [WhiteShadow set];
        CGContextBeginTransparencyLayer(ctx, NULL); {
            CGContextSaveGState(ctx); {
                CGContextClip(ctx);
                CGContextDrawShading(ctx, shading);
                
                if (drawPressed) {
                    // Also, if we are the selected cell, while we have the clip on, draw a shadow around the edge
                    // Add a big rect outside of our clip path and then add our clip path again (closed this time).
                    // EO fill will then cut a hole out where our clip path is but we should see the shadow cast from outside.
                    CGContextSetShadowWithColor(ctx, CGSizeMake(0,-2), 3, ShadowColor);
                    
                    CGRect outerRect = CGRectMake(NSMinX(frame), NSMinY(frame), NSWidth(frame), NSHeight(frame));
                    outerRect = CGRectInset(outerRect, -20, -20);
                    CGContextAddRect(ctx, outerRect);
                    
                    // Push the bottom of the inner frame down to avoid shadow there, allowing us to adjust the radius w/o it encroaching on the bottom
                    NSRect shadowInnerFrame = frame;
                    shadowInnerFrame.size.height += 10;
                    
                    _appendPath(ctx, shadowInnerFrame, _position, YES/*forceClosed*/);
                    
                    
                    CGContextDrawPath(ctx, kCGPathEOFill);
                }
            } CGContextRestoreGState(ctx);
        } CGContextEndTransparencyLayer(ctx);
    } CGContextRestoreGState(ctx);

    
    // Darker border when pressed
    if (drawPressed)
        [[NSColor colorWithCalibratedWhite:0.5f alpha:1] set];
    else
        [[NSColor colorWithCalibratedWhite:0.6f alpha:1] set];
        
    _appendPath(ctx, frame, _position, NO/*forceClosed*/);
    CGContextStrokePath(ctx);
}

@end
