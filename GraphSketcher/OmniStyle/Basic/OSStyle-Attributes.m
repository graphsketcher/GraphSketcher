// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStyle-Attributes.m 200244 2013-12-10 00:11:55Z correia $

#import "OSStyle.h"

#import "OSStyleAttributeRegistry.h"
#import "OSBoolStyleAttribute.h"
#import "OSColorStyleAttribute.h"
#import "OSEnumStyleAttribute.h"
#import "OSNumberStyleAttribute.h"
#import "OSStringStyleAttribute.h"
#import "OSVectorStyleAttribute.h"
#import "OSURLStyleAttribute.h"
#import "OSStyle-AttributeExtensions.h"
#import "OSStyledTextStorage-XML.h"
#import <OmniAppKit/OAFontDescriptor.h>
#import <OmniAppKit/OAParagraphStyle.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#import "OSStyle-AttributeExtensions.h"
#else
#import <OmniQuartz/OQColor.h>
#endif

#import <OmniFoundation/NSNumber-OFExtensions-CGTypes.h>
#import <OmniFoundation/OFEnumNameTable.h>
#import <OmniFoundation/NSNumber-OFExtensions.h>
#import <OmniFoundation/OFPoint.h>

#import <OmniBase/rcsid.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStyle-Attributes.m 200244 2013-12-10 00:11:55Z correia $")

// Character styles
OSStringStyleAttribute *OSFontFamilyNameStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSStringStyleAttribute *OSFontNameStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSFontSizeStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSColorStyleAttribute  *OSFontFillColorStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSFontStrokeWidthStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSColorStyleAttribute  *OSFontStrokeColorStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSFontWeightStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSBoolStyleAttribute   *OSFontItalicStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSBoolStyleAttribute   *OSFontCondensedStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSBoolStyleAttribute   *OSFontNarrowStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSBoolStyleAttribute   *OSFontFixedPitchStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSColorStyleAttribute  *OSBackgroundColorStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
OSColorStyleAttribute  *OSSelectionColorStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
#endif

OSNumberStyleAttribute *OSBaselineSuperscriptStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSBaselineOffsetStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSKerningAdjustmentStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSEnumStyleAttribute   *OSLigatureSelectionStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;

OSEnumStyleAttribute   *OSUnderlineStyleStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSEnumStyleAttribute   *OSUnderlinePatternStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSEnumStyleAttribute   *OSUnderlineAffinityStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSColorStyleAttribute  *OSUnderlineColorStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;

OSEnumStyleAttribute   *OSStrikethroughStyleStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSEnumStyleAttribute   *OSStrikethroughPatternStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSEnumStyleAttribute   *OSStrikethroughAffinityStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSColorStyleAttribute  *OSStrikethroughColorStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;

OSNumberStyleAttribute *OSObliquenessStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSExpansionStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;

OSVectorStyleAttribute *OSShadowVectorStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSShadowBlurRadiusStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSColorStyleAttribute  *OSShadowColorStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;

// Paragraph styles
OSEnumStyleAttribute   *OSParagraphAlignmentStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphLineSpacingStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphSpacingStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphHeadIndentStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphTailIndentStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphFirstLineHeadIndentStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphMinimumLineHeightStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphMaximumLineHeightStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSStringStyleAttribute *OSParagraphTabStopsStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphLineHeightMultipleStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphSpacingBeforeStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSNumberStyleAttribute *OSParagraphDefaultTabIntervalStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;
OSEnumStyleAttribute   *OSParagraphBaseWritingDirectionStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;

// Link styles
OSURLStyleAttribute *OSLinkStyleAttribute = OS_UNINITIALIZED_STYLE_ATTRIBUTE;

#define ASSIGN_NAMES(attr,group,name)

OSStyleAttributeBeginRegistration
{
    OBPRECONDITION(OSFontFamilyNameStyleAttribute == OS_UNINITIALIZED_STYLE_ATTRIBUTE);

    NSBundle *bundle = OMNI_BUNDLE;
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    id blackColor = [OQColor blackColor];
    id clearColor = [OQColor clearColor];
#else
    id blackColor = [NSColor blackColor];
    id clearColor = [NSColor clearColor];
#endif
    
    // Register OSStyleAttributes for everything that we want to represent from the Cocoa text suite.
    //
    // NOTE: THESE MUST NOT CHANGE AFTER SHIPPING (at least not w/o serious consideration to file format compatibility issues)
    //

    OSFontFamilyNameStyleAttribute = [[OSStringStyleAttribute alloc] initWithKey:@"font-family" defaultValue:@"Helvetica"];
    ASSIGN_NAMES(OSFontFamilyNameStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"family", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontFamilyNameStyleAttribute];

    OSFontNameStyleAttribute = [[OSStringStyleAttribute alloc] initWithKey:@"font-name" defaultValue:@"Helvetica"];
    ASSIGN_NAMES(OSFontNameStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"name", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontNameStyleAttribute];

    OSFontSizeStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"font-size"
                                                              defaultValue:[NSNumber numberWithFloat: 12.0f]
                                                               valueExtent:OFExtentMake(1.0f, 65535.0f) // just making this up
                                                                  integral:NO];
    ASSIGN_NAMES(OSFontSizeStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"size", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontSizeStyleAttribute];

    OSFontFillColorStyleAttribute = [[OSColorStyleAttribute alloc] initWithKey:@"font-fill"
                                                                  defaultValue:blackColor];
    [OSFontFillColorStyleAttribute setVersion:1]; // Version 0 used +textColor, but that doesn't draw correctly on printers (#20499)
    ASSIGN_NAMES(OSFontFillColorStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"fill color", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontFillColorStyleAttribute];


    OSFontStrokeWidthStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"font-stroke-width"
                                                                     defaultValue:[NSNumber numberWithFloat: 0.0f]
                                                                      valueExtent:OFExtentMake(0.0f, 100.0f)
                                                                         integral:NO];
    ASSIGN_NAMES(OSFontStrokeWidthStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"border width", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontStrokeWidthStyleAttribute];

    OSFontStrokeColorStyleAttribute = [[OSColorStyleAttribute alloc] initWithKey:@"font-stroke"
                                                                    defaultValue:blackColor];
    [OSFontStrokeColorStyleAttribute setVersion:1]; // Version 0 used +textColor, but that doesn't draw correctly on printers (#20499)
    ASSIGN_NAMES(OSFontStrokeColorStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"border color", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontStrokeColorStyleAttribute];
    

     // See NSFontManager documentation for weight values
    OSFontWeightStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"font-weight"
                                                                defaultValue:[NSNumber numberWithInt:5]
                                                                 valueExtent:OAFontDescriptorValidFontWeightExtent()
                                                                    integral:YES];
    ASSIGN_NAMES(OSFontWeightStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"weight", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontWeightStyleAttribute];


    // This is different than the 10.3-added obliqueness (I think).  Obliqueness is a separate skew factor that can (presumably) be applied to a italic font too.
    OSFontItalicStyleAttribute = [[OSBoolStyleAttribute alloc] initWithKey:@"font-italic"
                                                              defaultValue:[NSNumber numberWithBool:NO]];
    ASSIGN_NAMES(OSFontItalicStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"italic", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontItalicStyleAttribute];

    OSFontCondensedStyleAttribute = [[OSBoolStyleAttribute alloc] initWithKey:@"font-condensed"
								 defaultValue:[NSNumber numberWithBool:NO]];
    ASSIGN_NAMES(OSFontCondensedStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"condensed", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontCondensedStyleAttribute];
    
    OSFontNarrowStyleAttribute = [[OSBoolStyleAttribute alloc] initWithKey:@"font-narrow"
								 defaultValue:[NSNumber numberWithBool:NO]];
    ASSIGN_NAMES(OSFontNarrowStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"narrow", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontNarrowStyleAttribute];
    
    OSFontFixedPitchStyleAttribute = [[OSBoolStyleAttribute alloc] initWithKey:@"font-fixed-pitch"
								  defaultValue:[NSNumber numberWithBool:NO]];
    ASSIGN_NAMES(OSFontFixedPitchStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"fixed pitch", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSFontFixedPitchStyleAttribute];
    
    // Baseline
    OSBaselineSuperscriptStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"baseline-superscript"
                                                                         defaultValue:[NSNumber numberWithInt:0]
                                                                          valueExtent:OFExtentMake(-1000, 2000)
                                                                             integral:YES];
    ASSIGN_NAMES(OSBaselineSuperscriptStyleAttribute, NSLocalizedStringFromTableInBundle(@"baseline", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"superscript", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSBaselineSuperscriptStyleAttribute];

    OSBaselineOffsetStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"baseline-offset"
                                                                    defaultValue:[NSNumber numberWithInt:0]
                                                                     valueExtent:OFExtentMake(-1000, 2000)
                                                                        integral:YES];
    ASSIGN_NAMES(OSBaselineOffsetStyleAttribute, NSLocalizedStringFromTableInBundle(@"baseline", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"offset", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSBaselineOffsetStyleAttribute];


    // We use NaN to represent the 'no adjustment' and zero for 'turn off kerning'
    OSKerningAdjustmentStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"kerning-adjust"
                                                                       defaultValue:(id)[OFNaN sharedNaN]
                                                                        valueExtent:OFExtentMake(-1000, 2000)
                                                                           integral:NO];
    ASSIGN_NAMES(OSKerningAdjustmentStyleAttribute, NSLocalizedStringFromTableInBundle(@"kerning", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"adjust", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSKerningAdjustmentStyleAttribute];
    OBASSERT([[OSKerningAdjustmentStyleAttribute defaultValue] isEqual: [OSKerningAdjustmentStyleAttribute defaultValue]]); // NaN == NaN in this world?

    // Ligatures -- there is no official enum for this, just the comments in NSAttributedString.h
    OFEnumNameTable *ligatureTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:1];
    [ligatureTable setName:@"none"
               displayName:NSLocalizedStringWithDefaultValue(@"none <ligature style value>", @"OmniStyle", bundle, @"none", "ligature style value")
              forEnumValue:0];
    [ligatureTable setName:@"default"
               displayName:NSLocalizedStringFromTableInBundle(@"default", @"OmniStyle", bundle, "ligature style value")
              forEnumValue:1];
    [ligatureTable setName:@"all"
               displayName:NSLocalizedStringFromTableInBundle(@"all", @"OmniStyle", bundle, "ligature style value")
              forEnumValue:2];
    OSLigatureSelectionStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"ligature-selection"
                                                                        enumTable:ligatureTable];
    [ligatureTable release];
    ASSIGN_NAMES(OSLigatureSelectionStyleAttribute, NSLocalizedStringFromTableInBundle(@"ligature", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"selection", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSLigatureSelectionStyleAttribute];


    // For now this is equivalent to NSBackgroundColorAttributeName, except that we use +[NSColor clearColor] has the default.
    OSBackgroundColorStyleAttribute = [[OSColorStyleAttribute alloc] initWithKey:@"text-background-color"
                                                                    defaultValue:clearColor];
    ASSIGN_NAMES(OSBackgroundColorStyleAttribute, NSLocalizedStringFromTableInBundle(@"text", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"background color", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSBackgroundColorStyleAttribute];

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    // The base selection color; the actual rendered colors may be algorithmically generated from this.
    OSSelectionColorStyleAttribute = [[OSColorStyleAttribute alloc] initWithKey:@"selection-color"
                                                                    defaultValue:[NSColor alternateSelectedControlColor]];
    ASSIGN_NAMES(OSSelectionColorStyleAttribute, NSLocalizedStringFromTableInBundle(@"interface", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"selection color", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSSelectionColorStyleAttribute];
#endif
    
    // Underline & Strikethrough

    
    NSUInteger underlineStyleVersion = 1;
    NSUInteger underlinePatternVersion = 1;

    // NOT reusing the underline tables since localizers might want different values.
    {
	OFEnumNameTable *styleTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:NSUnderlineStyleNone];
	[styleTable setName:@"none"
		displayName:NSLocalizedStringWithDefaultValue(@"none <underline style value>", @"OmniStyle", bundle, @"none", @"underline style value")
	       forEnumValue:NSUnderlineStyleNone];
	[styleTable setName:@"single"
		displayName:NSLocalizedStringWithDefaultValue(@"single <underline style value>", @"OmniStyle", bundle, @"single", @"underline style value")
	       forEnumValue:NSUnderlineStyleSingle];
	[styleTable setName:@"thick"
		displayName:NSLocalizedStringWithDefaultValue(@"thick <underline style value>", @"OmniStyle", bundle, @"thick", @"underline style value")
	       forEnumValue:NSUnderlineStyleThick];
	[styleTable setName:@"double"
		displayName:NSLocalizedStringWithDefaultValue(@"double <underline style value>", @"OmniStyle", bundle, @"double", @"underline style value")
	       forEnumValue:NSUnderlineStyleDouble];
	
	OFEnumNameTable *patternTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:NSUnderlinePatternSolid];
	[patternTable setName:@"solid"
		  displayName:NSLocalizedStringWithDefaultValue(@"solid <underline style value>", @"OmniStyle", bundle, @"solid", "underline pattern style value")
		 forEnumValue:NSUnderlinePatternSolid];
	[patternTable setName:@"dot"
		  displayName:NSLocalizedStringWithDefaultValue(@"dot <underline style value>", @"OmniStyle", bundle, @"dot", "underline pattern style value")
		 forEnumValue:NSUnderlinePatternDot];
	[patternTable setName:@"dash"
		  displayName:NSLocalizedStringWithDefaultValue(@"dash <underline style value>", @"OmniStyle", bundle, @"dash", "underline pattern style value")
		 forEnumValue:NSUnderlinePatternDash];
	[patternTable setName:@"dash dot"
		  displayName:NSLocalizedStringWithDefaultValue(@"dash dot <underline style value>", @"OmniStyle", bundle, @"dash dot", "underline pattern style value")
		 forEnumValue:NSUnderlinePatternDashDot];
	[patternTable setName:@"dash dot dot"
		  displayName:NSLocalizedStringWithDefaultValue(@"dash dot dot <underline style value>", @"OmniStyle", bundle, @"dash dot dot", "underline pattern style value")
		 forEnumValue:NSUnderlinePatternDashDotDot];
	
	// NSUnderlineStrikethroughMask is a global, so they *could* change it -- don't reference it here.  Making this an enum since they could add additional affinitys (by sentence, by paragraph, etc).
	OFEnumNameTable *affinityTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:0/*no mask value*/];
	[affinityTable setName:@"none"
		   displayName:NSLocalizedStringWithDefaultValue(@"none <underline affinity style value>", @"OmniStyle", bundle, @"none", "underline affinity style value")
		  forEnumValue:0/*no mask value*/];
	[affinityTable setName:@"by word"
		   displayName:NSLocalizedStringWithDefaultValue(@"by word <underline affinity style value>", @"OmniStyle", bundle, @"by word", "underline affinity style value")
		  forEnumValue:1];
	
	OSUnderlineStyleStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"underline-style"
									 enumTable:styleTable];
	[OSUnderlineStyleStyleAttribute setVersion:underlineStyleVersion];
        ASSIGN_NAMES(OSUnderlineStyleStyleAttribute, NSLocalizedStringFromTableInBundle(@"underline", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"style", @"OmniStyle", bundle, "style attribute or group name"));
	[OSStyleAttributeRegistry registerStyleAttribute:OSUnderlineStyleStyleAttribute];
	
        OSUnderlinePatternStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"underline-pattern"
									   enumTable:patternTable];
	[OSUnderlinePatternStyleAttribute setVersion:underlinePatternVersion];
        ASSIGN_NAMES(OSUnderlinePatternStyleAttribute, NSLocalizedStringFromTableInBundle(@"underline", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"pattern", @"OmniStyle", bundle, "style attribute or group name"));
	[OSStyleAttributeRegistry registerStyleAttribute:OSUnderlinePatternStyleAttribute];
	
	OSUnderlineAffinityStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"underline-affinity"
									    enumTable:affinityTable];
        ASSIGN_NAMES(OSUnderlineAffinityStyleAttribute, NSLocalizedStringFromTableInBundle(@"underline", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"affinity", @"OmniStyle", bundle, "style attribute or group name"));
	[OSStyleAttributeRegistry registerStyleAttribute:OSUnderlineAffinityStyleAttribute];
	
        [styleTable release];
	[patternTable release];
	[affinityTable release];
    }

    {
	OFEnumNameTable *styleTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:NSUnderlineStyleNone];
	[styleTable setName:@"none"
		displayName:NSLocalizedStringWithDefaultValue(@"none <strikethrough style value>", @"OmniStyle", bundle, @"none", @"strikethrough style value")
	       forEnumValue:NSUnderlineStyleNone];
	[styleTable setName:@"single"
		displayName:NSLocalizedStringWithDefaultValue(@"single <strikethrough style value>", @"OmniStyle", bundle, @"single", @"strikethrough style value")
	       forEnumValue:NSUnderlineStyleSingle];
	[styleTable setName:@"thick"
		displayName:NSLocalizedStringWithDefaultValue(@"thick <strikethrough style value>", @"OmniStyle", bundle, @"thick", @"strikethrough style value")
	       forEnumValue:NSUnderlineStyleThick];
	[styleTable setName:@"double"
		displayName:NSLocalizedStringWithDefaultValue(@"double <strikethrough style value>", @"OmniStyle", bundle, @"double", @"strikethrough style value")
	       forEnumValue:NSUnderlineStyleDouble];
	
	OFEnumNameTable *patternTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:NSUnderlinePatternSolid];
	[patternTable setName:@"solid"
		  displayName:NSLocalizedStringWithDefaultValue(@"solid <strikethrough style value>", @"OmniStyle", bundle, @"solid", "strikethrough pattern style value")
		 forEnumValue:NSUnderlinePatternSolid];
	[patternTable setName:@"dot"
		  displayName:NSLocalizedStringWithDefaultValue(@"dot <strikethrough style value>", @"OmniStyle", bundle, @"dot", "strikethrough pattern style value")
		 forEnumValue:NSUnderlinePatternDot];
	[patternTable setName:@"dash"
		  displayName:NSLocalizedStringWithDefaultValue(@"dash <strikethrough style value>", @"OmniStyle", bundle, @"dash", "strikethrough pattern style value")
		 forEnumValue:NSUnderlinePatternDash];
	[patternTable setName:@"dash dot"
		  displayName:NSLocalizedStringWithDefaultValue(@"dash dot <strikethrough style value>", @"OmniStyle", bundle, @"dash dot", "strikethrough pattern style value")
		 forEnumValue:NSUnderlinePatternDashDot];
	[patternTable setName:@"dash dot dot"
		  displayName:NSLocalizedStringWithDefaultValue(@"dash dot dot <strikethrough style value>", @"OmniStyle", bundle, @"dash dot dot", "strikethrough pattern style value")
		 forEnumValue:NSUnderlinePatternDashDotDot];
	
	// NSUnderlineStrikethroughMask is a global, so they *could* change it -- don't reference it here.  Making this an enum since they could add additional affinitys (by sentence, by paragraph, etc).
	OFEnumNameTable *affinityTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:0/*no mask value*/];
	[affinityTable setName:@"none"
		   displayName:NSLocalizedStringWithDefaultValue(@"none <strikethrough affinity style value>", @"OmniStyle", bundle, @"none", "strikethrough affinity style value")
		  forEnumValue:0/*no mask value*/];
	[affinityTable setName:@"by word"
		   displayName:NSLocalizedStringWithDefaultValue(@"by word <strikethrough affinity style value>", @"OmniStyle", bundle, @"by word", "strikethrough affinity style value")
		  forEnumValue:1];
	
	OSStrikethroughStyleStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"strikethrough-style"
									     enumTable:styleTable];
	[OSStrikethroughStyleStyleAttribute setVersion:underlineStyleVersion];
        ASSIGN_NAMES(OSStrikethroughStyleStyleAttribute, NSLocalizedStringFromTableInBundle(@"strikethrough", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"style", @"OmniStyle", bundle, "style attribute or group name"));
	[OSStyleAttributeRegistry registerStyleAttribute:OSStrikethroughStyleStyleAttribute];
	
	
	OSStrikethroughPatternStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"strikethrough-pattern"
									       enumTable:patternTable];
	[OSStrikethroughPatternStyleAttribute setVersion:underlinePatternVersion];
        ASSIGN_NAMES(OSStrikethroughPatternStyleAttribute, NSLocalizedStringFromTableInBundle(@"strikethrough", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"pattern", @"OmniStyle", bundle, "style attribute or group name"));
	[OSStyleAttributeRegistry registerStyleAttribute:OSStrikethroughPatternStyleAttribute];
	
        OSStrikethroughAffinityStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"strikethrough-affinity"
										enumTable:affinityTable];
        ASSIGN_NAMES(OSStrikethroughAffinityStyleAttribute, NSLocalizedStringFromTableInBundle(@"strikethrough", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"affinity", @"OmniStyle", bundle, "style attribute or group name"));
	[OSStyleAttributeRegistry registerStyleAttribute:OSStrikethroughAffinityStyleAttribute];
	
        [styleTable release];
	[patternTable release];
	[affinityTable release];
    }

    OSUnderlineColorStyleAttribute = [[OSColorStyleAttribute alloc] initWithKey:@"underline-color"
                                                                   defaultValue:blackColor];
    [OSUnderlineColorStyleAttribute setVersion:1]; // Version 0 used +textColor, but that doesn't draw correctly on printers (#20499)
    ASSIGN_NAMES(OSUnderlineColorStyleAttribute, NSLocalizedStringFromTableInBundle(@"underline", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"color", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSUnderlineColorStyleAttribute];

    OSStrikethroughColorStyleAttribute = [[OSColorStyleAttribute alloc] initWithKey:@"strikethrough-color"
                                                                       defaultValue:blackColor];
    [OSStrikethroughColorStyleAttribute setVersion:1]; // Version 0 used +textColor, but that doesn't draw correctly on printers (#20499)
    ASSIGN_NAMES(OSStrikethroughColorStyleAttribute, NSLocalizedStringFromTableInBundle(@"strikethrough", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"color", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSStrikethroughColorStyleAttribute];

    // "NSObliquenessAttributeName: skew to be applied to glyphs, default 0: no skew"
    // No mention is made of units...  maybe it is just 'one unit up, skew units right'.
    OSObliquenessStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"font-obliqueness"
                                                                 defaultValue:[NSNumber numberWithFloat:0.0f]
                                                                  valueExtent:OFExtentMake(-10.0f, 20.0f)
                                                                     integral:NO];
    ASSIGN_NAMES(OSObliquenessStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"obliqueness", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSObliquenessStyleAttribute];

    // "NSExpansionAttributeName: log of expansion factor to be applied to glyphs"
    // No mention is made of log base.
    OSExpansionStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"font-expansion"
                                                               defaultValue:[NSNumber numberWithFloat:0.0f]
                                                                valueExtent:OFExtentMake(0.0f, 200.0f)
                                                                   integral:NO];
    ASSIGN_NAMES(OSExpansionStyleAttribute, fontGroupName, NSLocalizedStringFromTableInBundle(@"expansion", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSExpansionStyleAttribute];


    // Shadow.
    OSShadowVectorStyleAttribute = [[OSVectorStyleAttribute alloc] initWithKey:@"shadow-offset"
                                                                  defaultValue:[OFPoint pointWithPoint:CGPointMake(0.0f,-1.0f)]];
    ASSIGN_NAMES(OSShadowVectorStyleAttribute, NSLocalizedStringFromTableInBundle(@"shadow", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"offset", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSShadowVectorStyleAttribute];

    OSShadowBlurRadiusStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"shadow-radius"
                                                                      defaultValue:[NSNumber numberWithFloat:1.5f]
                                                                       valueExtent:OFExtentMake(0.0f, 100.0f)
                                                                          integral:NO];
    ASSIGN_NAMES(OSShadowBlurRadiusStyleAttribute, NSLocalizedStringFromTableInBundle(@"shadow", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"blur radius", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSShadowBlurRadiusStyleAttribute];

    OSShadowColorStyleAttribute = [[OSColorStyleAttribute alloc] initWithKey:@"shadow-color"
                                                                defaultValue:clearColor];
    ASSIGN_NAMES(OSShadowColorStyleAttribute, NSLocalizedStringFromTableInBundle(@"shadow", @"OmniStyle", bundle, "style attribute or group name"), NSLocalizedStringFromTableInBundle(@"color", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSShadowColorStyleAttribute];
    
    //
    // Paragraph styles
    //

    NSParagraphStyle *pgStyle = [NSParagraphStyle defaultParagraphStyle];
    
    OFEnumNameTable *alignmentTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:[pgStyle alignment]];
    [alignmentTable setName:@"left"
                displayName:NSLocalizedStringFromTableInBundle(@"left", @"OmniStyle", bundle, "paragraph alignment style value")
               forEnumValue:NSTextAlignmentLeft];
    [alignmentTable setName:@"right"
                displayName:NSLocalizedStringFromTableInBundle(@"right", @"OmniStyle", bundle, "paragraph alignment style value")
               forEnumValue:NSTextAlignmentRight];
    [alignmentTable setName:@"center"
                displayName:NSLocalizedStringFromTableInBundle(@"center", @"OmniStyle", bundle, "paragraph alignment style value")
               forEnumValue:NSTextAlignmentCenter];
    [alignmentTable setName:@"justified"
                displayName:NSLocalizedStringFromTableInBundle(@"justified", @"OmniStyle", bundle, "paragraph alignment style value")
               forEnumValue:NSTextAlignmentJustified    ];
    [alignmentTable setName:@"natural"
                displayName:NSLocalizedStringFromTableInBundle(@"natural", @"OmniStyle", bundle, "paragraph alignment style value")
               forEnumValue:NSTextAlignmentNatural];
    OSParagraphAlignmentStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"paragraph-alignment"
                                                                         enumTable:alignmentTable];
    [alignmentTable release];
    ASSIGN_NAMES(OSParagraphAlignmentStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"alignment", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphAlignmentStyleAttribute];

    OSParagraphLineSpacingStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-line-spacing"
                                                                          defaultValue:[NSNumber numberWithCGFloat:[pgStyle lineSpacing]]
                                                                           valueExtent:OFExtentMake(-1000, 2000)
                                                                              integral:YES];  // making this integral for now for integral line drawing
    ASSIGN_NAMES(OSParagraphLineSpacingStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"line spacing", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphLineSpacingStyleAttribute];

    OSParagraphSpacingStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-spacing"
                                                                      defaultValue:[NSNumber numberWithCGFloat:[pgStyle paragraphSpacing]]
                                                                       valueExtent:OFExtentMake(-1000, 2000)
                                                                          integral:YES];  // making this integral for now for integral line drawing
    ASSIGN_NAMES(OSParagraphSpacingStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"spacing", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphSpacingStyleAttribute];

    OSParagraphHeadIndentStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-head-indent"
                                                                         defaultValue:[NSNumber numberWithCGFloat:[pgStyle headIndent]]
                                                                          valueExtent:OFExtentMake(-1000, 2000)
                                                                             integral:YES];  // making this integral for now for integral line drawing
    ASSIGN_NAMES(OSParagraphHeadIndentStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"head indent", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphHeadIndentStyleAttribute];

    OSParagraphTailIndentStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-tail-indent"
                                                                         defaultValue:[NSNumber numberWithCGFloat:[pgStyle tailIndent]]
                                                                          valueExtent:OFExtentMake(-1000, 2000)
                                                                             integral:YES];  // making this integral for now for integral line drawing
    ASSIGN_NAMES(OSParagraphTailIndentStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"tail indent", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphTailIndentStyleAttribute];

    OSParagraphFirstLineHeadIndentStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-first-line-head-indent"
                                                                                  defaultValue:[NSNumber numberWithCGFloat:[pgStyle firstLineHeadIndent]]
                                                                                   valueExtent:OFExtentMake(-1000, 2000)
                                                                                      integral:YES];  // making this integral for now for integral line drawing
    ASSIGN_NAMES(OSParagraphFirstLineHeadIndentStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"first line head indent", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphFirstLineHeadIndentStyleAttribute];

    OSParagraphMinimumLineHeightStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-minimum-line-height"
                                                                                defaultValue:[NSNumber numberWithCGFloat:[pgStyle minimumLineHeight]]
                                                                                 valueExtent:OFExtentMake(-1000, 2000)
                                                                                    integral:YES];  // making this integral for now for integral line drawing
    ASSIGN_NAMES(OSParagraphMinimumLineHeightStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"minimum line height", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphMinimumLineHeightStyleAttribute];

    OSParagraphMaximumLineHeightStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-maximum-line-height"
                                                                                defaultValue:[NSNumber numberWithCGFloat:[pgStyle maximumLineHeight]]
                                                                                 valueExtent:OFExtentMake(-1000, 2000)
                                                                                    integral:YES];  // making this integral for now for integral line drawing
    ASSIGN_NAMES(OSParagraphMaximumLineHeightStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"maximum line height", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphMaximumLineHeightStyleAttribute];


    OSParagraphTabStopsStyleAttribute = [[OSStringStyleAttribute alloc] initWithKey:@"paragraph-tab-stops"
                                                                       defaultValue:[OSStyle stringForTabStops:[pgStyle tabStops]]];
    ASSIGN_NAMES(OSParagraphTabStopsStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"tab stops", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphTabStopsStyleAttribute];
    
    OSParagraphLineHeightMultipleStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-line-height-multiple"
                                                                                 defaultValue:[NSNumber numberWithCGFloat:[pgStyle lineHeightMultiple]]
                                                                                  valueExtent:OFExtentMake(0.0f, 1000.0f)
                                                                                     integral:NO]; // NSRulerView UI will let you set float values; NSTextView seems to deal with this, so...
    ASSIGN_NAMES(OSParagraphLineHeightMultipleStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"line height multiple", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphLineHeightMultipleStyleAttribute];

    OSParagraphSpacingBeforeStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-spacing-before"
                                                                            defaultValue:[NSNumber numberWithCGFloat:[pgStyle paragraphSpacingBefore]]
                                                                             valueExtent:OFExtentMake(0.0f, 1000.0f)
                                                                                integral:NO]; // NSRulerView UI will let you set float values; NSTextView seems to deal with this, so...
    ASSIGN_NAMES(OSParagraphSpacingBeforeStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"space before", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphSpacingBeforeStyleAttribute];


    OSParagraphDefaultTabIntervalStyleAttribute = [[OSNumberStyleAttribute alloc] initWithKey:@"paragraph-tab-stop-interval"
                                                                                 defaultValue:[NSNumber numberWithCGFloat:[pgStyle defaultTabInterval]]
                                                                                  valueExtent:OFExtentMake(0.0f, 1000.0f)
                                                                                     integral:NO]; // No UI for this in NSRulerView yet.
    ASSIGN_NAMES(OSParagraphDefaultTabIntervalStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"tab stop interval", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphDefaultTabIntervalStyleAttribute];


    // It seems that NSParagraphStyle report -1 for 'default for script', but if you load a RTF file with LTR-Hebrew, it gets flipped to RTL.
    OFEnumNameTable *writingDirectionTable = [[OFEnumNameTable alloc] initWithDefaultEnumValue:[pgStyle baseWritingDirection]];
    [writingDirectionTable setName:@"natural"
                       displayName:NSLocalizedStringFromTableInBundle(@"natural", @"OmniStyle", bundle, "writing direction style value")
                      forEnumValue:NSWritingDirectionNatural];
    [writingDirectionTable setName:@"left-to-right"
                       displayName:NSLocalizedStringFromTableInBundle(@"left-to-right", @"OmniStyle", bundle, "writing direction style value")
                      forEnumValue:NSWritingDirectionLeftToRight];
    [writingDirectionTable setName:@"right-to-left"
                       displayName:NSLocalizedStringFromTableInBundle(@"right-to-left", @"OmniStyle", bundle, "writing direction style value")
                      forEnumValue:NSWritingDirectionRightToLeft];
    OSParagraphBaseWritingDirectionStyleAttribute = [[OSEnumStyleAttribute alloc] initWithKey:@"paragraph-base-writing-direction"
                                                                                    enumTable:writingDirectionTable];
    [writingDirectionTable release];
    ASSIGN_NAMES(OSParagraphBaseWritingDirectionStyleAttribute, paragraphGroupName, NSLocalizedStringFromTableInBundle(@"writing direction", @"OmniStyle", bundle, "style attribute or group name"));
    [OSStyleAttributeRegistry registerStyleAttribute:OSParagraphBaseWritingDirectionStyleAttribute];
    
} OSStyleAttributeEndRegistration
