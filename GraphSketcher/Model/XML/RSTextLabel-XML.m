// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSTextLabel-XML.h"

#import "RSGraph-XML.h"
#import "OFObject-XML.h"
#import "RSText-XML.h"

#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLDocument.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/NSFont.h>
#endif

@implementation RSTextLabel (XML)

#pragma mark -
#pragma mark XMLArchiving protocol

+ (NSString *)xmlElementName;
{
    return @"label";
}

- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    OBPRECONDITION(OFISEQUAL([cursor name], [[self class] xmlElementName]));
    
    OFXMLElement *element = [cursor currentElement];
    
    // XML
    _pos.x = [element doubleValueForAttributeNamed:@"x" defaultValue:0];
    _pos.y = [element doubleValueForAttributeNamed:@"y" defaultValue:0];
    
    _owner = nil;
    NSString *idref = [element attributeNamed:@"owner"];
    if (idref) {
        RSGraphElement *owner = [_graph objectForIdentifier:idref];
        if (owner && ![owner hasLabel]) {
            [self setOwner:[_graph objectForIdentifier:idref]];
        }
    }
    
    _rotation = [element realValueForAttributeNamed:@"rotation" defaultValue:(float)_rotation];
    _locked = [element boolValueForAttributeNamed:@"locked" defaultValue:NO];

    // only change the visibility status if the xml element specifically says it's invisible
    NSString *visibleStr;
    if ( (visibleStr = [element attributeNamed:@"visible"]) ) {
	if (boolFromString(visibleStr) == NO) {
	    _visible = NO;
	}
    }
    
    [_text release];
    _text = [[RSText alloc] initWithXML:cursor baseStyle:[_graph defaultBaseStyle]];
    
    return YES;
}

- (BOOL)writeContentsXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
{
    [xmlDoc pushElement:[[self class] xmlElementName]];
    
    [xmlDoc setAttribute:@"id" string:[_graph identiferForObject:self]];
    
    [xmlDoc setAttribute:@"x" double:[self position].x];
    [xmlDoc setAttribute:@"y" double:[self position].y];
    
    if ([self owner]) {
	[xmlDoc setAttribute:@"owner" string:[_graph identiferForObject:[self owner]]];
    }
    
    if ([self rotation]) {
	[xmlDoc setAttribute:@"rotation" real:(float)[self rotation]];
    }
    
    if ([self locked])
	[xmlDoc setAttribute:@"locked" string:stringFromBool([self locked])];
    if (![self isVisible])
	[xmlDoc setAttribute:@"visible" string:stringFromBool([self isVisible])];
    
    // styled text
    OSStyle *baseStyle = [_graph defaultBaseStyle];
    OBASSERT(baseStyle);
    
    [_text appendXML:xmlDoc baseStyle:baseStyle];
    
    [xmlDoc popElement];
    return YES;
}


@end
