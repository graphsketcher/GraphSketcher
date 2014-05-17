// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSAttributedString-OSExtensions.h"

#import "OSStyle.h"
#import "OSStyle-AttributeExtensions.h"
#import "OSBoolStyleAttribute.h"
#import "OSColorStyleAttribute.h"
#import "OSEnumStyleAttribute.h"
#import "OSNumberStyleAttribute.h"
#import "OSStringStyleAttribute.h"
#import "OSVectorStyleAttribute.h"
#import "OSURLStyleAttribute.h"
#import "OSStyleContext.h"
#import "OSStyledTextStorage-XML.h"
#import <OmniAppKit/NSAttributedString-OAExtensions.h>
#import <OmniAppKit/OATextStorage.h>
#import <OmniAppKit/OAFontDescriptor.h>
#import <OmniAppKit/OATextAttributes.h>
#import <OmniFoundation/NSNumber-OFExtensions-CGTypes.h>
#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/NSMutableAttributedString-OFExtensions.h>
#import <OmniFoundation/OFEnumNameTable.h>
#import <OmniFoundation/OFPoint.h>
#import <OmniQuartz/OQColor.h>

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#import <UIKit/UIColor.h>
#else
#import <AppKit/AppKit.h>
#endif

#import <OmniBase/rcsid.h>

RCS_ID("$Header$");

// This is used in text attribute dictionaries to hold an array of named styles (not their names; the actual styles).
NSString * const OSInheritedStylesAttributeName = @"OSInheritedStyles";

#define OS_DEFINE_ORIGINAL_COLOR_KEY(key) \
NSString * const OSOriginal ## key = @"OSOriginal" @#key

OS_DEFINE_ORIGINAL_COLOR_KEY(NSForegroundColorAttributeName);
OS_DEFINE_ORIGINAL_COLOR_KEY(NSBackgroundColorAttributeName);
OS_DEFINE_ORIGINAL_COLOR_KEY(NSStrokeColorAttributeName);
OS_DEFINE_ORIGINAL_COLOR_KEY(NSUnderlineColorAttributeName);
OS_DEFINE_ORIGINAL_COLOR_KEY(NSStrikethroughColorAttributeName);

#undef OS_DEFINE_ORIGINAL_COLOR_KEY


#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE // This class doesn't exist on the iPad, and even if it did it would be private
@interface NSAttributeDictionary : NSDictionary
+ (NSDictionary *)newWithDictionary:(NSDictionary *)dict;
@end
#endif

static NSDictionary *OSCopyUniquedTextAttributeDictionary(NSDictionary *dict) NS_RETURNS_RETAINED;
static NSDictionary *OSCopyUniquedTextAttributeDictionary(NSDictionary *dict)
{
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    static dispatch_once_t onceToken;
    static Class NSAttributeDictionaryClass = Nil;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"NSAttributeDictionary");
        if (cls && [cls respondsToSelector:@selector(newWithDictionary:)]) {
            NSAttributeDictionaryClass = cls;
        } else {
            OBASSERT_NOT_REACHED("NSAttributeDictionary's private API has changed!");
        }
    });
    
    if (NSAttributeDictionaryClass)
        return [NSAttributeDictionary newWithDictionary:dict];
    // otherwise fall through...
#endif
    return [dict copy];
}

@implementation NSAttributedString (OSExtensions)

// Avoid autoreleases
static void _setFloatDict(NSMutableDictionary *dict, CGFloat value, NSString *key)
{
    NSNumber *number = [[NSNumber alloc] initWithCGFloat:value];
    [dict setObject:number forKey:key];
    [number release];
}

static void _setUnsignedDict(NSMutableDictionary *dict, NSUInteger value, NSString *key)
{
    NSNumber *number = [[NSNumber alloc] initWithUnsignedInteger:value];
    [dict setObject:number forKey:key];
    [number release];
}

static void _setFloatStyle(OSStyle *style, CGFloat value, OSStyleAttribute *attribute)
{
    NSNumber *number = [[NSNumber alloc] initWithCGFloat:value];
    [style setValue:number forAttribute:attribute];
    [number release];
}

static inline id _lookupAttribute(NSString *key, NSDictionary *first, NSDictionary *second)
{
    id value;
    
    if ((value = [first objectForKey:key]))
        return value;
    
    value = [second objectForKey:key];
    
    // Attachment can be nil since it is an internal attribute that should never get pushed to a cascade style.  Links can be nil too since we have a default URL of "" and avoid setting that on the text storage attributes.
    // If *any* other attribute is missing, constructing a style based on a cascade style may result in an incorrect style (since we'd return nil here meaning to use the parent value when really we want to use the default value, but we don't have a default registered!).  See <bug://bugs/23033>
#ifdef OMNI_ASSERTIONS_ON
    if (!value && ![key isEqualToString:NSAttachmentAttributeName] && ![key isEqualToString:NSLinkAttributeName])
	NSLog(@"No default attribute registered for '%@'!", key);
#endif
    OBPOSTCONDITION(value || [key isEqualToString:NSAttachmentAttributeName] || [key isEqualToString:NSLinkAttributeName]);
    
    return value;
}

static NSDictionary *OSDefaultTextAttributes(void)
{
    // If the input text attributes don't have a value, we want to use the same default we'd get from an empty style
    static NSDictionary *defaultTextAttributes = nil;
    if (!defaultTextAttributes) {
        // TODO: Later we need to think about attribute maps here.
	
        NSUndoManager *undoManager = [[NSUndoManager alloc] init];
        OSStyleContext *context = [[OSStyleContext alloc] initWithUndoManager:undoManager identifierRegistry:nil];
        [undoManager release];
        
        OSStyle *style = [[OSStyle alloc] initWithContext:context];
        
	NSMutableDictionary *attributes = [[[NSAttributedString copyTextAttributesFromStyle:style] autorelease] mutableCopy];
        
	// Set up some attributes in the default attribute dictionary that aren't filled in by +copyTextAttributesFromStyle:

	[attributes setObject:[OSKerningAdjustmentStyleAttribute defaultValue] forKey:NSKernAttributeName];
	
	NSString *enumName = [style valueForAttribute:OSLigatureSelectionStyleAttribute];
	NSUInteger enumNumber = [[OSLigatureSelectionStyleAttribute enumTable] enumForName:enumName];
	_setUnsignedDict(attributes, enumNumber, NSLigatureAttributeName);
        
        OSSetColorForTextAttribute(attributes, NSStrokeColorAttributeName, nil/*originalKey*/, [OSFontStrokeColorStyleAttribute defaultValue]);
	[attributes setObject:[OSFontStrokeWidthStyleAttribute defaultValue] forKey:NSStrokeWidthAttributeName];
	
	OSSetColorForTextAttribute(attributes, NSBackgroundColorAttributeName, nil/*originalKey*/, [OSBackgroundColorStyleAttribute defaultValue]);
        
	NSShadow *shadow = [[NSShadow alloc] init];
	CGPoint shadowOffset = [[OSShadowVectorStyleAttribute defaultValue] point];
	[shadow setShadowOffset:CGSizeMake(shadowOffset.x, shadowOffset.y)];
	[shadow setShadowBlurRadius:[[OSShadowBlurRadiusStyleAttribute defaultValue] cgFloatValue]];
	[shadow setShadowColor:[OSShadowColorStyleAttribute defaultValue]];
	[attributes setObject:shadow forKey:NSShadowAttributeName];
	[shadow release];
        
	[attributes setObject:[NSArray array] forKey:OSInheritedStylesAttributeName];
	
	defaultTextAttributes = OSCopyUniquedTextAttributeDictionary(attributes);
        [attributes release];

        [style release];
        [context invalidate];
        [context release];
    }
    
    return defaultTextAttributes;
}

// We want to look in textAttributes first and then defaultTextAttributes
#define ATTR(x) _lookupAttribute(x, textAttributes, defaultTextAttributes)

OS_COLOR_CLASS *OSColorForTextAttribute(NSDictionary *textAttributes, NSString *textKey, NSString *originalKey)
{
    NSDictionary *defaultTextAttributes = OSDefaultTextAttributes();
    
    OS_COLOR_CLASS *colorObject = nil;
    // First check for the unconverted color under the original key.
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    colorObject = [textAttributes objectForKey:originalKey];
#else
    OBASSERT([textAttributes objectForKey:originalKey] == nil); // no conversion on the Mac.
#endif
    
    if (!colorObject) {
        OQ_PLATFORM_COLOR_CLASS *colorValue = ATTR(textKey);
        OBPRECONDITION(!colorValue || [colorValue isKindOfClass:[OQ_PLATFORM_COLOR_CLASS class]]);
        
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        colorObject = [OQColor colorWithPlatformColor:colorValue];
#else
        colorObject = colorValue;
#endif
    }

    OBPRECONDITION(!colorObject || [colorObject isKindOfClass:[OS_COLOR_CLASS class]]);
    return colorObject;
}
#define COLOR_ATTR(key) OSColorForTextAttribute(textAttributes, key, OSOriginal ## key)

// Text attributes contain UIColor on the iPhone and we want OQColor.
void OSSetColorForTextAttribute(NSMutableDictionary *textAttributes, NSString *textKey, NSString *originalKey, OS_COLOR_CLASS *color)
{
    OBPRECONDITION([color isKindOfClass:[OS_COLOR_CLASS class]]);
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    // Store both the original color and the version that is converted to what CoreText can render.
    if (originalKey) // nil when we are setting up the defaults dictionary
        textAttributes[originalKey] = color;
#endif

    OQ_PLATFORM_COLOR_CLASS *colorValue = OS_COLOR_CLASS_TO_PLATFORM_COLOR(color);

    textAttributes[textKey] = colorValue;
}
#define SET_COLOR(key, color) OSSetColorForTextAttribute(textAttributes, key, OSOriginal ## key, color)

NSDictionary *OSStyledTextStorageCreateTextAttributes(OSStyle *_style)
{
    OBPRECONDITION(_style);
    
    // TODO: Use a OFMKKD here?
    NSMutableDictionary *textAttributes;
    
    textAttributes = [[NSMutableDictionary alloc] init];
    
    // This will do the 'iterate associated styles' ONCE rather than doing it once for each attribute. We can't use this for computing the font if a specific font face is declared somehwere (since -newFontDescriptor needs to know where in the cascade things are defined).
    OSStyle *style = [_style newFlattenedStyle];
    
    // Record what we originally wanted in the text attributes in case -fixFontAttributeInRange: decides that certain ranges can't be represented in the original set font and replaces it.
    BOOL hasFontNameSpecified = ([_style styleDefiningAttributeKey:OSFontNameStyleAttribute.key] != nil);
    OAFontDescriptor *fontDescriptor = [(hasFontNameSpecified ? _style : style) newFontDescriptor];
    textAttributes[OAFontDescriptorAttributeName] = fontDescriptor;
    [fontDescriptor release];
    
    // Immediately apply the derived font. This avoids needing to make edits in -fixFontAttributeInRange:, but more importantly if we create an attributed string or text storage and it never gets sent -fixFontAttributesInRange: before we use it to create *another* text storage via -initWithAttributedString:style: (which ignores styled text storage attributes since it expects a plain attributed string). For example, see <bug:///97129> (Paste and Match Style with row selection always pastes Helvetica 12)
    textAttributes[NSFontAttributeName] = fontDescriptor.font;
    
    
    NSParagraphStyle *paragraphStyle = [style newParagraphStyle];
    textAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
    [paragraphStyle release];
    
    // In AppKit/CoreText land, negative stroke width means stroke and fill. Stroke width is a percentage of the point size.
    {
        NSNumber *strokeWidth = [style valueForAttribute:OSFontStrokeWidthStyleAttribute];
        OS_COLOR_CLASS *fillColor = [style valueForAttribute:OSFontFillColorStyleAttribute];
        OS_COLOR_CLASS *strokeColor = [style valueForAttribute:OSFontStrokeColorStyleAttribute];
        
        CGFloat strokeWidthValue = [strokeWidth cgFloatValue];
        if (strokeWidthValue == 0.0f || [strokeColor isEqual:[OS_COLOR_CLASS clearColor]]) {
            // No stroke; only fill
            SET_COLOR(NSForegroundColorAttributeName, fillColor);
	} else if ([fillColor isEqual:[OS_COLOR_CLASS clearColor]]) {
	    // No fill; only stroke
	    [textAttributes setObject:strokeWidth forKey:NSStrokeWidthAttributeName];
            SET_COLOR(NSStrokeColorAttributeName, strokeColor);
        } else if (strokeWidthValue > 0.0f) {
            // Positive stroke; we send BOTH stroke and fill to AppKit (but our fill might be transparent) AND we need to make the stroke width negative to indicate to AppKit that it use both
            _setFloatDict(textAttributes, -strokeWidthValue, NSStrokeWidthAttributeName);
            SET_COLOR(NSForegroundColorAttributeName, fillColor);
            SET_COLOR(NSStrokeColorAttributeName, strokeColor);
        }
    }
    
    // We use +clearColor as our default while the text system wants nil.
    OS_COLOR_CLASS *backgroundColor = [style valueForAttribute:OSBackgroundColorStyleAttribute];
    if (![backgroundColor isEqual:[OS_COLOR_CLASS clearColor]])
        SET_COLOR(NSBackgroundColorAttributeName, backgroundColor);
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    // <bug:///94057> (Emulate superscript/subscript via baseline offset)
#else
    textAttributes[NSSuperscriptAttributeName] = [style valueForAttribute:OSBaselineSuperscriptStyleAttribute];
#endif
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    // OBFinishPortingLater("Set baseline offset text attribute.");
#else
    [textAttributes setObject:[style valueForAttribute:OSBaselineOffsetStyleAttribute] forKey:NSBaselineOffsetAttributeName];
#endif
    
    // Don't stick NaN's in the attributed string...
    // TJW: How does NaN get reported to AppleScript?
    // NOTE: Only nil and 0 are supported on iOS.
    NSNumber *kerningAdjust = [style valueForAttribute:OSKerningAdjustmentStyleAttribute];
    OBASSERT([[OSKerningAdjustmentStyleAttribute defaultValue] isEqual: [OSKerningAdjustmentStyleAttribute defaultValue]]); // NaN == NaN in this world?
    if (![kerningAdjust isEqual:[OSKerningAdjustmentStyleAttribute defaultValue]])
        [textAttributes setObject:kerningAdjust forKey:NSKernAttributeName];
    
    NSString *enumName = [style valueForAttribute:OSLigatureSelectionStyleAttribute];
    NSUInteger enumNumber = [[OSLigatureSelectionStyleAttribute enumTable] enumForName:enumName];
    if (enumNumber != 1) // The default for the text system
        _setUnsignedDict(textAttributes, enumNumber, NSLigatureAttributeName);
    
    // More stuff will get 'or'ed in with this later
    NSUInteger underlineMask;
    underlineMask = [[OSUnderlineStyleStyleAttribute enumTable] enumForName:[style valueForAttribute:OSUnderlineStyleStyleAttribute]];
    underlineMask |= [[OSUnderlinePatternStyleAttribute enumTable] enumForName:[style valueForAttribute:OSUnderlinePatternStyleAttribute]];
    if ([[OSUnderlineAffinityStyleAttribute enumTable] enumForName:[style valueForAttribute:OSUnderlineAffinityStyleAttribute]])
        underlineMask |= OAUnderlineByWordMask;
    SET_COLOR(NSUnderlineColorAttributeName, [style valueForAttribute:OSUnderlineColorStyleAttribute]);
    
    NSUInteger strikethroughMask;
    strikethroughMask = [[OSStrikethroughStyleStyleAttribute enumTable] enumForName:[style valueForAttribute:OSStrikethroughStyleStyleAttribute]];
    strikethroughMask |= [[OSStrikethroughPatternStyleAttribute enumTable] enumForName:[style valueForAttribute:OSStrikethroughPatternStyleAttribute]];
    if ([[OSStrikethroughAffinityStyleAttribute enumTable] enumForName:[style valueForAttribute:OSStrikethroughAffinityStyleAttribute]])
        strikethroughMask |= OAUnderlineByWordMask;
    _setUnsignedDict(textAttributes, underlineMask, NSUnderlineStyleAttributeName);
    _setUnsignedDict(textAttributes, strikethroughMask, NSStrikethroughStyleAttributeName);
    SET_COLOR(NSStrikethroughColorAttributeName, [style valueForAttribute:OSStrikethroughColorStyleAttribute]);
    
    NSNumber *obliqueness = [style valueForAttribute:OSObliquenessStyleAttribute];
    [textAttributes setObject:obliqueness forKey:NSObliquenessAttributeName];
    
    textAttributes[NSExpansionAttributeName] = [style valueForAttribute:OSExpansionStyleAttribute];
    
    OS_COLOR_CLASS *shadowColor = [style valueForAttribute:OSShadowColorStyleAttribute];
    if (![shadowColor isEqual:[OSShadowColorStyleAttribute defaultValue]]) {
        // Clear is the default, so if it is different, then the shadow is 'on'
        NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowColor:OS_COLOR_CLASS_TO_PLATFORM_COLOR(shadowColor)];
        [shadow setShadowBlurRadius:[[style valueForAttribute:OSShadowBlurRadiusStyleAttribute] cgFloatValue]];
        
        OFPoint *pointValue = [style valueForAttribute:OSShadowVectorStyleAttribute];
        OBASSERT(pointValue);
        if (pointValue) {
            CGPoint  point = [pointValue point];
            [shadow setShadowOffset:CGSizeMake(point.x, point.y)];
        }
        
        textAttributes[NSShadowAttributeName] = shadow;
        [shadow release];
    }
    
//    // Get the inherited styles from the original unflatted style (which won't have any named styles itself)
//    OBASSERT([[style inheritedStyles] count] == 0);
//    NSArray *inheritedStyles = [_style inheritedStyles];
//    if ([inheritedStyles count])
//        [textAttributes setObject:inheritedStyles forKey:OSInheritedStylesAttributeName];
    
    //NSLog(@"style %@ -> attributes %@", style, textAttributes);
    
    [style release]; // Get rid of the flattened style
    
    NSDictionary *result = OSCopyUniquedTextAttributeDictionary(textAttributes);
    [textAttributes release];
    
    return result;
}

void _OSMutableAttributedStringRemoveStyleTextAttributes(NSMutableAttributedString *str)
{
    // Clean up any OSStyle-defined text attributes on this attributed string.
    NSRange range = NSMakeRange(0, [str length]);
    
    [str removeAttribute:OSInheritedStylesAttributeName range:range];
    [str removeAttribute:OAFontDescriptorAttributeName range:range];
    
    [str removeAttribute:OSOriginalNSForegroundColorAttributeName range:range];
    [str removeAttribute:OSOriginalNSBackgroundColorAttributeName range:range];
    [str removeAttribute:OSOriginalNSStrokeColorAttributeName range:range];
    [str removeAttribute:OSOriginalNSUnderlineColorAttributeName range:range];
    [str removeAttribute:OSOriginalNSStrikethroughColorAttributeName range:range];
}


+ (NSDictionary *)copyTextAttributesFromStyle:(OSStyle *)style;
{
    if (!style)
        return nil;
    else
        return [[style textAttributes] copy];
}


+ (OSStyle *)newStyleOfClass:(Class)styleClass fromTextAttributes:(NSDictionary *)textAttributes cascadeStyle:(OSStyle *)cascadeStyle context:(OSStyleContext *)context;
{
    OBPRECONDITION(context);
    
    OSStyle *style = [[styleClass alloc] initWithContext:context];
    NSDictionary *defaultTextAttributes = OSDefaultTextAttributes();
    
    if (cascadeStyle) {
        OBASSERT([cascadeStyle context] == context);
        // Set this up before local values are set so that if a 'default' value is set and the cascade style we wanted had a non-default value, the resultant style will have the default value (since otherwise the 'set' will do nothing for the default value).
        [style setCascadeStyle:cascadeStyle];
    }
    
    // Get or build a font descriptor.  Can't just use ATTR(OAFontDescriptorAttributeName) here since that wouldn't consider a locally set OAFontAttributeName -- it would just fall back to the default attribute dictionary!
    OAFontDescriptor *fontDescriptor = textAttributes[OAFontDescriptorAttributeName];
    if (fontDescriptor) {
        [style setFontDescriptor:fontDescriptor];
    } else {
        OAFontDescriptorPlatformFont font = (OAFontDescriptorPlatformFont)ATTR(NSFontAttributeName); // In this case we can look locally and then in the default dictionary
        OBASSERT(font);
        fontDescriptor = [[OAFontDescriptor alloc] initWithFont:font];
        [style setFontDescriptor:fontDescriptor];
        [fontDescriptor release];
    }
    
    NSParagraphStyle *paragraphStyle;
    if ((paragraphStyle = ATTR(NSParagraphStyleAttributeName)))
        [style setParagraphStyle:paragraphStyle];

    NSNumber *underlineMaskValue;
    if ((underlineMaskValue = ATTR(NSUnderlineStyleAttributeName))) {
        NSUInteger underlineMask = [underlineMaskValue unsignedIntegerValue];
        
        if ((underlineMask & OAUnderlineByWordMask) == OAUnderlineByWordMask)
            [style setValue:@"by word" forAttribute:OSUnderlineAffinityStyleAttribute];
        underlineMask &= ~OAUnderlineByWordMask;
        
        // Style is in the low byte
	uint8_t underlineStyle = (underlineMask & 0xFFU);
	if (underlineStyle == (NSUnderlineStyleSingle|NSUnderlineStyleThick))
	    underlineStyle = NSUnderlineStyleThick; // OBS #21184; someone got a file with an underline style of 0x3, but that doesn't seem to be allowed?
        [style setValue:[[OSUnderlineStyleStyleAttribute enumTable] nameForEnum:underlineStyle] forAttribute:OSUnderlineStyleStyleAttribute];
        underlineMask &= ~0xFFU;
        
        // Pattern is in the next byte up
        [style setValue:[[OSUnderlinePatternStyleAttribute enumTable] nameForEnum:underlineMask & 0xFF00U] forAttribute:OSUnderlinePatternStyleAttribute];
        underlineMask &= ~0xFF00U;
        
        // There shouldn't be any bits left
        OBASSERT(underlineMask == 0);
        OB_UNUSED_VALUE(underlineMask);
    }
    
    NSNumber *strikethroughMaskValue;
    if ((strikethroughMaskValue = ATTR(NSStrikethroughStyleAttributeName))) {
        NSUInteger strikethroughMask = [strikethroughMaskValue unsignedIntegerValue];
        
        if ((strikethroughMask & OAUnderlineByWordMask) == OAUnderlineByWordMask)
            [style setValue:@"by word" forAttribute:OSStrikethroughAffinityStyleAttribute];
        strikethroughMask &= ~OAUnderlineByWordMask;
        
        // Style is in the low byte
        [style setValue:[[OSStrikethroughStyleStyleAttribute enumTable] nameForEnum:(strikethroughMask & 0xFFU)] forAttribute:OSStrikethroughStyleStyleAttribute];
        strikethroughMask &= ~0xFFU;
        
        // Pattern is in the next byte up
        [style setValue:[[OSStrikethroughPatternStyleAttribute enumTable] nameForEnum:strikethroughMask & 0xFF00U] forAttribute:OSStrikethroughPatternStyleAttribute];
        strikethroughMask &= ~0xFF00U;
        
        // There shouldn't be any bits left
        OBASSERT(strikethroughMask == 0);
    }

    OS_COLOR_CLASS *color;
    if ((color = COLOR_ATTR(NSUnderlineColorAttributeName)))
	[style setValue:color forAttribute:OSUnderlineColorStyleAttribute];
    if ((color = COLOR_ATTR(NSStrikethroughColorAttributeName)))
        [style setValue:color forAttribute:OSStrikethroughColorStyleAttribute];
    
    NSNumber *number;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    // <bug:///94057> (Emulate superscript/subscript with formula from Apple)
#else
    if ((number = ATTR(OASuperscriptAttributeName)))
        [style setValue:number forAttribute:OSBaselineSuperscriptStyleAttribute];
    if ((number = ATTR(NSBaselineOffsetAttributeName)))
        [style setValue:number forAttribute:OSBaselineOffsetStyleAttribute];
#endif
    
    number = ATTR(NSKernAttributeName);
    OBASSERT([[OSKerningAdjustmentStyleAttribute defaultValue] isEqual: [OSKerningAdjustmentStyleAttribute defaultValue]]); // NaN == NaN in this world?
    if (number)
        [style setValue:number forAttribute:OSKerningAdjustmentStyleAttribute];
    
    number = ATTR(NSLigatureAttributeName);
    if (number) {
        NSString *name = [[OSLigatureSelectionStyleAttribute enumTable] nameForEnum:[number intValue]];
        [style setValue:name forAttribute:OSLigatureSelectionStyleAttribute];
    }
    
    OS_COLOR_CLASS *fillColor = COLOR_ATTR(NSForegroundColorAttributeName);
    OS_COLOR_CLASS *strokeColor = COLOR_ATTR(NSStrokeColorAttributeName);
    NSNumber *strokeWidth = ATTR(NSStrokeWidthAttributeName);
    
    if (strokeColor && strokeWidth) {
        // In AppKit-world, a negative stroke width means to obey BOTH the stroke and fill.  Otherwise only the stroke is used.
        CGFloat strokeWidthValue = [strokeWidth cgFloatValue];
        _setFloatStyle(style, (CGFloat)fabs(strokeWidthValue), OSFontStrokeWidthStyleAttribute);
        [style setValue:strokeColor forAttribute:OSFontStrokeColorStyleAttribute];
        
        if (fillColor && strokeWidthValue <= 0.0f) {
            [style setValue:fillColor forAttribute:OSFontFillColorStyleAttribute];
        } else {
            // No fill -- set clear
            [style setValue:[OS_COLOR_CLASS clearColor] forAttribute:OSFontFillColorStyleAttribute];
        }
    } else {
	OBASSERT_NOT_REACHED("Now that ATTR() always returns something, this can't be reached");
	
        // Only obey the fill color
        [style setValue:fillColor forAttribute:OSFontFillColorStyleAttribute];
    }
    
    if ((color = COLOR_ATTR(NSBackgroundColorAttributeName)))
        [style setValue:color forAttribute:OSBackgroundColorStyleAttribute];
    
    if ((number = ATTR(NSObliquenessAttributeName)))
        [style setValue:number forAttribute:OSObliquenessStyleAttribute];
    
    if ((number = ATTR(NSExpansionAttributeName)))
        [style setValue:number forAttribute:OSExpansionStyleAttribute];

    NSShadow *shadow = ATTR(NSShadowAttributeName);
    if (shadow) {
        [style setValue:[shadow shadowColor] forAttribute:OSShadowColorStyleAttribute];
        _setFloatStyle(style, [shadow shadowBlurRadius], OSShadowBlurRadiusStyleAttribute);
        
        CGSize size = [shadow shadowOffset];
        [style setValue:[OFPoint pointWithPoint:CGPointMake(size.width, size.height)] forAttribute:OSShadowVectorStyleAttribute];
    }

    // Might remove some more later if/when our cascade chain is set up, but definitely remove redundant values if we have inherited styles
    if (cascadeStyle)
        [style removeRedundantValues];
    
#undef ATTR
    return style;
}

+ (OSStyle *)newStyleFromTextAttributes:(NSDictionary *)textAttributes cascadeStyle:(OSStyle *)cascadeStyle context:(OSStyleContext *)context;
{
    return [self newStyleOfClass:[OSStyle class] fromTextAttributes:textAttributes cascadeStyle:cascadeStyle context:context];
}

+ (OSStyle *)newStyleFromTextAttributes:(NSDictionary *)textAttributes context:(OSStyleContext *)context;
{
    return [self newStyleOfClass:[OSStyle class] fromTextAttributes:textAttributes cascadeStyle:nil context:context];
}

struct _checkDictionaryForDifferencesIgnoringAttachmentKeyState {
    BOOL differ;
    NSDictionary *otherDict;
};

static void _checkDictionaryForDifferencesIgnoringAttachmentKey(const void *key, const void *value, void *context)
{
    struct _checkDictionaryForDifferencesIgnoringAttachmentKeyState *state = context;
    
    if (state->differ)
        return; // Done already
    
    if ([(id)key isEqualToString:NSAttachmentAttributeName])
        return; // Ignore this key
    
    id otherValue = [state->otherDict objectForKey:(id)key];
    if (OFNOTEQUAL((id)value, otherValue))
        state->differ = YES;
}

typedef struct {
    NSAttributedString *self;
    OSStyleContext *styleContext;
    OSStyle *baseStyle;
    BOOL wroteAnyAttachment;
    NSDictionary *baseStyleAttributes;
    
    OSStyle *previousStyle;
    OSStyle *newStyle;
} AppendXMLContext;

static OSStyledTextStorageAppendRunStyleResult _appendRunStyleApplier(OFXMLDocument *doc, id style_, NSString *forString, BOOL hasAttachment, void *context)
{
    OSStyle *style = style_;

    OBPRECONDITION(doc);
    OBPRECONDITION([style isKindOfClass:[OSStyle class]]); // shouldn't get called for nil style

    [style appendXML:doc];
    return OSStyledTextStorageAppendRunStyleContinue;
}

static void _appendXMLBeginParagraphApplier(OFXMLDocument *doc, NSString *string, NSUInteger lineStart, NSUInteger lineEnd, NSUInteger contentsEnd, void *context)
{
    AppendXMLContext *ctx = context;
        
    OBASSERT(ctx->previousStyle == nil);
    OBASSERT(ctx->newStyle == nil);
    
    ctx->newStyle = [ctx->baseStyle retain];
}

static void _appendXMLFindStyleEffectiveRangeAtLocation(OFXMLDocument *doc, NSString *string, NSUInteger location, NSUInteger lineStart, NSUInteger lineEnd, NSUInteger contentsEnd,
                                                        NSRange *outEffectiveRange, id *outStyleToWrite, id *outAttachment,
                                                        void *context)
{
    AppendXMLContext *ctx = context;
    
    NSAttributedString *self = ctx->self;
    NSDictionary *baseStyleAttributes = ctx->baseStyleAttributes;
    
    [ctx->previousStyle release];
    ctx->previousStyle = ctx->newStyle;
    ctx->newStyle = nil;
    
    id attachment = nil;
    id styleToWrite = nil;
    
    NSDictionary *textAttributes = [self attributesAtIndex:location longestEffectiveRange:outEffectiveRange inRange:(NSRange){location, lineEnd-location}];
    if (!baseStyleAttributes || [baseStyleAttributes isEqual:textAttributes]) {
        // Either we aren't supposed to write attributes, or there are no differences between these attributes and the base attributes
        ctx->newStyle = [ctx->baseStyle retain];
        OBASSERT([textAttributes objectForKey:NSAttachmentAttributeName] == nil); // base attributes can't have attachments; links would be weird but OK.
    } else {
        // Different, but the difference might not matter for the style element itself.  Might only differ due to the attachment attribute.
        if ((attachment = [textAttributes objectForKey:NSAttachmentAttributeName])) {
            // If the two are equal except for the attachment attribute, then the count must be as follows.
            BOOL differ = ([textAttributes count] != ([baseStyleAttributes count] + 1));
            
            if (!differ) {
                // Counts checked out, now compare the contents, ignoring the attachment key
                struct _checkDictionaryForDifferencesIgnoringAttachmentKeyState state;
                state.differ = NO;
                state.otherDict = baseStyleAttributes;
                CFDictionaryApplyFunction((CFDictionaryRef)textAttributes, _checkDictionaryForDifferencesIgnoringAttachmentKey, &state);
                if (!state.differ) {
                    // No interesting difference differences!
                    ctx->newStyle = [ctx->baseStyle retain];
                }
            }
        }
    }
    
    if (!ctx->newStyle)
        ctx->newStyle = [object_getClass(self) newStyleFromTextAttributes:textAttributes cascadeStyle:ctx->baseStyle context:ctx->styleContext];

    // Only archive differences from the base style
    if (ctx->newStyle != ctx->baseStyle)
        [ctx->newStyle removeRedundantValues];
    
    if (ctx->newStyle != ctx->baseStyle && ![ctx->newStyle isEmpty])
        styleToWrite = ctx->newStyle;
    
    *outStyleToWrite = styleToWrite;
    *outAttachment = attachment;
}

static void _appendXMLEndParagraphApplier(OFXMLDocument *doc, NSString *string, NSUInteger lineStart, NSUInteger lineEnd, NSUInteger contentsEnd, void *context)
{
    AppendXMLContext *ctx = context;
    
    [ctx->previousStyle release];
    ctx->previousStyle = nil;
    
    [ctx->newStyle release];
    ctx->newStyle = nil;
}


- (void)appendXML:(OFXMLDocument *)doc baseStyle:(OSStyle *)baseStyle;
{
    OBPRECONDITION(baseStyle);
    
    NSUInteger length = [self length];
    
    AppendXMLContext ctx;
    memset(&ctx, 0, sizeof(ctx));
    ctx.self = self;
    ctx.styleContext = [baseStyle context];
    ctx.baseStyle = baseStyle;
    
    // It is often the case that the whole text storage has the same attributes, or at least that most of the text storage has the same attributes as the base style.  We can more efficiently save if we spend some time here and then compare NSDictionaries for each run, instead of building OSStyles for each run and removing redundant attributes (usually ending up with no differences).
    
#if 0 // This doesn't work since we don't propagate full range styles to cell styles (and we don't support cell styles having attributes at all anyway).
    // As a very special case, though, we assume that if the entire text storage has the same attributes, then those attributes are the base attribute (so we can skip any consideration of writing attributes).
    if (length) {
        NSRange effectiveRange;
        [self attributesAtIndex:0 longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, length)];
        
        if (effectiveRange.length == length)
            ctx.baseStyleAttributes = nil; // Our signal that we should not write any attributes
        else
            ctx.baseStyleAttributes = [[self class] copyTextAttributesFromStyle:baseStyle];
    } else
        ctx.baseStyleAttributes = nil; // No text; no attributes
#else
    if (length)
        ctx.baseStyleAttributes = [[self class] copyTextAttributesFromStyle:baseStyle];
    else
        ctx.baseStyleAttributes = nil; // No text; no attributes
#endif
    
    OSStyledTextStorageAppendTextCallbacks callbacks;
    memset(&callbacks, 0, sizeof(callbacks));
    callbacks.beginParagraph = _appendXMLBeginParagraphApplier;
    callbacks.findStyleEffectiveRangeAtLocation = _appendXMLFindStyleEffectiveRangeAtLocation;
    callbacks.appendRunStyle = _appendRunStyleApplier;
    callbacks.endParagraph = _appendXMLEndParagraphApplier;
    
    OSStyledTextStorageAppendTextWithApplier(doc, [self string], callbacks, &ctx);
    
    [ctx.baseStyleAttributes release];
}

@end

@implementation NSMutableAttributedString (OSExtensions)

// This is the current workaround for the old/new element name issue.  This method checks both names and the caller should NOT have checked it.
+ (BOOL)canCreateFromNextChildXML:(OFXMLCursor *)cursor;
{
    id nextChild = [cursor peekNextChild];
    if (![nextChild isKindOfClass:[OFXMLElement class]])
        return NO;
    
    NSString *elementName = [(OFXMLElement *)nextChild name];
    if (![elementName isEqualToString:OSStyledTextStorageXMLElementName])
        return NO;
    
    return YES;
}

+ (BOOL)shouldRemoveStyleTextAttributesAfterUnarchiving;
{
    return YES;
}

+ newFromNextChildXML:(OFXMLCursor *)cursor baseStyle:(OSStyle *)baseStyle;
{
    if (![self canCreateFromNextChildXML:cursor])
        return nil;
    
    [cursor nextChild];
    [cursor openElement];
    NSMutableAttributedString *text = [[self alloc] initFromXML:cursor baseStyle:baseStyle];
    [cursor closeElement];
    
    return text;    
}

- initFromXML:(OFXMLCursor *)cursor baseStyle:(OSStyle *)baseStyle;
{
    OBPRECONDITION([[cursor name] isEqualToString:OSStyledTextStorageXMLElementName]);
    
    // Avoid doing an -init/-appendString:attributes: if we only have a single run.
    BOOL hasCalledInit = NO;
    
    OSStyleContext *context = [baseStyle context];
    NSDictionary *currentAttributes = nil;
    NSArray *cascadeStyles = [[NSArray alloc] initWithObjects:&baseStyle count:1];
    NSDictionary *baseAttributes = [[self class] copyTextAttributesFromStyle:baseStyle];
    
    BOOL firstParagraph = YES;

    @try {
        currentAttributes = [baseAttributes retain];
        
        while ([cursor openNextChildElementNamed:OSStyledTextStorageParagraphXMLElementName]) {
            if (!firstParagraph) {
                // Not the first paragraph; insert a newline between the two.  Note that this means we do not preserve the line ending style used on input.  Note that we firstParagraph != [self length] since the text might start with a bunch of newlines.
                if (hasCalledInit)
                    [self appendString:@"\n" attributes:currentAttributes];
                else {
                    self = [self initWithString:@"\n" attributes:currentAttributes];
                    hasCalledInit = YES;
                }
            }
            firstParagraph = NO;
            
            while ([cursor openNextChildElementNamed:OSStyledTextStorageRunXMLElementName]) {
                if ([cursor openNextChildElementNamed:[OSStyle xmlElementName]]) {
                    OSStyle *style = [[OSStyle alloc] initFromXML:cursor context:context cascadeStyles:cascadeStyles allowRedundantValues:NO referencedAttributes:nil];
                    
                    [currentAttributes release];
                    currentAttributes = [[self class] copyTextAttributesFromStyle:style];
                    [style release];
                    [cursor closeElement];
                } else if (currentAttributes != baseAttributes) {
                    [currentAttributes release];
                    currentAttributes = [baseAttributes retain];
                }
                
                if ([cursor openNextChildElementNamed:OSStyledTextStorageLiteralStringXMLElementName]) {
                    // This can contain any number of strings and attachments
                    id child;
                    
                    while ((child = [cursor nextChild])) {
                        if ([child isKindOfClass:[NSString class]]) {
                            if (hasCalledInit)
                                [self appendString:child attributes:currentAttributes];
                            else {
                                self = [self initWithString:child attributes:currentAttributes];
                                hasCalledInit = YES;
                            }
                        } else {
                            NSLog(@"%s: Unable to read child element %@ at cursor path %@", __PRETTY_FUNCTION__, child, [cursor currentPath]);
                        }
                    }
                    
                    [cursor closeElement]; // <lit>
                }
                [cursor closeElement]; // <run>
            }
            [cursor closeElement]; // <p>
        }
        
        // Empty archive
        if (!hasCalledInit) {
            self = [self initWithString:@""];
            hasCalledInit = YES;
        }
    } @finally {
        [cascadeStyles release];
        [baseAttributes release];
        [currentAttributes release];
    };

    _OSMutableAttributedStringRemoveStyleTextAttributes(self);

    OBPOSTCONDITION(hasCalledInit);
    return self;
}

@end

