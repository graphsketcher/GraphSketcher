// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFObject.h>
#import <Availability.h>

@class OUITextLayout;
@class OFXMLElement;
@class OQColor;
@class OAFontDescriptor;

extern NSDictionary *RSTextAttributesMake(OAFontDescriptor *fontDescriptor, OQColor *color);
extern const CGSize RSTextLayoutContraints;

@interface RSText : OFObject
{
@private
    OFXMLElement *_originalXML;
    NSMutableAttributedString *_attributedString;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    CGFloat _effectiveScale;
    OUITextLayout *_textLayout;
#endif
    
    CGSize _cachedSize;
}

- initWithString:(NSString *)string;
- initWithAttributedString:(NSAttributedString *)attributedString;

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (void)useEffectiveScale:(CGFloat)effectiveScale;
#endif


@property(readonly,nonatomic) NSUInteger length;
@property(copy,nonatomic) NSString *stringValue;
@property(copy,nonatomic) NSAttributedString *attributedString;

- (id)attributeForKey:(NSString *)name;
- (void)setAttribute:(id)value forKey:(NSString *)key;

@property(copy,nonatomic) OQColor *color;
@property(assign,nonatomic) CGFloat fontSize;
@property(copy,nonatomic) OAFontDescriptor *fontDescriptor;

- (CGSize)size;
- (void)resetSizeCache;

- (void)drawAtPoint:(CGPoint)pt baselineRotatedByDegrees:(CGFloat)degrees;

@end

