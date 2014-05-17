// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <UIKit/UIKit.h>

@class OAFontDescriptor;
@class RSAxis;

@interface AxisEndHandleView : UIImageView
{
@private
    RSAxis *axis;
    int orientation;
    BOOL isMax;
    BOOL isEditing;
    
    CGSize graphicSize;
    
    NSString *labelText;
    UIImageView *labelView;
}

- (id)initWithAxis:(RSAxis *)A isMax:(BOOL)m;

@property (nonatomic,assign) RSAxis *axis;
@property (nonatomic,readonly) int orientation;
@property BOOL isMax;
@property (retain) NSString *labelText;
@property (readonly) NSAttributedString *labelAttributedString;
@property BOOL isEditing;

@property (readonly) UIFont *font;
@property (readonly) OAFontDescriptor *fontDescriptor;
@property (readonly) UIColor *textColor;
@property (readonly) CGPoint textOrigin;

@property (readonly) CGSize graphicSize;
@property (readonly) CGPoint centerOffset;

- (void)setup;
- (void)update;

@end
