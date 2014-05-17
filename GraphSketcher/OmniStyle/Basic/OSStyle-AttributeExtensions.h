// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSStyle.h"
#import <OmniAppKit/OAParagraphStyle.h>
#import <OmniAppKit/OAFontDescriptor.h>

@interface OSStyle (AttributeExtensions)

@property(nonatomic) CGFloat fontSize;
- (OAPlatformFontClass *)font;

- (OAFontDescriptor *)newFontDescriptor;
- (void)setFontDescriptor:(OAFontDescriptor *)fontDescriptor;

- (NSMutableParagraphStyle *)newParagraphStyle;
- (void)setParagraphStyle:(NSParagraphStyle *)paragraphStyle;

+ (NSString *)stringForTabStops:(NSArray *)tabStops;
+ (NSArray *)tabStopsForString:(NSString *)string;

@end

