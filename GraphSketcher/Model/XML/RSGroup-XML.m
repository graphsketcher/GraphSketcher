// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/XML/RSGroup-XML.m 200244 2013-12-10 00:11:55Z correia $

#import "RSGroup-XML.h"

#import "RSGraph-XML.h"

#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLDocument.h>

@implementation RSGroup (XML)

#pragma mark -
#pragma mark XMLArchiving protocol

+ (NSString *)xmlElementName;
{
    return @"group";
}

- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    OBPRECONDITION(OFISEQUAL([cursor name], [[self class] xmlElementName]));
    
    OFXMLElement *element = [cursor currentElement];
    
    OBASSERT(self == [_graph objectForIdentifier:[element attributeNamed:@"id"]]);
    
    _elements = [[NSMutableArray arrayWithCapacity:5] retain];
    
    NSString *idrefs = [element attributeNamed:@"elements"];
    NSArray *idrefsArray = [idrefs componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    for (NSString *idref in idrefsArray) {
	DEBUG_XML(@"Reading idref: %@", idref);
	RSGraphElement *GE = [_graph objectForIdentifier:idref];
        if(GE == nil)
	    continue;
        
	[_graph setGroup:self forElement:GE];
    }
    
    return YES;
}

- (BOOL)writeContentsXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
{
    [xmlDoc pushElement:[[self class] xmlElementName]];
    
    [xmlDoc setAttribute:@"id" string:[_graph identiferForObject:self]];
    [xmlDoc setAttribute:@"elements" string:[_graph idrefsFromArray:[self elements]]];
    
    [xmlDoc popElement];
    return YES;
}


@end
