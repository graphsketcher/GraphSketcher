// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/XML/RSLine-XML.m 200244 2013-12-10 00:11:55Z correia $

#import "RSLine-XML.h"

#import <GraphSketcherModel/RSGroup.h>
#import <OmniQuartz/OQColor-Archiving.h>
#import "RSVertex-XML.h"
#import "RSGraph-XML.h"

#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLDocument.h>

static NSString *nameFromDashStyle(NSUInteger dash)
{
    switch (dash) {
	case 0:
	    return @"solid";
	case 1:
	    return @"solid";  // "none" and "solid" mean the same thing here
	case 2:
	    return @"dots";
	case 3:
	    return @"dashes";
	case 4:
	    return @"dashes-spaced";
	case 5:
	    return @"dashes-long";
	case 6:
	    return @"dashes-dots";
	case RS_ARROWS_DASH:
	    return @"arrows";
	case RS_REVERSE_ARROWS_DASH:
	    return @"reverse-arrows";
	case RS_RAILROAD_DASH:
	    return @"railroad";
	default:
	    OBASSERT_NOT_REACHED("Unknown dash style");
	    break;
    }
    return nil;
}

static NSUInteger dashStyleFromName(NSString *name)
{
    if ([name isEqualToString:@"solid"])
	return 0;
    else if ([name isEqualToString:@"dots"])
	return 2;
    else if ([name isEqualToString:@"dashes"])
	return 3;
    else if ([name isEqualToString:@"dashes-spaced"])
	return 4;
    else if ([name isEqualToString:@"dashes-long"])
	return 5;
    else if ([name isEqualToString:@"dashes-dots"])
	return 6;
    else if ([name isEqualToString:@"arrows"])
	return RS_ARROWS_DASH;
    else if ([name isEqualToString:@"reverse-arrows"])
	return RS_REVERSE_ARROWS_DASH;
    else if ([name isEqualToString:@"railroad"])
	return RS_RAILROAD_DASH;
    else {
	OBASSERT_NOT_REACHED("Unknown dash style name");
	return 0;  // solid
    }
}


@implementation RSLine (XML)

#pragma mark -
#pragma mark XMLArchiving protocol

+ (NSString *)xmlElementName;
{
    return @"line";
}

- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    OBPRECONDITION(OFISEQUAL([cursor name], [[self class] xmlElementName]));
    
    OFXMLElement *element = [cursor currentElement];
    
    // non-XML initializations
    _group = nil;
    _label = nil;  // this is potentially set later by a text label
    _hasChanged = NO;
    
    // XML
    _width = [element realValueForAttributeNamed:@"width" defaultValue:2.0f];
    _slide = [element realValueForAttributeNamed:@"label-placement" defaultValue:0.5f];
    _labelDistance = [element realValueForAttributeNamed:@"label-distance" defaultValue:2.0f];
    NSString *dashString = [element stringValueForAttributeNamed:@"dash" defaultValue:@"solid"];
    _dash = dashStyleFromName(dashString);
    
    _color = nil;
    if ([cursor openNextChildElementNamed:@"color"]) {
	_color = [[OQColor colorFromXML:cursor] retain];
	[cursor closeElement];
    } else {
	_color = [[OQColor blackColor] retain];
    }
    
    return YES;
}

- (BOOL)writeContentsXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
{
    [xmlDoc pushElement:[[self class] xmlElementName]];
    
    [RSGraphElement appendColorIfNotBlack:[self color] toXML:xmlDoc];
    
    [xmlDoc setAttribute:@"id" string:[_graph identiferForObject:self]];
    [xmlDoc setAttribute:@"width" real:(float)[self width]];
    if ([self dash])
	[xmlDoc setAttribute:@"dash" string:nameFromDashStyle([self dash])];
    if ([self label]) {
	[xmlDoc setAttribute:@"label-placement" real:(float)[self slide]];
	[xmlDoc setAttribute:@"label-distance" real:(float)[self labelDistance]];
    }
    
    if ([self isKindOfClass:[RSConnectLine class]]) {
	[xmlDoc setAttribute:@"class" string:@"connect"];
	[xmlDoc setAttribute:@"method" string:nameFromConnectMethod([self connectMethod])];
	
	[xmlDoc pushElement:@"vertices"];
	[xmlDoc setAttribute:@"ids" string:[_graph idrefsFromArray:[[self vertices] elements]]];
	[xmlDoc popElement];
    }
    else if ([self isKindOfClass:[RSFitLine class]]) {
	[xmlDoc setAttribute:@"class" string:@"fit"];
	//not necessary for now//[xmlDoc setAttribute:@"method" string:@"linear-regression"];
	[xmlDoc setAttribute:@"v1" string:[_graph identiferForObject:[self startVertex]]];
	[xmlDoc setAttribute:@"v2" string:[_graph identiferForObject:[self endVertex]]];
	
	[xmlDoc pushElement:@"data"];
	[xmlDoc setAttribute:@"ids" string:[_graph idrefsFromArray:[[(RSFitLine *)self data] elements]]];
	[xmlDoc popElement];
    }
    
    [xmlDoc popElement];
    return YES;
}

- (NSArray *)childObjectsForXML;
{
    NSArray *vertices = [[self vertices] elements];
    
    if ([self label]) {
        return [vertices arrayByAddingObject:[self label]];
    }
    
    return vertices;
}


@end


#pragma mark -
@implementation RSConnectLine (XML)

+ (NSString *)xmlClassName;
{
    return @"connect";
}

- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    [super readContentsXML:cursor error:outError];
    
    OFXMLElement *element = [cursor currentElement];
    
    OBASSERT([[element attributeNamed:@"class"] isEqualToString:[[self class] xmlClassName]]);
    
    NSString *connectString = [element stringValueForAttributeNamed:@"method" defaultValue:@"curved"];
    _connect = connectMethodFromName(connectString);
    _order = RS_ORDER_CREATION;  // not used
    
     // vertices
    _vertices = [[RSGroup alloc] initWithGraph:_graph];
    
    if ([cursor openNextChildElementNamed:@"vertices"]) {
     
	NSString *idrefs = [[cursor currentElement] attributeNamed:@"ids"];
	NSArray *idrefsArray = [idrefs componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	for (NSString *idref in idrefsArray) {
	    DEBUG_XML(@"Reading connect-line vertex: %@", idref);
	    RSVertex *V = [_graph objectForIdentifier:idref];
	    if (V) {
		[self addVertexAtEnd:V];
	    }
	    else {
		NSLog(@"XML error: ConnectLine vertex '%@' not found.", idref);
	    }
	}
	
	[cursor closeElement];
    }
    else {
	NSLog(@"%s: Element %@ at cursor path %@ is missing child 'vertices'", __PRETTY_FUNCTION__, element, [cursor currentPath]);
    }
    
    // non-XML
    _v1 = [[RSVertex alloc] initWithGraph:_graph];
    _v2 = [[RSVertex alloc] initWithGraph:_graph];
    
    return YES;
}

@end


#pragma mark -
@implementation RSFitLine (XML)

+ (NSString *)xmlClassName;
{
    return @"fit";
}

- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    [super readContentsXML:cursor error:outError];
    
    OFXMLElement *element = [cursor currentElement];
    
    OBASSERT([[element attributeNamed:@"class"] isEqualToString:[[self class] xmlClassName]]);
    
    NSString *methodString = [element attributeNamed:@"method"];
    if (methodString && ![methodString isEqualToString:@"linear-regression"]) {
	NSLog(@"%s: Element %@ at cursor path %@ has unknown value '%@' for attribute 'method'.", __PRETTY_FUNCTION__, _identifier, [cursor currentPath], methodString);
    }
    
    NSString *idref;
    BOOL needResetEndpoints = NO;
    if ( (idref = [element attributeNamed:@"v1"]) ) {
	_v1 = [[_graph objectForIdentifier:idref] retain];
    }
    else {
	//NSLog(@"%s: Element %@ at cursor path %@ is missing attribute 'v1'", __PRETTY_FUNCTION__, element, [cursor currentPath]);
	_v1 = [[RSVertex alloc] initWithGraph:_graph];
	needResetEndpoints = YES;
    }
    [_v1 addParent:self];
    if ( (idref = [element attributeNamed:@"v2"]) ) {
	_v2 = [[_graph objectForIdentifier:idref] retain];
    }
    else {
	//NSLog(@"%s: Element %@ at cursor path %@ is missing attribute 'v2'", __PRETTY_FUNCTION__, element, [cursor currentPath]);
	_v2 = [[RSVertex alloc] initWithGraph:_graph];
	needResetEndpoints = YES;
    }
    [_v2 addParent:self];

    
    // data
    _data = [[RSGroup alloc] initWithGraph:_graph];
    
    if ([cursor openNextChildElementNamed:@"data"]) {
	
	NSString *idrefs = [[cursor currentElement] attributeNamed:@"ids"];
	NSArray *idrefsArray = [idrefs componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	for (NSString *idref in idrefsArray) {
	    DEBUG_XML(@"Reading fit-line data: %@", idref);
	    RSVertex *V = [_graph objectForIdentifier:idref];
	    if (V) {
		[_data addElement:V];
	    }
	    else {
		NSLog(@"XML error: Best-fit line vertex '%@' not found.", idref);
	    }
	}
	[_data addParent:self];
	
	[cursor closeElement];
    }
    else {
	NSLog(@"%s: Element %@ at cursor path %@ is missing child 'data'", __PRETTY_FUNCTION__, element, [cursor currentPath]);
    }
    
    
    // non-XML
    _needsRecompute = NO;
    [self updateParameters];
    if (needResetEndpoints) {
	[self resetEndpoints];
    }
    
    return YES;
}

- (NSArray *)childObjectsForXML;
{
    NSArray *lineChildren = [super childObjectsForXML];
    
    return [lineChildren arrayByAddingObjectsFromArray:[[self data] elements]];
}

@end
