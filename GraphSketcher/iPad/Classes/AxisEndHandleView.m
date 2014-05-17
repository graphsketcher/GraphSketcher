// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "AxisEndHandleView.h"
#import "Parameters.h"
#import <GraphSketcherModel/RSAxis.h>
#import <OmniAppKit/OAFontDescriptor.h>

#import <GraphSketcherModel/RSTextLabel.h>
#import <OmniUI/OUITextLayout.h>


@interface AxisEndHandleView (/*Private*/)
- (UIImage *)imageFromString:(NSString *)string;
@end



@implementation AxisEndHandleView


- (id)initWithFrame:(CGRect)frame;
{
    OBRequestConcreteImplementation([self class], _cmd);
    return nil;
}

// Designated initializer
- (id)initWithAxis:(RSAxis *)A isMax:(BOOL)m;
{
    if (!(self = [super initWithFrame:CGRectZero]))
        return nil;
    
    axis = A;
    
    self.userInteractionEnabled = YES;
    //self.backgroundColor = [[UIColor yellowColor] colorWithAlphaComponent:0.5];
    
//    labelView = [[UILabel alloc] initWithFrame:CGRectZero];
//    labelView.opaque = NO;
//    labelView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
//    labelView.font = self.font;
    labelView = [[UIImageView alloc] initWithFrame:CGRectZero];
    
    [self addSubview:labelView];
    [labelView release];
    
    // Defaults
    isMax = m;
    orientation = axis.orientation;
    
    // Setup graphics
    [self setup];
    
    return self;
}

- (void)dealloc;
{
    [labelView removeFromSuperview];
    
    [super dealloc];
}

- (UIImage *)imageFromString:(NSString *)string;
{
    NSDictionary *attributes = @{NSFontAttributeName:self.font, NSForegroundColorAttributeName:self.textColor};
    NSAttributedString *attString = [[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease];
    
    // Superscript
    NSAttributedString *superscriptString = [self.axis formatExponentsInString:attString];
    
    return [OUITextLayout imageFromAttributedString:superscriptString];
}

#pragma mark - Class methods

@synthesize axis, orientation, isMax, isEditing;
@synthesize graphicSize;

- (void)setAxis:(RSAxis *)newAxis;
{
    if (axis == newAxis)
        return;
    
    axis = newAxis;
    orientation = axis.orientation;
    
    [self setup];
    [self update];
}

- (NSString *)labelText;
{
    return labelText;
}

- (void)setLabelText:(NSString *)str;
{
    if ([labelText isEqualToString:str]) {
        return;
    }
    
    [labelText release];
    labelText = [str retain];
    
    //labelView.text = str;
    labelView.image = [self imageFromString:labelText];
    [labelView sizeToFit];
    
    [self update];
}

- (NSAttributedString *)labelAttributedString;
{
    return [[[NSAttributedString alloc] initWithString:labelText attributes:[self.fontDescriptor fontAttributes]] autorelease];
}

- (UIFont *)font;
{
    return [UIFont systemFontOfSize:24];
}

- (OAFontDescriptor *)fontDescriptor;
{
    UIFont *font = self.font;
    OAFontDescriptor *descriptor = [[OAFontDescriptor alloc] initWithFamily:font.familyName size:font.pointSize];
    return [descriptor autorelease];
}

- (UIColor *)textColor;
{
    return [UIColor blackColor];
}

- (CGPoint)textOrigin;
{
    CGRect labelViewFrame = labelView.frame;
    return CGPointMake(CGRectGetMinX(labelViewFrame), CGRectGetMaxY(labelViewFrame));
}

- (CGPoint)centerOffset;
{
    CGPoint delta;
    
    if (orientation == RS_ORIENTATION_HORIZONTAL) {
        
        if (isMax) {
            CGPoint tipInset = AXIS_END_LABEL_HORIZONTAL_MAX_TIP_INSET;
            delta = CGPointMake(-CGRectGetWidth(self.bounds)/2.0 + tipInset.x, CGRectGetHeight(self.bounds)/2.0 - tipInset.y);
        }
        else {
            CGPoint tipInset = AXIS_END_LABEL_HORIZONTAL_MIN_TIP_INSET;
            delta = CGPointMake(CGRectGetWidth(self.bounds)/2.0 - tipInset.x, CGRectGetHeight(self.bounds)/2.0 - tipInset.y);
        }
        return delta;
    }
    
    else {  // RS_ORIENTATION_VERTICAL
        if (isMax) {
            CGPoint tipInset = AXIS_END_LABEL_VERTICAL_MAX_TIP_INSET;
            delta = CGPointMake(-CGRectGetWidth(self.bounds)/2.0 + tipInset.x, CGRectGetHeight(self.bounds)/2.0 - tipInset.y);
        }
        else {
            CGPoint tipInset = AXIS_END_LABEL_VERTICAL_MIN_TIP_INSET;
            delta = CGPointMake(-CGRectGetWidth(self.bounds)/2.0 + tipInset.x, -CGRectGetHeight(self.bounds)/2.0 + tipInset.y);
        }
        return delta;
    }
}

- (void)setup;
{
    if (orientation == RS_ORIENTATION_HORIZONTAL) {
        
        CGFloat stretchPixel = AXIS_END_LABEL_HORIZONTAL_RESIZE_PIXEL;
        
        if (isMax) {
            self.image = [UIImage imageNamed:@"AxisLabelXMax.png"];
            [self sizeToFit];
            graphicSize = self.bounds.size;

            self.image = [self.image resizableImageWithCapInsets:UIEdgeInsetsMake(0/*top*/, stretchPixel/*left*/, 0/*bottom*/, graphicSize.width - stretchPixel + 1 /*right*/)];
        }
        else {  // min
            self.image = [UIImage imageNamed:@"AxisLabelXMin.png"];
            [self sizeToFit];
            graphicSize = self.bounds.size;

            self.image = [self.image resizableImageWithCapInsets:UIEdgeInsetsMake(0/*top*/, graphicSize.width - stretchPixel + 1/*left*/, 0/*bottom*/, stretchPixel/*right*/)];
        }

    }
    
    else {  // RS_ORIENTATION_VERTICAL
        CGFloat stretchPixel = AXIS_END_LABEL_VERTICAL_RESIZE_PIXEL;
        
        if (isMax) {
            self.image = [UIImage imageNamed:@"AxisLabelYMax.png"];
        }
        else {  // min
            self.image = [UIImage imageNamed:@"AxisLabelYMin.png"];
        }
        
        [self sizeToFit];
        graphicSize = self.bounds.size;

        self.image = [self.image resizableImageWithCapInsets:UIEdgeInsetsMake(0/*top*/, stretchPixel/*left*/, 0/*bottom*/, graphicSize.width - stretchPixel + 1 /*right*/)];
    }

}

- (void)update;
{
    // Resize
    CGRect newBounds = self.bounds;
    [labelView sizeToFit];
    
    newBounds.size.width = graphicSize.width + labelView.bounds.size.width;
    self.bounds = newBounds;
    //NSLog(@"new bounds: %@", NSStringFromCGRect(self.bounds));
    
    // Hide our version of the label if we're currently editing it.
    if (self.isEditing) {
        labelView.alpha = 0;
        return;
    }
    else {
        labelView.alpha = 1;
    }
    
    // Position the labelView correctly within the background graphic.
    if (orientation == RS_ORIENTATION_HORIZONTAL) {
        CGPoint labelInset = AXIS_END_LABEL_HORIZONTAL_TEXT_INSET;
        if (isMax) {
            labelView.center = CGPointMake(labelInset.x + CGRectGetWidth(labelView.bounds)/2.0f, labelInset.y + CGRectGetHeight(self.bounds)/2.0f);
        }
        else {
            labelView.center = CGPointMake(graphicSize.width - labelInset.x + CGRectGetWidth(labelView.bounds)/2.0f, labelInset.y + nearbyint(CGRectGetHeight(self.bounds)/2.0f));
        }
    }
    
    else {  // RS_ORIENTATION_VERTICAL
        CGPoint labelInset = AXIS_END_LABEL_VERTICAL_TEXT_INSET;
        labelView.center = CGPointMake(labelInset.x + CGRectGetWidth(labelView.bounds)/2.0f, labelInset.y + nearbyint(CGRectGetHeight(self.bounds)/2.0f));
    }
}


@end
