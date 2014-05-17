// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSGraphElement-XML.h"

#import <GraphSketcherModel/RSGraph.h>
#import <OmniQuartz/OQColor-Archiving.h>
#import "OFObject-XML.h"

#import <OmniFoundation/OFVersionNumber.h>

NSString *nameFromShape(NSUInteger shape)
{
    switch (shape) {
	case RS_NONE:
	    return @"none";
	case RS_CIRCLE:
	    return @"circle";
	case RS_TRIANGLE:
	    return @"triangle";
	case RS_SQUARE:
	    return @"square";
	case RS_STAR:
	    return @"star";
	case RS_DIAMOND:
	    return @"diamond";
	case RS_X:
	    return @"treasure";
	case RS_CROSS:
	    return @"cross";
	case RS_HOLLOW:
	    return @"hollow";
	case RS_TICKMARK:
	    return @"tickmark";
	case RS_BAR_VERTICAL:
	    return @"bar-vertical";
	case RS_BAR_HORIZONTAL:
	    return @"bar-horizontal";
	case RS_ARROW:
	    return @"arrow";
	case RS_LEFT_ARROW:
	    return @"min-arrow";
	case RS_RIGHT_ARROW:
	    return @"max-arrow";
	case RS_BOTH_ARROW:
	    return @"both-arrow";
	default:
	    OBASSERT_NOT_REACHED("Unknown point shape");
	    break;
    }
    return nil;
}
NSUInteger shapeFromName(NSString *name)
{
    if ([name isEqualToString:@"none"])
	return RS_NONE;
    if ([name isEqualToString:@"circle"])
	return RS_CIRCLE;
    if ([name isEqualToString:@"triangle"])
	return RS_TRIANGLE;
    if ([name isEqualToString:@"square"])
	return RS_SQUARE;
    if ([name isEqualToString:@"star"])
	return RS_STAR;
    if ([name isEqualToString:@"diamond"])
	return RS_DIAMOND;
    if ([name isEqualToString:@"treasure"])
	return RS_X;
    if ([name isEqualToString:@"cross"])
	return RS_CROSS;
    if ([name isEqualToString:@"hollow"])
	return RS_HOLLOW;
    if ([name isEqualToString:@"tickmark"])
	return RS_TICKMARK;
    if ([name isEqualToString:@"bar-vertical"])
	return RS_BAR_VERTICAL;
    if ([name isEqualToString:@"bar-horizontal"])
	return RS_BAR_HORIZONTAL;
    if ([name isEqualToString:@"arrow"])
	return RS_ARROW;
    if ([name isEqualToString:@"min-arrow"])
	return RS_LEFT_ARROW;
    if ([name isEqualToString:@"max-arrow"])
	return RS_RIGHT_ARROW;
    if ([name isEqualToString:@"both-arrow"])
	return RS_BOTH_ARROW;
    
    OBASSERT_NOT_REACHED("Unknown point shape");
    
    return RS_CIRCLE;
}


@implementation RSGraphElement (XML)

#pragma mark -
#pragma mark Reading XML contents

static OFVersionNumber *appVersionOfImportedFile = nil;
+ (void)setAppVersionOfImportedFileFromString:(NSString *)versionString;
{
    if (appVersionOfImportedFile) {
        [appVersionOfImportedFile release];
        appVersionOfImportedFile = nil;
    }
    if (versionString)
        appVersionOfImportedFile = [[OFVersionNumber alloc] initWithVersionString:versionString];
}
+ (OFVersionNumber *)appVersionOfImportedFile;
{
    return appVersionOfImportedFile;
}


#pragma mark -
#pragma mark Writing XML contents

+ (void)appendRect:(CGRect)rect toXML:(OFXMLDocument *)xmlDoc;
{
    [xmlDoc setAttribute:@"x" real:(float)rect.origin.x];
    [xmlDoc setAttribute:@"y" real:(float)rect.origin.y];
    [xmlDoc setAttribute:@"w" real:(float)rect.size.width];
    [xmlDoc setAttribute:@"h" real:(float)rect.size.height];
}

+ (void)appendColorIfNotBlack:(OQColor *)color toXML:(OFXMLDocument *)xmlDoc;
{
    OQColor *rgbColor = [color colorUsingColorSpace:OQColorSpaceRGB];
    if ([rgbColor brightnessComponent] > 0 || [rgbColor alphaComponent] < 1) {
	[color appendXML:xmlDoc];
    }
}

+ (void)appendColorIfNotWhite:(OQColor *)color toXML:(OFXMLDocument *)xmlDoc;
{
    OQColor *rgbColor = [color colorUsingColorSpace:OQColorSpaceRGB];
    if ([rgbColor brightnessComponent] < 1 || [rgbColor saturationComponent] > 0 || [rgbColor alphaComponent] < 1) {
	[color appendXML:xmlDoc];
    }
}

@end


@implementation OFXMLElement (RSExtensions)

- (BOOL)boolValueForAttributeNamed:(NSString *)attribute defaultValue:(BOOL)defaultValue;
{
    NSString *defaultString = stringFromBool(defaultValue);
    return boolFromString([self stringValueForAttributeNamed:attribute defaultValue:defaultString]);
}

@end
