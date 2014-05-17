// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSStyle-AttributeExtensions.h"

#import "OSStyle-Internal.h"
#import "OSNumberStyleAttribute.h"
#import "OSBoolStyleAttribute.h"
#import "OSColorStyleAttribute.h"
#import "OSEnumStyleAttribute.h"
#import "OSVectorStyleAttribute.h"
#import "OSNumberStyleAttribute.h"
#import "OSStringStyleAttribute.h"
#import <OmniAppKit/OAFontDescriptor.h>
#import <OmniFoundation/NSNumber-OFExtensions-CGTypes.h>
#import <OmniFoundation/OFEnumNameTable.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#import <OmniAppKit/NSFontManager-OAExtensions.h>
//#import "OSStyledTextStorage.h"
#else
#import <OmniQuartz/OQColor.h>
#endif

#import <OmniBase/OmniBase.h>

RCS_ID("$Header$");

@implementation OSStyle (AttributeExtensions)

static NSArray *defaultTabStops(void)
{
    static NSArray *cache = nil;
    if (!cache)
        cache = [[[NSParagraphStyle defaultParagraphStyle] tabStops] retain];
    return cache;
}

static NSString *defaultTabStopStringCache;

static NSString *defaultTabStopString(void)
{
    static NSString *defaultTabStopStringCache = nil;
    if (!defaultTabStopStringCache)
        defaultTabStopStringCache = [[OSStyle stringForTabStops:defaultTabStops()] copy];
    return defaultTabStopStringCache;
}

// Avoid autoreleases
static void _setFloat(OSStyle *style, CGFloat value, OSNumberStyleAttribute *attribute)
{
    // Clipping/copying RTF from Safari can give bizarro values.  Clamp to the allowed range.  <bug://bugs/43574> (Clipping the entire Apple start page crashes)
    OFExtent valueExtent = [attribute valueExtent];
    if (value < valueExtent.location)
        value = valueExtent.location;
    else if (value >= valueExtent.location + valueExtent.length)
        value = valueExtent.location + valueExtent.length;
    
    NSNumber *number = [[NSNumber alloc] initWithCGFloat:value];
    [style setValue:number forAttribute:attribute];
    [number release];
}

static void _setInt(OSStyle *style, NSInteger value, OSStyleAttribute *attribute)
{
    NSNumber *number = [[NSNumber alloc] initWithInteger:value];
    [style setValue:number forAttribute:attribute];
    [number release];
}

- (CGFloat)fontSize;
{
    return [[self valueForAttribute:OSFontSizeStyleAttribute] cgFloatValue];
}

- (void)setFontSize:(CGFloat)fontSize;
{
    _setFloat(self, fontSize, OSFontSizeStyleAttribute);
}

- (OAPlatformFontClass *)font;
{
    OAFontDescriptor *descriptor = [self newFontDescriptor];
    OAPlatformFontClass *font = [[[descriptor font] retain] autorelease];
    [descriptor release];
    return font;
}

- (OAFontDescriptor *)newFontDescriptor;
{
    OBASSERT_IF([self styleDefiningAttributeKey:OSFontNameStyleAttribute.key], ![self isKindOfClass:[_OSFlattenedStyle class]], "We need to know the relative positioning of font name vs other attributes, which we can't once a style has been flattened");
    
    // Don't look up the actual name yet; might be nothing and we don't want to get the default value back spuriously
    OSStyle *nameStyle = [self styleDefiningAttributeKey:OSFontNameStyleAttribute.key];

    if (nameStyle) {
        // An explicit font face has been defined. Use that, plus any extra attributes that are specified from that point in the cascade/inheritance chain (including local attributes on that style).
        OAFontDescriptor *fontDescriptor = [[OAFontDescriptor alloc] initWithName:[nameStyle valueForAttribute:OSFontNameStyleAttribute] size:self.fontSize];
        
        NSString *family = [self valueForAttributeKey:OSFontFamilyNameStyleAttribute.key stoppingAtStyle:nameStyle];
        NSString *weightNumber = [self valueForAttributeKey:OSFontWeightStyleAttribute.key stoppingAtStyle:nameStyle];
        NSString *italicNumber = [self valueForAttributeKey:OSFontItalicStyleAttribute.key stoppingAtStyle:nameStyle];
        NSString *condensedNumber = [self valueForAttributeKey:OSFontCondensedStyleAttribute.key stoppingAtStyle:nameStyle];
        NSString *fixedPitchNumber = [self valueForAttributeKey:OSFontFixedPitchStyleAttribute.key stoppingAtStyle:nameStyle];
        
        // If any of these is set *and* different from the font's derived value, we need to reconsider.
        if ((family && ![family isEqual:fontDescriptor.family]) ||
            (weightNumber && [weightNumber integerValue] != fontDescriptor.weight) ||
            (italicNumber && ([italicNumber boolValue] ^ fontDescriptor.italic)) ||
            (condensedNumber && ([condensedNumber boolValue] ^ fontDescriptor.condensed)) ||
            (fixedPitchNumber && ([fixedPitchNumber boolValue] ^ fontDescriptor.fixedPitch))) {

            family = family ?: fontDescriptor.family;
            NSInteger weight = weightNumber ? [weightNumber integerValue] : fontDescriptor.weight;
            BOOL italic = italicNumber ? [italicNumber boolValue] : fontDescriptor.italic;
            BOOL condensed = condensedNumber ? [condensedNumber boolValue] : fontDescriptor.condensed;
            BOOL fixedPitch = fixedPitchNumber ? [fixedPitchNumber boolValue] : fontDescriptor.fixedPitch;

            [fontDescriptor release];
            return [[OAFontDescriptor alloc] initWithFamily:family size:self.fontSize weight:weight italic:italic condensed:condensed fixedPitch:fixedPitch];
        }

        return fontDescriptor;
    } else {
        NSString *family = [self valueForAttribute:OSFontFamilyNameStyleAttribute];
        NSInteger weight = [[self valueForAttribute:OSFontWeightStyleAttribute] integerValue];
        BOOL italic = [[self valueForAttribute:OSFontItalicStyleAttribute] boolValue];
        BOOL condensed = [[self valueForAttribute:OSFontCondensedStyleAttribute] boolValue];
        BOOL fixedPitch = [[self valueForAttribute:OSFontFixedPitchStyleAttribute] boolValue];
        
        return [[OAFontDescriptor alloc] initWithFamily:family size:self.fontSize weight:weight italic:italic condensed:condensed fixedPitch:fixedPitch];
    }
}

- (void)setFontDescriptor:(OAFontDescriptor *)fontDescriptor;
{
    [self setValue:[fontDescriptor family] forAttribute:OSFontFamilyNameStyleAttribute];
    
    // Don't promote the calculated font name to an explicitly desired font name.
    [self setValue:fontDescriptor.desiredFontName forAttribute:OSFontNameStyleAttribute];
    
    self.fontSize = [fontDescriptor size];
    if ([fontDescriptor hasExplicitWeight]) {
        // We only set the style's font weight from the descriptor if the descriptor has an explicit weight. Unlike the other attributes below, font weight can be "rounded" to one of the weights available for the family. If we set the rounded weight on the style and it doesn't match an inherited weight, we'll fail to detect that it's redundant. <bug:///85457> (Text insertion style is wrong for row with named style using unsupported font weight)
        _setInt(self, [fontDescriptor weight], OSFontWeightStyleAttribute);
    }
    [self setValue:[NSNumber numberWithBool:[fontDescriptor italic]] forAttribute:OSFontItalicStyleAttribute];
    [self setValue:[NSNumber numberWithBool:[fontDescriptor condensed]] forAttribute:OSFontCondensedStyleAttribute];
    [self setValue:[NSNumber numberWithBool:[fontDescriptor fixedPitch]] forAttribute:OSFontFixedPitchStyleAttribute];

    OBPOSTCONDITION(OFISEQUAL([[[self newFontDescriptor] autorelease] font], [fontDescriptor font]));
}

- (NSMutableParagraphStyle *)newParagraphStyle;
{
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setLineSpacing:[[self valueForAttribute:OSParagraphLineSpacingStyleAttribute] cgFloatValue]];
    [paragraphStyle setParagraphSpacing:[[self valueForAttribute:OSParagraphSpacingStyleAttribute] cgFloatValue]];
    [paragraphStyle setAlignment:[[OSParagraphAlignmentStyleAttribute enumTable] enumForName:[self valueForAttribute:OSParagraphAlignmentStyleAttribute]]];
    [paragraphStyle setFirstLineHeadIndent:[[self valueForAttribute:OSParagraphFirstLineHeadIndentStyleAttribute] cgFloatValue]];
    [paragraphStyle setHeadIndent:[[self valueForAttribute:OSParagraphHeadIndentStyleAttribute] cgFloatValue]];
    [paragraphStyle setTailIndent:-[[self valueForAttribute:OSParagraphTailIndentStyleAttribute] cgFloatValue]];
    [paragraphStyle setMinimumLineHeight:[[self valueForAttribute:OSParagraphMinimumLineHeightStyleAttribute] cgFloatValue]];
    [paragraphStyle setMaximumLineHeight:[[self valueForAttribute:OSParagraphMaximumLineHeightStyleAttribute] cgFloatValue]];
    [paragraphStyle setLineHeightMultiple:[[self valueForAttribute:OSParagraphLineHeightMultipleStyleAttribute] cgFloatValue]];
    [paragraphStyle setParagraphSpacingBefore:[[self valueForAttribute:OSParagraphSpacingBeforeStyleAttribute] cgFloatValue]];
    
    [paragraphStyle setTabStops:[OSStyle tabStopsForString:[self valueForAttribute:OSParagraphTabStopsStyleAttribute]]];
    [paragraphStyle setDefaultTabInterval:[[self valueForAttribute:OSParagraphDefaultTabIntervalStyleAttribute] cgFloatValue]];
    
    OFEnumNameTable *writingDirectionTable = [OSParagraphBaseWritingDirectionStyleAttribute enumTable];
    NSWritingDirection writingDirection = [writingDirectionTable enumForName:[self valueForAttribute:OSParagraphBaseWritingDirectionStyleAttribute]];
    [paragraphStyle setBaseWritingDirection:writingDirection];
    
    return paragraphStyle;
}

- (void)setParagraphStyle:(NSParagraphStyle *)paragraphStyle;
{
    _setFloat(self, [paragraphStyle lineSpacing], OSParagraphLineSpacingStyleAttribute);
    _setFloat(self, [paragraphStyle paragraphSpacing], OSParagraphSpacingStyleAttribute);
    [self setValue:[[OSParagraphAlignmentStyleAttribute enumTable] nameForEnum:[paragraphStyle alignment]] forAttribute:OSParagraphAlignmentStyleAttribute];
    _setFloat(self, [paragraphStyle firstLineHeadIndent], OSParagraphFirstLineHeadIndentStyleAttribute);
    _setFloat(self, [paragraphStyle headIndent], OSParagraphHeadIndentStyleAttribute);
    _setFloat(self, -[paragraphStyle tailIndent], OSParagraphTailIndentStyleAttribute);
    _setFloat(self, [paragraphStyle minimumLineHeight], OSParagraphMinimumLineHeightStyleAttribute);
    _setFloat(self, [paragraphStyle maximumLineHeight], OSParagraphMaximumLineHeightStyleAttribute);
    _setFloat(self, [paragraphStyle lineHeightMultiple], OSParagraphLineHeightMultipleStyleAttribute);
    _setFloat(self, [paragraphStyle paragraphSpacingBefore], OSParagraphSpacingBeforeStyleAttribute);
    
    [self setValue:[OSStyle stringForTabStops:[paragraphStyle tabStops]] forAttribute:OSParagraphTabStopsStyleAttribute];
    _setFloat(self, [paragraphStyle defaultTabInterval], OSParagraphDefaultTabIntervalStyleAttribute);
    
    NSWritingDirection writingDirection = [paragraphStyle baseWritingDirection];
    [self setValue:[[OSParagraphBaseWritingDirectionStyleAttribute enumTable] nameForEnum:writingDirection] forAttribute:OSParagraphBaseWritingDirectionStyleAttribute];
    
    [self removeRedundantValues];
}

+ (NSString *)stringForTabStops:(NSArray *)tabStops
{
    // This method gets called to initialize defaultTabStopString, so don't short-circuit if it isn't initialized
    if (defaultTabStopStringCache && [defaultTabStops() isEqual:tabStops])
        return defaultTabStopString();
    
    NSMutableString *str = [NSMutableString string];
    NSUInteger tabStopIndex, tabStopCount = [tabStops count];
    
    for (tabStopIndex = 0; tabStopIndex < tabStopCount; tabStopIndex++) {
        NSTextTab *textTab = [tabStops objectAtIndex:tabStopIndex];
        
        if (tabStopIndex != 0)
            [str appendString:@","];
        
        [str appendFormat:@"%g", [textTab location]];
        
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        switch ([textTab alignment]) {
            case NSTextAlignmentRight:
                [str appendString:@"R"];
                break;
                
            case NSTextAlignmentCenter:
                [str appendString:@"C"];
                break;
                
                // <bug:///94056> (Handle decimal tab stops)
#if 0
            case NSDecimalTabStopType:
                [str appendString:@"D"];
                break;
#endif
                
            case NSTextAlignmentLeft:
            default:
                [str appendString:@"L"];
                break;
        }
#else
        switch ([textTab tabStopType]) {
            case NSRightTabStopType:
                [str appendString:@"R"];
                break;
                
            case NSCenterTabStopType:
                [str appendString:@"C"];
                break;
                
            case NSDecimalTabStopType:
                [str appendString:@"D"];
                break;
                
            case NSLeftTabStopType:
            default:
                [str appendString:@"L"];
                break;
        }
#endif
    }
    
    return str;
}

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
static NSTextAlignment _OSTextTabAlignmentFromString(NSString *str)
{
    if ([@"R" isEqual:str] == YES) {
        return NSTextAlignmentRight;
    } else if ([@"C" isEqual:str] == YES) {
        return NSTextAlignmentCenter;
    } else if ([@"D" isEqual:str] == YES) {
        return NSTextAlignmentRight;
    } else if ([@"L" isEqual:str] == YES) {
        return NSTextAlignmentLeft;
    }
    
    return NSTextAlignmentLeft;
}
static NSDictionary *_OSTextTabOptionsFromString(NSString *str)
{
    if ([@"D" isEqual:str]) {
        OBFinishPortingLater("Handle decimal tabs");
    }
    return nil;
}
#else
static NSTextTabType _OSTextTabTypeFromString(NSString *str)
{
    if ([@"R" isEqual:str] == YES) {
        return NSRightTabStopType;
    } else if ([@"C" isEqual:str] == YES) {
        return NSCenterTabStopType;
    } else if ([@"D" isEqual:str] == YES) {
        return NSDecimalTabStopType;
    } else if ([@"L" isEqual:str] == YES) {
        return NSLeftTabStopType;
    }
    
    return NSLeftTabStopType;
}
#endif

+ (NSArray *)tabStopsForString:(NSString *)string;
{
    // The NSScanner is fairly expensive in terms of autoreleases and such; avoid this in the (vastly) common case
    if ([string isEqualToString:defaultTabStopString()])
        return defaultTabStops();
    
    NSMutableArray *tabStops;
    NSScanner      *scanner;
    BOOL            isFirst;
    
    tabStops = [NSMutableArray array];
    scanner = [[NSScanner alloc] initWithString:string];
    isFirst = YES;
    
    while ([scanner isAtEnd] == NO) {
        int position;
        NSString *alignmentString;
        
        if (isFirst == YES) {
            isFirst = NO;
        } else {
            if ([scanner scanString:@"," intoString:NULL] == NO) {
                NSLog(@"Expected ',' when parsing tab stop list");
                break;
            }
        }
        
        if ([scanner scanInt:&position] == YES) {
            if ([scanner scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&alignmentString] == YES) {
                
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
                NSTextTab *textTab = [[NSTextTab alloc] initWithTextAlignment:_OSTextTabAlignmentFromString(alignmentString) location:position options:_OSTextTabOptionsFromString(alignmentString)];
#else
                NSTextTab *textTab = [[NSTextTab alloc] initWithType:_OSTextTabTypeFromString(alignmentString) location:position];
#endif
                [tabStops addObject:textTab];
                [textTab release];
            } else {
                break;
            }
        } else {
            break;
        }
    }
    
    [scanner release];
    return tabStops;
}

@end
