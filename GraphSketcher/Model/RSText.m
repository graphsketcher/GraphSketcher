// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSText.m 200244 2013-12-10 00:11:55Z correia $

#import "RSText.h"

#import <OmniQuartz/OQColor.h>
#import <OmniAppKit/OAFontDescriptor.h>
#import <OmniAppKit/OATextAttributes.h>
#import <OmniFoundation/NSMutableAttributedString-OFExtensions.h>
#import <GraphSketcherModel/OFPreference-RSExtensions.h>

#import "NSAttributedString-OSExtensions.h"

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE

#import <AppKit/NSAttributedString.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSStringDrawing.h>
static const NSUInteger RS_STRING_DRAWING_OPTIONS = NSStringDrawingUsesLineFragmentOrigin;

#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSAffineTransform.h>

#else

#import <OmniUI/OUITextLayout.h>

#endif

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSText.m 200244 2013-12-10 00:11:55Z correia $");

static OAFontDescriptorPlatformFont _getDefaultFont(void)
{
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    return [UIFont fontWithName:@"Gill Sans" size:20]; // No Lucida on the iPad
#else
    return [NSFont fontWithName:@"LucidaGrande" size:12];
#endif
}

NSDictionary *RSTextAttributesMake(OAFontDescriptor *fontDescriptor, OQColor *color)
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    
    if (!fontDescriptor)
        fontDescriptor = [[OFPreferenceWrapper sharedPreferenceWrapper] fontDescriptorForKey:@"DefaultLabelFont"];

    OAFontDescriptorPlatformFont font = [fontDescriptor font];
    if (!font)
        font = _getDefaultFont();
    if (font)
        [attributes setObject:font forKey:NSFontAttributeName];

    if (!color)
        color = [OQColor colorForPreferenceKey:@"DefaultTextColor"];
    if (color)
        [attributes setObject:color.toColor forKey:NSForegroundColorAttributeName];

    return attributes;
}

@implementation RSText

- initWithString:(NSString *)string;
{
    if (!string)
        string = @"";

    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string];
    self = [self initWithAttributedString:attributedString];
    [attributedString release];
    
    return self;
}

// Designated initializer
- initWithAttributedString:(NSAttributedString *)attributedString;
{
    if (!(self = [super init]))
        return nil;
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    _effectiveScale = 1; // until told otherwise.
#endif
    
    _cachedSize = CGSizeZero;
    
    _attributedString = attributedString ? [attributedString mutableCopy] : [[NSMutableAttributedString alloc] init];
    OBPOSTCONDITION([_attributedString string] != nil);
    
    return self;
}

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE

- (void)useEffectiveScale:(CGFloat)effectiveScale;
{
    if (_effectiveScale == effectiveScale)
        return;
    _effectiveScale = effectiveScale;
    [self _clearTextLayout];
}

#endif

- (void)dealloc;
{
    [_originalXML release];
    [_attributedString release];
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    [self _clearTextLayout];
#endif
    [super dealloc];
}

- (NSUInteger)length;
{
    return [_attributedString length];
}

- (NSString *)stringValue;
{
    return [_attributedString string];
}

- (void)setStringValue:(NSString *)stringValue;
{
    if (!stringValue)
        stringValue = @"";
    
    if (OFISEQUAL(stringValue, [_attributedString string]))
        return;
    
    [self _changed];
    
    NSRange range = NSMakeRange(0, [_attributedString length]);

    // Use the attributes at the start position, if any. Otherwise, use default attributes (if we have an empty string right now).
    NSDictionary *attributes;
    if (range.length)
        attributes = [[[_attributedString attributesAtIndex:range.location effectiveRange:NULL] retain] autorelease]; // call below might zombie them..
    else
        attributes = RSTextAttributesMake(nil, nil);
    
    [_attributedString replaceCharactersInRange:range withString:stringValue];
    [_attributedString setAttributes:attributes range:NSMakeRange(0, [stringValue length])];

    OBPOSTCONDITION([_attributedString string] != nil);
}

- (NSAttributedString *)attributedString;
{
    return _attributedString;
}

- (void)setAttributedString:(NSAttributedString *)attributedString;
{
    if ([_attributedString isEqualToAttributedString:attributedString])
        return;

    [self _changed];
    
    [_attributedString release];
    _attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];

    OBPOSTCONDITION([_attributedString string] != nil);
}

- (id)attributeForKey:(NSString *)name;
{
    if (!_attributedString || ![_attributedString length])
        return nil;
    
    return [_attributedString attribute:name atIndex:0 effectiveRange:NULL];
}

- (void)setAttribute:(id)value forKey:(NSString *)key;
{
#if defined(OMNI_ASSERTIONS_ON) && defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if (OFISEQUAL(key, NSForegroundColorAttributeName)) {
        OBASSERT(!value || [value isKindOfClass:[UIColor class]]);
    }
#endif

    [self _changed];

    [_attributedString addAttribute:key value:value range:NSMakeRange(0, [_attributedString length])];
}

- (OQColor *)color;
{
    if (![_attributedString length])
	return nil;
    
    id rawColor = [_attributedString attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
    OQColor *color = nil;
    
    if (rawColor) {
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        OBASSERT([rawColor isKindOfClass:[UIColor class]]);
        color = [OQColor colorWithPlatformColor:rawColor];
#else
        color = [OQColor colorWithPlatformColor:rawColor];
#endif
    }
    if (!color)
        color = [OQColor blackColor]; // The default for NSForegroundColorAttributeName

    return color;
}

- (void)setColor:(OQColor *)color;
{
    [self _changed];

    // TODO: Instead of using kCTForegroundColor... and OAForegroundColor... take addAttribute: out of the #if defined and use OSOriginalOAForegroundColorAttributeName
    // <bug:///76344> (Fix build error that occurs when OSOriginalOAForegroundColorAttributeName is mentioned)
    [_attributedString addAttribute:NSForegroundColorAttributeName  value:color.toColor
                              range:NSMakeRange(0, [_attributedString length])];
}

- (CGFloat)fontSize;
{
    if (![_attributedString length])
	return 0; // TODO: return the default font? Use a base style?
    
    // TODO: Store the originally requested font descriptor like we do for OSStyledTextStorage?
    OAFontDescriptorPlatformFont font = (OAFontDescriptorPlatformFont)[_attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    if (!font)
	return 0; // TODO: return the default font? Use a base style?
    
    return [font pointSize];
}

- (void)setFontSize:(CGFloat)fontSize;
{
    [self _changed];

    NSRange mutationRange = NSMakeRange(0, [_attributedString length]);
    
    [_attributedString mutateRangesInRange:mutationRange matchingString:nil with:^NSAttributedString *(NSMutableAttributedString *source, NSDictionary *attributes, NSRange matchRange, NSRange effectiveAttributeRange, BOOL *isEditing) {
        {
            // 1 for full superscript, -1 for full subscript. Unclear what 0.5 does, if anything.
            NSNumber *superScriptNumber = [attributes objectForKey:OASuperscriptAttributeName];
            BOOL isSuper = superScriptNumber && ([superScriptNumber doubleValue] != 0);
            
            OAFontDescriptor *oldFontDescriptor = [source attribute:(id)OAFontDescriptorAttributeName atIndex:effectiveAttributeRange.location effectiveRange:NULL];
            if (!oldFontDescriptor) {
                OAFontDescriptorPlatformFont oldFont = (OAFontDescriptorPlatformFont)[source attribute:NSFontAttributeName atIndex:effectiveAttributeRange.location effectiveRange:NULL];
                if (oldFont)
                    oldFontDescriptor = [[[OAFontDescriptor alloc] initWithFont:oldFont] autorelease];
                else {
                    oldFontDescriptor = [[OFPreferenceWrapper sharedPreferenceWrapper] fontDescriptorForKey:@"DefaultLabelFont"];
                }
            }
            
            // if this range is a super- or subscript, make the actual font size smaller:
            CGFloat fontScale = isSuper ? (2.0f/3.0f) : 1.0f;
            OAFontDescriptor *resultFontDescriptor = [oldFontDescriptor newFontDescriptorWithSize:fontScale*fontSize];
            OAFontDescriptorPlatformFont fontForRange = [resultFontDescriptor font];
            
            if (!*isEditing) {
                *isEditing = YES;
                [source beginEditing];
            }
            [source addAttribute:NSFontAttributeName value:fontForRange range:effectiveAttributeRange];
            [source addAttribute:OAFontDescriptorAttributeName value:resultFontDescriptor range:effectiveAttributeRange];
            [resultFontDescriptor release];
            
            return nil; // caller shouldn't replace anything; we did all the work.
        }
    }];
}

- (OAFontDescriptor *)fontDescriptor;
{
    if (![_attributedString length])
	return nil; // TODO: return the default font? Use a base style?
    
    // TODO: Store the originally requested font descriptor like we do for OSStyledTextStorage?
    OAFontDescriptorPlatformFont font = (OAFontDescriptorPlatformFont)[_attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    return [[[OAFontDescriptor alloc] initWithFont:font] autorelease];
}

- (void)setFontDescriptor:(OAFontDescriptor *)newFontDescriptor;
{
    [self _changed];

    NSRange mutationRange = NSMakeRange(0, [_attributedString length]);

    [_attributedString mutateRangesInRange:mutationRange matchingString:nil with:^NSAttributedString *(NSMutableAttributedString *source, NSDictionary *attributes, NSRange matchRange, NSRange effectiveAttributeRange, BOOL *isEditing) {

        // 1 for full superscript, -1 for full subscript. Unclear what 0.5 does, if anything.
        NSNumber *superScriptNumber = [attributes objectForKey:OASuperscriptAttributeName];
        BOOL isSuper = superScriptNumber && ([superScriptNumber doubleValue] != 0);
        
        // if this range is a super- or subscript, make the actual font size smaller:
        OAFontDescriptorPlatformFont fontForRange = NULL;
        OAFontDescriptor *smallerFontDescriptor = nil;
        if (isSuper) {
            smallerFontDescriptor = [newFontDescriptor newFontDescriptorWithSize:[newFontDescriptor size]*2/3];
            fontForRange = [smallerFontDescriptor font];
        }
        if (!fontForRange)
            fontForRange = [newFontDescriptor font];
        
        if (!*isEditing) {
            *isEditing = YES;
            [source beginEditing];
        }
        [source addAttribute:NSFontAttributeName value:fontForRange range:effectiveAttributeRange];
        [source addAttribute:OAFontDescriptorAttributeName value:newFontDescriptor range:effectiveAttributeRange];
        [smallerFontDescriptor release]; // wait to release this to avoid losing the CTFontRef
        
        return nil; // caller shouldn't replace anything; we did all the work.
    }];
}

- (CGSize)_nonWrappingSize;
{
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    CGSize bigSize = CGSizeMake(10000, 10000);
    CGRect boundingRect = [_attributedString boundingRectWithSize:bigSize options:RS_STRING_DRAWING_OPTIONS];
    return boundingRect.size;
#else
    if (_textLayout == nil) {
        [self _makeTextLayout];
        if (_textLayout == nil)
            return CGSizeMake(0.0f, 0.0f);
    }
    return _textLayout.usedSize;
#endif
}

- (CGSize)size;
{
    if ( CGSizeEqualToSize(_cachedSize, CGSizeZero) ) {
        _cachedSize = [self _nonWrappingSize];
    }
    return _cachedSize;
}

- (void)resetSizeCache;
{
    _cachedSize = CGSizeZero;
}

- (void)drawAtPoint:(CGPoint)pt baselineRotatedByDegrees:(CGFloat)degrees;
{
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    [self _makeTextLayout];
    if (!_textLayout)
        return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(ctx);
    {        
        if (0) {
            CGSize usedSize = _textLayout.usedSize;
            
            [[UIColor redColor] set];
            CGContextStrokeRect(ctx, CGRectMake(pt.x, pt.y, usedSize.width, usedSize.height));
        }
        
        CGContextTranslateCTM(ctx, pt.x, pt.y);
        if (degrees != 0)
            CGContextRotateCTM(ctx, degrees * (2*M_PI/360));
        
        [_textLayout drawInContext:ctx];
        
    }
    CGContextRestoreGState(ctx);
#else
    if (degrees) {
	[NSGraphicsContext saveGraphicsState];
	NSAffineTransform *AT = [NSAffineTransform transform];
	[AT translateXBy:pt.x yBy:pt.y];
	[AT rotateByDegrees:degrees];
	[AT concat];
        
        // width of 0 means "no maximum width"
        [_attributedString drawWithRect:CGRectMake(0, 0, 0, 0) options:RS_STRING_DRAWING_OPTIONS];

	[NSGraphicsContext restoreGraphicsState];
    } else {
        if (0) {
            CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
            [[NSColor redColor] set];
            CGSize size = [self size];
            CGContextStrokeRect(ctx, CGRectMake(pt.x, pt.y, size.width, size.height));
        }

	//[attributedString drawAtPoint:p];
        // width of 0 means "no maximum width"
        [_attributedString drawWithRect:CGRectMake(pt.x, pt.y, 0, 0) options:RS_STRING_DRAWING_OPTIONS];
    }
#endif
}

#pragma mark - Private

- (void)_changed;
{
    [_originalXML release];
    _originalXML = nil;

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    [self _clearTextLayout];
#endif
    
    _cachedSize = CGSizeZero;
}

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE

- (void)_clearTextLayout;
{
    [_textLayout release];
    _textLayout = nil;
    
    _cachedSize = CGSizeZero;
}

const CGSize RSTextLayoutContraints = {5000, 100000};

- (void)_makeTextLayout;
{
    if (_textLayout || !_attributedString || [_attributedString length] == 0)
        return;
    
    OBASSERT([_attributedString string] != nil);

    // CoreText *does* obey non-integral font sizes (nice), but UITextView doesn't (boo). So if we want to render with CoreText to get styled text and edit with UITextView, we have to make our effective font sizes be integral (via floor to avoid growing).
    NSAttributedString *layoutAttributedString;
    if (_effectiveScale > 0 && _effectiveScale != 1.0) {
        NSMutableAttributedString *integralAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:_attributedString];
        NSRange mutationRange = NSMakeRange(0, [integralAttributedString length]);
        
        [integralAttributedString mutateRangesInRange:mutationRange matchingString:nil with:^NSAttributedString *(NSMutableAttributedString *source, NSDictionary *attributes, NSRange matchRange, NSRange effectiveAttributeRange, BOOL *isEditing) {
            UIFont *font = [source attribute:NSFontAttributeName atIndex:effectiveAttributeRange.location longestEffectiveRange:NULL inRange:matchRange];
            if (!font)
                font = _getDefaultFont();
            
            CGFloat pointSize = [font pointSize];
            //NSLog(@"  pointSize %f", pointSize);
            
            CGFloat effectiveSize = pointSize / _effectiveScale;
            //NSLog(@"  effectiveSize %f", effectiveSize);
            
            CGFloat snapped = floor(effectiveSize);
            //NSLog(@"  snapped %f", snapped);
            
            CGFloat scaled = snapped * _effectiveScale;
            //NSLog(@"  scaled %f", scaled);
            
            UIFont *scaledFont = [font fontWithSize:scaled];
            
            [source addAttribute:NSFontAttributeName value:scaledFont range:effectiveAttributeRange];
            
            return nil; // replaced attributes in place.
        }];

        layoutAttributedString = integralAttributedString;
    } else {
        layoutAttributedString = [_attributedString retain];
    }
    
    // Apply superscript and other fix-ups
    NSAttributedString *transformedString = OUICreateTransformedAttributedString(layoutAttributedString, nil);
    if (!transformedString)
        transformedString = [layoutAttributedString copy];
    
    _textLayout = [[OUITextLayout alloc] initWithAttributedString:(NSAttributedString *)transformedString constraints:RSTextLayoutContraints];
    [transformedString release];
    [layoutAttributedString release];
}    

#endif

@end
