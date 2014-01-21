// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/XML/RSVertex-XML.m 200244 2013-12-10 00:11:55Z correia $

#import "RSVertex-XML.h"

#import <GraphSketcherModel/RSGraph.h>
#import "OFObject-XML.h"
#import <OmniQuartz/OQColor-Archiving.h>

#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/CFArray-OFExtensions.h>

@implementation RSVertex (XML)

#pragma mark -
#pragma mark XMLArchiving protocol

+ (NSString *)xmlElementName;
{
    return @"vertex";
}

- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    OBPRECONDITION(OFISEQUAL([cursor name], [[self class] xmlElementName]));
    
    OFXMLElement *element = [cursor currentElement];
    
    // non-XML initializations
    _group = nil;
    
    [_parents release];
    _parents = (NSMutableArray *)OFCreateNonOwnedPointerArray();  // Creates an NSMutableArray that doesn't retain its members.
    _label = nil;  // this is potentially set later by a text label
    _sortValue = 0;
    
    // XML
    _p.x = [element doubleValueForAttributeNamed:@"x" defaultValue:0];
    _p.y = [element doubleValueForAttributeNamed:@"y" defaultValue:0];
    _width = [element realValueForAttributeNamed:@"width" defaultValue:2.0f];
    _shape = shapeFromName([element stringValueForAttributeNamed:@"shape" defaultValue:@"none"]);
    
    _arrowParent = nil;
    NSString *idref = [element attributeNamed:@"arrow-parent"];
    if (idref && ![idref isEqualToString:@""])
	_arrowParent = [_graph objectForIdentifier:idref];
    
    CGFloat degreesLabelPosition = [element realValueForAttributeNamed:@"label-placement" defaultValue:0];
    CGFloat adjustedLabelPosition = degreesLabelPosition * (CGFloat)M_PI / 180;      // convert to radians
    if (_shape == RS_BAR_VERTICAL)  // On vertical bars, the label position setting starts at north instead of east.
        adjustedLabelPosition -= (CGFloat)PIOVER2;
    _labelPosition = adjustedLabelPosition;
    
    _labelDistance = [element realValueForAttributeNamed:@"label-distance" defaultValue:5];
    _locked = [element boolValueForAttributeNamed:@"locked" defaultValue:NO];
    
    [_color release];
    _color = nil;
    if ([cursor openNextChildElementNamed:@"color"]) {
	_color = [[OQColor colorFromXML:cursor] retain];
	[cursor closeElement];
    } else {
	_color = [[OQColor blackColor] retain];
    }
    
    if ([cursor openNextChildElementNamed:@"snapped-to"]) {
	OFXMLElement *snappedElement = nil;
	while ( (snappedElement = [cursor nextChild]) ) {
	    if ([[snappedElement name] isEqualToString:@"element"]) {
		idref = [snappedElement attributeNamed:@"idref"];
		if (!idref) {
		    NSLog(@"No 'idref' attribute found.");
		    continue;
		}
		CGFloat param = [snappedElement realValueForAttributeNamed:@"param" defaultValue:0.5f];
		
		RSGraphElement *GE = [_graph objectForIdentifier:idref];
		if (!GE) {
		    NSLog(@"XML error: Snapped-to element not found!");
		    continue;
		}
		[self addSnappedTo:GE withParam:[NSNumber numberWithFloat:(float)param]];
	    }
	}
	[cursor closeElement];
    }
    
    return YES;
}

- (BOOL)writeContentsXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
{
    [xmlDoc pushElement:[[self class] xmlElementName]];
    
    [RSGraphElement appendColorIfNotBlack:[self color] toXML:xmlDoc];
    
    [xmlDoc setAttribute:@"id" string:[_graph identiferForObject:self]];
    RSDataPoint coords = [self position];
    [xmlDoc setAttribute:@"x" double:coords.x];
    [xmlDoc setAttribute:@"y" double:coords.y];
//    NSLog(@"y: %.*g", DBL_DIG, coords.y);
    
    [xmlDoc setAttribute:@"width" real:(float)[self width]];
    if ([self shape])
	[xmlDoc setAttribute:@"shape" string:nameFromShape([self shape])];
    if ([self arrowParent])
	[xmlDoc setAttribute:@"arrow-parent" string:[_graph identiferForObject:[self arrowParent]]];
    if ([self label]) {
        CGFloat adjustedPosition = [self labelPosition];
        if ([self shape] == RS_BAR_VERTICAL)  // On vertical bars, the label position setting starts at north instead of east.
            adjustedPosition += (CGFloat)PIOVER2;
	CGFloat degreesPosition = adjustedPosition * 180 / (CGFloat)M_PI;
	[xmlDoc setAttribute:@"label-placement" real:(float)degreesPosition];
	[xmlDoc setAttribute:@"label-distance" real:(float)[self labelDistance]];
    }
	
    if ([self locked])
	[xmlDoc setAttribute:@"locked" string:stringFromBool([self locked])];
    
    RSGroup *snappedTo = [self snappedTo];
    if (snappedTo && [snappedTo count]) {
	[xmlDoc pushElement:@"snapped-to"];
	for (RSGraphElement *element in [snappedTo elements]) {
            //OBASSERT([_graph containsElement:element]);
            if (![_graph containsElement:element])
                continue;
            
	    [xmlDoc pushElement:@"element"];
	    [xmlDoc setAttribute:@"idref" string:[_graph identiferForObject:element]];
	    [xmlDoc setAttribute:@"param" string:[[self paramOfSnappedToElement:element] stringValue]];
	    [xmlDoc popElement];
	}
	[xmlDoc popElement];
    }
    
    [xmlDoc popElement];
    return YES;
}


@end
