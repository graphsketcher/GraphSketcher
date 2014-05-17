// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSFill-XML.h"

#import <GraphSketcherModel/RSGroup.h>

#import "RSGraph-XML.h"
#import <OmniQuartz/OQColor-Archiving.h>

#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLDocument.h>

@implementation RSFill (XML)

#pragma mark -
#pragma mark XMLArchiving protocol

+ (NSString *)xmlElementName;
{
    return @"fill";
}

- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    OBPRECONDITION(OFISEQUAL([cursor name], [[self class] xmlElementName]));
    
    OFXMLElement *element = [cursor currentElement];
    
    // non-XML initializations
    _group = nil;
    _label = nil;  // this is potentially set later by a text label
    _vertices = [[RSGroup alloc] initWithGraph:_graph];
    
    // XML
    _labelPlacement.x = [element realValueForAttributeNamed:@"label-placement-x" defaultValue:0.5f];
    _labelPlacement.y = [element realValueForAttributeNamed:@"label-placement-y" defaultValue:0.5f];
    
    _color = nil;
    if ([cursor openNextChildElementNamed:@"color"]) {
	_color = [[OQColor colorFromXML:cursor] retain];
	[cursor closeElement];
    } else {
	_color = [[OQColor colorWithRed:0 green:0 blue:0 alpha:0.5f] retain];
    }
    
    // vertices
    if ([cursor openNextChildElementNamed:@"vertices"]) {
	
	NSString *idrefs = [[cursor currentElement] attributeNamed:@"ids"];
	NSArray *idrefsArray = [idrefs componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	for (NSString *idref in idrefsArray) {
	    DEBUG_XML(@"Reading fill vertex: %@", idref);
	    RSVertex *V = [_graph objectForIdentifier:idref];
            if (V) {
		[self addVertexAtEnd:V];
	    }
	    else {
		NSLog(@"XML error: Fill vertex '%@' not found.", idref);
	    }
	}
	
	[cursor closeElement];
    }
    else {
	NSLog(@"%s: Element %@ at cursor path %@ is missing child 'vertices'", __PRETTY_FUNCTION__, element, [cursor currentPath]);
    }
    
    return YES;
}

- (BOOL)writeContentsXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
{
    [xmlDoc pushElement:[[self class] xmlElementName]];
    
    [RSGraphElement appendColorIfNotBlack:[self color] toXML:xmlDoc];
    
    [xmlDoc setAttribute:@"id" string:[_graph identiferForObject:self]];
    if ([self label]) {
	[xmlDoc setAttribute:@"label-placement-x" real:(float)[self labelPlacement].x];
	[xmlDoc setAttribute:@"label-placement-y" real:(float)[self labelPlacement].y];
    }
    
    [xmlDoc pushElement:@"vertices"];
    [xmlDoc setAttribute:@"ids" string:[_graph idrefsFromArray:[[self vertices] elements]]];
    [xmlDoc popElement];
    
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
