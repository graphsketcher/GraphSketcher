// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSBoxSeparator.h"


@implementation RSBoxSeparator

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
    if ([self boxType] != NSBoxSeparator) {
	OBASSERT_NOT_REACHED("This subclass can only draw separators.");
	[super drawRect:rect];
    }
    
    //NSLog(@"separator bounds: %@", NSStringFromRect([self bounds]));
    NSBezierPath *P = [NSBezierPath bezierPath];
    NSRect bounds = [self bounds];
    CGFloat y = bounds.size.height / 2;
    [P moveToPoint: NSMakePoint(0, y)];
    [P lineToPoint: NSMakePoint(bounds.size.width, y)];
    
    [P setLineWidth:1];
    [[NSColor colorWithCalibratedWhite:0.7f alpha:1] set];
    [P stroke];
}

@end
