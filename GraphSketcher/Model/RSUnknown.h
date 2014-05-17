// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSUnknown was intended to stand in for a graph element when none are selected. This was to make the inspector's job easier in a pre-Omni framework world. The inspector ends up changing attributes of the RSUnknown, which in turn sets defaults which get applied when a real point or line is eventually created.

#import <GraphSketcherModel/RSGraphElement.h>

@class RSTextLabel;

@interface RSUnknown : RSGraphElement 
{
    OQColor *_color;
    CGFloat _width;
    RSDataPoint _position;
    RSTextLabel *_label;
    NSInteger _dash;
    NSInteger _shape;
    RSConnectType _connect;
}

// Designated initializer:
- (id)initWithIdentifier:(NSString *)identifier color:(OQColor *)color width:(CGFloat)width position:(RSDataPoint)p label:(RSTextLabel *)label dash:(NSInteger)dash shape:(NSInteger)shape connectMethod:(RSConnectType)connect;



@end
