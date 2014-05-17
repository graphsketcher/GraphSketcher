// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "InspectorSupport.h"

#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSGroup.h>
#import <OmniQuartz/OQColor.h>

RCS_ID("$Header$");

@implementation RSGraph (ColorInspection)

- (NSString *)preferenceKeyForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    return @"CanvasColorPalette";
}

- (OQColor *)colorForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    return self.backgroundColor;
}
- (void)setColor:(OQColor *)color fromInspectorSlice:(OUIInspectorSlice *)inspector;
{
    self.backgroundColor = color;
}

@end

@implementation RSGraphElement (ColorInspection)

- (BOOL)shouldBeInspectedByInspectorSlice:(OUIInspectorSlice *)inspector protocol:(Protocol *)protocol;
{
    if (protocol_isEqual(protocol, @protocol(OUIFontInspection))) {
        // We conform to the protocol on RSGraphElement, but some might not have fonts at all (vertexes w/o labels for example).
        id <RSFontAttributes> fontAttributes = [RSGraph fontAtrributeElementForElement:self];
        return (fontAttributes != nil);
    }
    
    return [super shouldBeInspectedByInspectorSlice:inspector protocol:protocol];
}

- (NSString *)preferenceKeyForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    return @"LineColorPalette";
}

- (OQColor *)colorForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    if ([self isKindOfClass:[RSVertex class]]) {
        RSVertex *vertex = (RSVertex *)self;
        if ([vertex lastParentFill] || [vertex shape] == RS_NONE)
            return nil;
    }
    
    return self.color;
}

- (void)setColor:(OQColor *)color fromInspectorSlice:(OUIInspectorSlice *)inspector;
{
    if ([self isKindOfClass:[RSVertex class]]) {
        RSVertex *vertex = (RSVertex *)self;
        if ([vertex lastParentFill])
            return;
    }
    
    self.color = color;

    if ([RSGraph isLine:self] || [self isKindOfClass:[RSVertex class]])
        [OQColor setColor:color forPreferenceKey:@"DefaultLineColor"];
}

- (OAFontDescriptor *)fontDescriptorForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    id <RSFontAttributes> fontAttributes = [RSGraph fontAtrributeElementForElement:self];
    return fontAttributes.fontDescriptor;
}

- (void)setFontDescriptor:(OAFontDescriptor *)fontDescriptor fromInspectorSlice:(OUIInspectorSlice *)inspector;
{
    id <RSFontAttributes> fontAttributes = [RSGraph fontAtrributeElementForElement:self];
    fontAttributes.fontDescriptor = fontDescriptor;
}

- (CGFloat)fontSizeForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    id <RSFontAttributes> fontAttributes = [RSGraph fontAtrributeElementForElement:self];
    return fontAttributes ? fontAttributes.fontSize : 12;
}

- (void)setFontSize:(CGFloat)fontSize fromInspectorSlice:(OUIInspectorSlice *)inspector;
{
    id <RSFontAttributes> fontAttributes = [RSGraph fontAtrributeElementForElement:self];
    fontAttributes.fontSize = fontSize;
}

- (NSUnderlineStyle)underlineStyleForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    RSGraphElement<RSFontAttributes> *fontAttributeElement = [RSGraph fontAtrributeElementForElement:self];
    NSNumber *value = [fontAttributeElement attributeForKey:NSUnderlineStyleAttributeName];
    return [value integerValue];
}

- (void)setUnderlineStyle:(NSUnderlineStyle)underlineStyle fromInspectorSlice:(OUIInspectorSlice *)inspector;
{
    RSGraphElement<RSFontAttributes> *fontAttributeElement = [RSGraph fontAtrributeElementForElement:self];
    [fontAttributeElement setAttribute:@(underlineStyle) forKey:NSUnderlineStyleAttributeName];
}

- (NSUnderlineStyle)strikethroughStyleForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    OBFinishPorting;
}

- (void)setStrikethroughStyle:(NSUnderlineStyle)strikethroughStyle fromInspectorSlice:(OUIInspectorSlice *)inspector;
{
    OBFinishPorting;
}

@end

@implementation RSFill (ColorInspection)

- (NSString *)preferenceKeyForInspectorSlice:(OUIInspectorSlice *)inspector;
{
    return @"FillColorPalette";
}

- (void)setColor:(OQColor *)color fromInspectorSlice:(OUIInspectorSlice *)inspector;
{
    OQColor *colorToUse = color;
    
    // If we're setting an opaque color from the inspector, use the fill's existing alpha level instead.  But if the fill is already almost opaque, don't bother; this is important for the advanced color sliders to work properly.
    // Never mind; it's not worth maintaining all the lies.
//    CGFloat opacity = [self opacity];
//    if ([color alphaComponent] == 1 && opacity < 0.9) {
//        colorToUse = [color colorWithAlphaComponent:opacity];
//    }
    
    self.color = colorToUse;
    
    [OQColor setColor:colorToUse forPreferenceKey:@"DefaultFillColor"];
}

@end

@implementation RSGroup (ColorInspection)

- (OQColor *)colorForInspectorSlice:(OUIInspectorSlice *)inspector;
{
#if 1
    // Hmmm. Here is one place that maybe wanted our old API. Still, since our inspectors only show one color, we should attempt to return the best/first color for a group.
    for (RSGraphElement *obj in [self elements])
    {
        if ([obj isKindOfClass:[RSVertex class]] && [obj shape] == RS_NONE)
            continue;
        
        return [obj color];
    }
    return nil;
#else
    NSMutableSet *colors = [NSMutableSet set];
    
    for (RSGraphElement *obj in [self elements])
    {
        if ([obj isKindOfClass:[RSVertex class]] && [obj shape] == RS_NONE)
            continue;
        
        [colors addObject:[obj color]];
    }
    
    return colors;
#endif
}

@end

#import "AppController.h"
#import "Document.h"
#import "GraphViewController.h"

@implementation OUIInspectorSlice (RSAdditions)

- (GraphViewController *)graphViewController;
{
    AppController *delegate = (AppController *)[[UIApplication sharedApplication] delegate];
    Document *document = (Document *)delegate.document;
    return (GraphViewController *)document.documentViewController;
}

- (RSGraphEditor *)editor;
{
    AppController *delegate = (AppController *)[[UIApplication sharedApplication] delegate];
    Document *document = (Document *)delegate.document;
    GraphViewController *vc = (GraphViewController *)document.documentViewController;
    return vc.editor;
}

@end
