// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSAxis-XML.h"

#import <GraphSketcherModel/RSGrid.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSGraph.h>

#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLDocument.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/NSFont.h>
#endif

#import "OFObject-XML.h"
#import <OmniQuartz/OQColor-Archiving.h>

@implementation RSAxis (XML)


#pragma mark -
#pragma mark XMLArchiving protocol

+ (NSString *)xmlElementName;
{
    return @"axis";
}

- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    OBPRECONDITION(OFISEQUAL([cursor name], [[self class] xmlElementName]));
    
    OFXMLElement *element = [cursor currentElement];
    
    // XML
    
    //////
    // axis
    _orientation = orientationFromName([element attributeNamed:@"dimension"]);
    _min = [element doubleValueForAttributeNamed:@"min" defaultValue:0];
    _max = [element doubleValueForAttributeNamed:@"max" defaultValue:10];
    _userModifiedRange = [element boolValueForAttributeNamed:@"userModifiedRange" defaultValue:YES];
    [self setAxisType:axisTypeFromName([element stringValueForAttributeNamed:@"scale" defaultValue:@"linear"])];
    _placement = placementFromName([element attributeNamed:@"placement"]);
    _extent = extentFromName([element stringValueForAttributeNamed:@"extent" defaultValue:@"full"]);
    
    _width = (CGFloat)[element realValueForAttributeNamed:@"width" defaultValue:2.0f];
    _shape = shapeFromName([element stringValueForAttributeNamed:@"end-shape" defaultValue:@"none"]);
    _displayAxis = [element boolValueForAttributeNamed:@"visible" defaultValue:YES];
    
    _color = nil;
    if ([cursor openNextChildElementNamed:@"color"]) {
	_color = [[OQColor colorFromXML:cursor] retain];
	[cursor closeElement];
    } else {
	_color = [[OQColor blackColor] retain];
    }
    
    
    //////
    // ticks
    _tickType = 0;
    _spacingSigFigs = 0;
    if ([cursor openNextChildElementNamed:@"ticks"]) {
	element = [cursor currentElement];
	
	_spacing = [element doubleValueForAttributeNamed:@"spacing" defaultValue:1];
	_userSpacing = [element doubleValueForAttributeNamed:@"user-spacing" defaultValue:0];
	_tickLayout = tickLayoutFromName([element stringValueForAttributeNamed:@"layout" defaultValue:@"simple"]);
	_tickWidthIn = [element realValueForAttributeNamed:@"width-in" defaultValue:3];
	_tickWidthOut = [element realValueForAttributeNamed:@"width-out" defaultValue:1];
	_displayTicks = [element boolValueForAttributeNamed:@"visible" defaultValue:YES];
	
	[cursor closeElement];
    }
    else {  // no <ticks> element found
	_spacing = 1;  // TODO: this should get calculated automatically from the data, not set arbitrarily
	_userSpacing = 0;
	_tickLayout = RSAxisTickLayoutSimple;
	_tickWidthIn = 3;
	_tickWidthOut = 1;
	_displayTicks = NO;
    }
    
    
    //////
    // grid
    _grid = [[RSGrid alloc] initWithOrientation:_orientation spacing:_spacing];
    if ([cursor openNextChildElementNamed:@"grid"]) {
	element = [cursor currentElement];
	
	[_grid setSpacing:[element doubleValueForAttributeNamed:@"spacing" defaultValue:_spacing]];
	[_grid setWidth:[element realValueForAttributeNamed:@"width" defaultValue:1]];
	[_grid setDisplayGrid:[element boolValueForAttributeNamed:@"visible" defaultValue:YES]];
	
	if ([cursor openNextChildElementNamed:@"color"]) {
	    [_grid setColor:[OQColor colorFromXML:cursor]];
	    [cursor closeElement];
	}
	else {
	    [_grid setColor:[OQColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1]];
	}
        
        _grid.dotted = [element boolValueForAttributeNamed:@"dotted" defaultValue:NO];
	
	[cursor closeElement];
    }
    else {  // no <grid> element found
	[_grid setWidth:1];
	[_grid setColor:[OQColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1]];
	[_grid setDisplayGrid:NO];
        _grid.dotted = NO;
    }
    
    
    //////
    // tick labels
    if( _orientation == RS_ORIENTATION_HORIZONTAL ) {
	_labelDistance = 3;
	_tickLabelPadding = DEFAULT_TICK_LABEL_PADDING_HORIZONTAL;
    } else {
	_labelDistance = 5;
	_tickLabelPadding = DEFAULT_TICK_LABEL_PADDING_VERTICAL;
    }
    _userLabels = [[NSMutableDictionary alloc] init];
    
    _minLabel = nil;
    _maxLabel = nil;
    if ([cursor openNextChildElementNamed:@"tick-labels"]) {
	element = [cursor currentElement];
	
	NSString *str;
	if ( (str = [element attributeNamed:@"distance"]) ) {
	    _labelDistance = [str floatValue];
	}
	if ( (str = [element attributeNamed:@"padding"]) ) {
	    _tickLabelPadding = [str floatValue];
	}
        
        _scientificNotation = scientificNotationSettingFromName([element stringValueForAttributeNamed:@"scientific-notation" defaultValue:@"auto"]);

	_displayTickLabels = [element boolValueForAttributeNamed:@"visible" defaultValue:YES];
	
	if ([cursor openNextChildElementNamed:@"user-labels"]) {
	    OFXMLElement *labelElement = nil;
	    while ( (labelElement = [cursor nextChild]) ) {
		if ([[labelElement name] isEqualToString:@"label"]) {
		    NSString *key = [labelElement attributeNamed:@"tick"];
		    NSString *idref = [labelElement attributeNamed:@"idref"];
		    if (!idref) {
			NSLog(@"No 'idref' attribute found.");
			continue;
		    }
		    id label = [_graph objectForIdentifier:idref];
		    OBASSERT(label);
		    
		    if ([key isEqualToString:@"minLabel"]) {
			_minLabel = label;
			[_userLabels setObject:label forKey:key];
			[label setTickValue:_min axisOrientation:_orientation];
		    }
		    else if ([key isEqualToString:@"maxLabel"]) {
			_maxLabel = label;
			[_userLabels setObject:label forKey:key];
			[label setTickValue:_max axisOrientation:_orientation];
		    }
		    else {
			[self setUserLabel:label forTick:[key doubleValue] andKey:key];
		    }
		}
	    }
	    
	    [cursor closeElement];
	}
	
	[cursor closeElement];
    }
    else {  // no <tick-labels> element found
	_displayTickLabels = NO;
    }
    
    // ensure we have min and max labels
    if (!_minLabel) {
	DEBUG_XML(@"No minLabel found");
	_minLabel = [[RSTextLabel alloc] initWithGraph:_graph fontDescriptor:nil];
	[_minLabel setPartOfAxis:YES];
	[_userLabels setObject:_minLabel forKey:@"minLabel"];
	[_minLabel release];
	[self setMin:_min];  // sets the right text for the label
    }
    if (!_maxLabel) {
	DEBUG_XML(@"No maxLabel found");
	_maxLabel = [[RSTextLabel alloc] initWithGraph:_graph fontDescriptor:nil];
	[_maxLabel setPartOfAxis:YES];
	[_userLabels setObject:_maxLabel forKey:@"maxLabel"];
	[_maxLabel release];
	[self setMax:_max];  // sets the right text for the label
    }
    
    
    //////
    // title
    _axisTitle = nil;
    if ([cursor openNextChildElementNamed:@"title"]) {
	element = [cursor currentElement];
	
	NSString *idref = [element attributeNamed:@"label"];
	if (idref) {
	    _axisTitle = [[_graph objectForIdentifier:idref] retain];
	}
	else {
	    _axisTitle = [[RSTextLabel alloc] initWithGraph:_graph fontDescriptor:nil];
	}
	[_axisTitle setPartOfAxis:YES];
	[self rotateTitle];  // in case the rotation is not in the label's xml element
	
	_titleDistance = [element realValueForAttributeNamed:@"distance" defaultValue:18];
	_titlePlacement = (CGFloat)[element realValueForAttributeNamed:@"placement" defaultValue:0.5f];
	[self setDisplayTitle:[element boolValueForAttributeNamed:@"visible" defaultValue:YES]];
	
	[cursor closeElement];
    }
    else {  // no <title> element found
	_axisTitle = [[RSTextLabel alloc] initWithGraph:_graph fontDescriptor:nil];
	[_axisTitle setPartOfAxis:YES];
	[self setDisplayTitle:NO];
	[_axisTitle setText:labelNameFromOrientation(_orientation)];
	[self rotateTitle];
	
	_titleDistance = 18;
    }
    
    _cachedTickArray = nil;
    _tickLabelSpacing = 0;
    _tickLabelNumberFormatter = nil;
    [self resetNumberFormatters];
    
    return YES;
}

- (BOOL)writeContentsXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
{
    [xmlDoc pushElement:[[self class] xmlElementName]];
    // attributes
    [xmlDoc setAttribute:@"id" string:[_graph identiferForObject:self]];
    [xmlDoc setAttribute:@"dimension" string:nameFromOrientation([self orientation])];
    [xmlDoc setAttribute:@"min" double:[self min]];
    [xmlDoc setAttribute:@"max" double:[self max]];
    [xmlDoc setAttribute:@"userModifiedRange" string:stringFromBool([self userModifiedRange])];
    [xmlDoc setAttribute:@"scale" string:nameFromAxisType(_axisType)];
    [xmlDoc setAttribute:@"width" real:(float)[self width]];
    if (_shape)
	[xmlDoc setAttribute:@"end-shape" string:nameFromShape(_shape)];
    [xmlDoc setAttribute:@"placement" string:nameFromPlacement([self placement])];
    [xmlDoc setAttribute:@"extent" string:nameFromExtent([self extent])];
    [xmlDoc setAttribute:@"visible" string:stringFromBool([self displayAxis])];
    
    [RSGraphElement appendColorIfNotBlack:[self color] toXML:xmlDoc];
    
    // ticks
    [xmlDoc pushElement:@"ticks"];
    [xmlDoc setAttribute:@"spacing" double:[self spacing]];
    if (_userSpacing)
	[xmlDoc setAttribute:@"user-spacing" double:[self userSpacing]];
    [xmlDoc setAttribute:@"layout" string:nameFromTickLayout([self tickLayout])];
    [xmlDoc setAttribute:@"width-in" real:(float)[self tickWidthIn]];
    [xmlDoc setAttribute:@"width-out" real:(float)[self tickWidthOut]];
    [xmlDoc setAttribute:@"visible" string:stringFromBool([self displayTicks])];
    [xmlDoc popElement];
    
    // grid
    RSGrid *grid = [self grid];
    [xmlDoc pushElement:@"grid"];
    [xmlDoc setAttribute:@"spacing" double:[grid spacing]];
    [xmlDoc setAttribute:@"width" real:(float)[grid width]];
    [xmlDoc setAttribute:@"extends-past-axis" string:stringFromBool([grid extendsPastAxis])];
    [xmlDoc setAttribute:@"visible" string:stringFromBool([grid displayGrid])];
    [[grid color] appendXML:xmlDoc];  // background color
    if (grid.dotted) {
        [xmlDoc setAttribute:@"dotted" string:stringFromBool(grid.dotted)];
    }
    [xmlDoc popElement];
    
    // tick-labels
    [xmlDoc pushElement:@"tick-labels"];
    [xmlDoc setAttribute:@"distance" real:(float)[self labelDistance]];
    [xmlDoc setAttribute:@"padding" real:(float)_tickLabelPadding];
    if (_scientificNotation != RSScientificNotationSettingAuto) {
        [xmlDoc setAttribute:@"scientific-notation" string:nameFromScientificNotationSetting(_scientificNotation)];
    }
    [xmlDoc setAttribute:@"visible" string:stringFromBool([self displayTickLabels])];
    if ([_userLabels count]) {
	[xmlDoc pushElement:@"user-labels"];
	NSDictionary *userLabels = [self userLabelsDictionary];
	for (NSString *key in userLabels) {
	    [xmlDoc pushElement:@"label"];
	    [xmlDoc setAttribute:@"tick" string:key];
	    [xmlDoc setAttribute:@"idref" string:[_graph identiferForObject:[userLabels objectForKey:key]]];
	    [xmlDoc popElement];
	}
	[xmlDoc popElement];
    }
    [xmlDoc popElement];
    
    // title
    [xmlDoc pushElement:@"title"];
    [xmlDoc setAttribute:@"label" string:[_graph identiferForObject:[self title]]];
    [xmlDoc setAttribute:@"distance" real:(float)[self titleDistance]];
    [xmlDoc setAttribute:@"placement" real:(float)[self titlePlacement]];
    [xmlDoc setAttribute:@"visible" string:stringFromBool([self displayTitle])];
    [xmlDoc popElement];
    
    [xmlDoc popElement];
    return YES;
}



@end
