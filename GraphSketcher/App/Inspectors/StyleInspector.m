// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/Inspectors/StyleInspector.m 200244 2013-12-10 00:11:55Z correia $

#import "StyleInspector.h"

#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/NSBezierPath-RSExtensions.h>
#import <GraphSketcherModel/OFPreference-RSExtensions.h>
#import <GraphSketcherModel/RSLog.h>
#import <OmniQuartz/OQColor.h>

#import "GraphDocument.h"
#import "RSSelector.h"
#import "RSMode.h"
#import "NSSegmentedControl-RSExtensions.h"
#import "OIInspector-RSExtensions.h"
#import "OpacityControlCell.h"


@implementation StyleInspector


#pragma mark -
#pragma mark Class methods

#define DASH_RECT_WIDTH (100)
#define DASH_RECT_HEIGHT (10)
#define DASH_RECT_INDENT (4)

- (void)setDashPictureForTag:(NSInteger)dash {
    NSImage *dashImg = [[NSImage alloc] initWithSize:NSMakeSize(DASH_RECT_WIDTH, DASH_RECT_HEIGHT)];
    NSBezierPath *P = [NSBezierPath bezierPath];
    [P moveToPoint:NSMakePoint(DASH_RECT_INDENT, DASH_RECT_HEIGHT/2)];
    [P lineToPoint:NSMakePoint(DASH_RECT_WIDTH, DASH_RECT_HEIGHT/2)];
    [P setLineWidth:2];
    
    // set dash style
    CGFloat style[] = {0,0,0,0};
    if( dash > 1 && dash <= 10 ) {
	if( dash == 2 ) {
	    style[0] = 2;  style[1] = 2;  style[2] = 2;  style[3] = 2;
	}
	else if( dash == 3 ) {
	    style[0] = 5;  style[1] = 2;  style[2] = 5;  style[3] = 2;
	}
	else if( dash == 4 ) {
	    style[0] = 5;  style[1] = 5;  style[2] = 5;  style[3] = 5;
	}
	else if( dash == 5 ) {
	    style[0] = 10;  style[1] = 2;  style[2] = 10;  style[3] = 2;
	}
	else if( dash == 6 ) {
	    style[0] = 10;  style[1] = 2;  style[2] = 3;  style[3] = 2;
	}
	[P setLineDash:style count:4 phase:0];
    }
    
    // draw image
    [dashImg lockFocus];
    
    [[NSColor blackColor] set];
    [P stroke];
    
    if( dash >= RS_ARROWS_DASH ) {
	CGFloat w = 1.5f;
	NSPoint p = NSMakePoint(DASH_RECT_INDENT + w*6 + 2, DASH_RECT_HEIGHT/2);
	CGFloat spacing = (DASH_RECT_WIDTH - DASH_RECT_INDENT)/5;
	for( ; p.x < DASH_RECT_WIDTH; p.x += spacing ) {
	    if( dash == RS_ARROWS_DASH || dash == RS_REVERSE_ARROWS_DASH ) {
		P = [NSBezierPath arrowheadWithBaseAtPoint:p width:w*3 height:w*3];
		if( dash == RS_ARROWS_DASH ) {  // only need to rotate right-pointing arrows
		    NSRect r = NSMakeRect(0,0,w*3,w*3);
		    r.origin = p;
		    [P rotateInFrame:r byDegrees:180];
		}
		[P fill];
	    }
	    else if( dash == RS_RAILROAD_DASH ) {
		P = [[NSBezierPath bezierPath] appendTickAtPoint:p width:w height:w*4];
		[P fill];
	    }
	}
    }
    // stop drawing
    [dashImg unlockFocus];
    
    // set popup menu item
    NSMenu *dashPopUpMenu = [_dashPopUp menu];
    [[dashPopUpMenu itemWithTag:dash] setImage:dashImg];
    [[dashPopUpMenu itemWithTag:dash] setTitle:@""];
    
    [dashImg release];
}


#define SHAPE_RECT_SIZE NSMakeSize(14, 14)

- (void)setShapePictureForTag:(NSInteger)shape {
    NSImage *img = [[[NSImage alloc] initWithSize:SHAPE_RECT_SIZE] autorelease];
    NSBezierPath *P = [NSBezierPath bezierPath];
    
    // initialize variables
    NSRect r;
    //NSPoint p = NSMakePoint(15/2, 15/2);
    NSPoint p = NSMakePoint(SHAPE_RECT_SIZE.width/2, SHAPE_RECT_SIZE.height/2);
    NSPoint s, t; // for creating the star, etc.
    CGFloat b, c; // for creating the X, etc.
    CGFloat w = 2;
    
    // construct shape path:
    if ( shape == RS_CIRCLE ) {
	r.origin.x = p.x - w*2;
	r.origin.y = p.y - w*2;
	r.size.width = w*4;
	r.size.height = w*4;
	P = [NSBezierPath bezierPathWithOvalInRect:r];
    }
    else if ( shape == RS_TRIANGLE ) {
	//s.x = w*0.8660254; //cos(30)
	//s.y = w*0.5; //sin(30);
	// these parameters give the triangle the same area as the square:
	s.x = (CGFloat)(w*0.759835686*4);
	s.y = (CGFloat)(w*0.438691338*4);
	P = [NSBezierPath bezierPath];
	// construct path
	[P moveToPoint:NSMakePoint(p.x - s.x, p.y - s.y)];
	[P lineToPoint:NSMakePoint(p.x + s.x, p.y - s.y)];
	[P lineToPoint:NSMakePoint(p.x, p.y + s.x)]; // correct for equilateral triangle
	[P closePath];
    }
    else if ( shape == RS_SQUARE ) {
	r.origin.x = p.x - w*2;
	r.origin.y = p.y - w*2;
	r.size.width = w*4;
	r.size.height = w*4;
	P = [NSBezierPath bezierPathWithRect:r];  // simply makes a rect bezier path
    }
    else if ( shape == RS_STAR ) {
	b = (CGFloat)(w*0.8*4);  // scaling factor
	// offsets for star points:
	s.x = (CGFloat)(b*0.8660254);//cos(30);
	s.y = b*0.5f;//sin(30);
	// offsets for star inners:
	t.x = b/2*0.5f;//cos(60);
	t.y = (CGFloat)(b/2*0.8660254);//sinf(60);
	P = [NSBezierPath bezierPath];
	// construct path
	[P moveToPoint:NSMakePoint(p.x, p.y + b)];
	[P lineToPoint:NSMakePoint(p.x - t.x, p.y + t.y)];
	[P lineToPoint:NSMakePoint(p.x - s.x, p.y + s.y)];
	[P lineToPoint:NSMakePoint(p.x - b/2, p.y)];
	[P lineToPoint:NSMakePoint(p.x - s.x, p.y - s.y)];
	[P lineToPoint:NSMakePoint(p.x - t.x, p.y - t.y)];
	[P lineToPoint:NSMakePoint(p.x, p.y - b)];
	[P lineToPoint:NSMakePoint(p.x + t.x, p.y - t.y)];
	[P lineToPoint:NSMakePoint(p.x + s.x, p.y - s.y)];
	[P lineToPoint:NSMakePoint(p.x + b/2, p.y)];
	[P lineToPoint:NSMakePoint(p.x + s.x, p.y + s.y)];
	[P lineToPoint:NSMakePoint(p.x + t.x, p.y + t.y)];
	[P closePath];
    }
    else if ( shape == RS_DIAMOND ) {
	b = (CGFloat)(w*0.70710678*4); // sqrt(2)/2
	P = [NSBezierPath bezierPath];
	// construct path
	[P moveToPoint:NSMakePoint(p.x - b, p.y)];
	[P lineToPoint:NSMakePoint(p.x, p.y - b)];
	[P lineToPoint:NSMakePoint(p.x + b, p.y)];
	[P lineToPoint:NSMakePoint(p.x, p.y + b)];
	[P closePath];
    }
    else if ( shape == RS_X ) {
	b = 5*w/2; // the "big" dimension of the X
	c = 3*w/2; // the "small" dimension of the X
	P = [NSBezierPath bezierPath];
	// construct path
	[P moveToPoint:NSMakePoint(p.x + w/2, p.y)];
	[P lineToPoint:NSMakePoint(p.x + b, p.y + c)];
	[P lineToPoint:NSMakePoint(p.x + c, p.y + b)];
	[P lineToPoint:NSMakePoint(p.x, p.y + w/2)];
	[P lineToPoint:NSMakePoint(p.x - c, p.y + b)];
	[P lineToPoint:NSMakePoint(p.x - b, p.y + c)];
	[P lineToPoint:NSMakePoint(p.x - w/2, p.y)];
	[P lineToPoint:NSMakePoint(p.x - b, p.y - c)];
	[P lineToPoint:NSMakePoint(p.x - c, p.y - b)];
	[P lineToPoint:NSMakePoint(p.x, p.y - w/2)];
	[P lineToPoint:NSMakePoint(p.x + c, p.y - b)];
	[P lineToPoint:NSMakePoint(p.x + b, p.y - c)];
	[P closePath];
    }
    else if ( shape == RS_CROSS ) {
	b = 5*w/2; // the "big" dimension of the cross
	c = w/2; // the "small" dimension of the cross
	P = [NSBezierPath bezierPath];
	// construct path
	[P moveToPoint:NSMakePoint(p.x + c, p.y + c)];
	[P lineToPoint:NSMakePoint(p.x + c, p.y + b)];
	[P lineToPoint:NSMakePoint(p.x - c, p.y + b)];
	[P lineToPoint:NSMakePoint(p.x - c, p.y + c)];
	[P lineToPoint:NSMakePoint(p.x - b, p.y + c)];
	[P lineToPoint:NSMakePoint(p.x - b, p.y - c)];
	[P lineToPoint:NSMakePoint(p.x - c, p.y - c)];
	[P lineToPoint:NSMakePoint(p.x - c, p.y - b)];
	[P lineToPoint:NSMakePoint(p.x + c, p.y - b)];
	[P lineToPoint:NSMakePoint(p.x + c, p.y - c)];
	[P lineToPoint:NSMakePoint(p.x + b, p.y - c)];
	[P lineToPoint:NSMakePoint(p.x + b, p.y + c)];
	[P closePath];
    }
    else if ( shape == RS_HOLLOW ) {
	b = w*2;  // outer width of circle / 2
	c = w*1.8f - 0.8f;  // inner width of circle / 2
	CGFloat d = .56f;  // percentage for control points (where does this number come from??)
	P = [NSBezierPath bezierPath];
	// construct outer circle
	[P moveToPoint:NSMakePoint(p.x - b, p.y)];
	s = NSMakePoint(p.x - b, p.y + b*d);
	t = NSMakePoint(p.x - b*d, p.y + b);
	[P curveToPoint:NSMakePoint(p.x, p.y + b) controlPoint1:s controlPoint2:t];
	s = NSMakePoint(p.x + b*d, p.y + b);
	t = NSMakePoint(p.x + b, p.y + b*d);
	[P curveToPoint:NSMakePoint(p.x + b, p.y) controlPoint1:s controlPoint2:t];
	s = NSMakePoint(p.x + b, p.y - b*d);
	t = NSMakePoint(p.x + b*d, p.y - b);
	[P curveToPoint:NSMakePoint(p.x, p.y - b) controlPoint1:s controlPoint2:t];
	s = NSMakePoint(p.x - b*d, p.y - b);
	t = NSMakePoint(p.x - b, p.y - b*d);
	[P curveToPoint:NSMakePoint(p.x - b, p.y) controlPoint1:s controlPoint2:t];
	// now the inner circle
	b = c; // so I can copy and paste
	[P lineToPoint:NSMakePoint(p.x - b, p.y)];
	s = NSMakePoint(p.x - b, p.y + b*d);
	t = NSMakePoint(p.x - b*d, p.y + b);
	[P curveToPoint:NSMakePoint(p.x, p.y + b) controlPoint1:s controlPoint2:t];
	s = NSMakePoint(p.x + b*d, p.y + b);
	t = NSMakePoint(p.x + b, p.y + b*d);
	[P curveToPoint:NSMakePoint(p.x + b, p.y) controlPoint1:s controlPoint2:t];
	s = NSMakePoint(p.x + b, p.y - b*d);
	t = NSMakePoint(p.x + b*d, p.y - b);
	[P curveToPoint:NSMakePoint(p.x, p.y - b) controlPoint1:s controlPoint2:t];
	s = NSMakePoint(p.x - b*d, p.y - b);
	t = NSMakePoint(p.x - b, p.y - b*d);
	[P curveToPoint:NSMakePoint(p.x - b, p.y) controlPoint1:s controlPoint2:t];
	//[P closePath];
	[P setWindingRule:NSEvenOddWindingRule];
    }
    else if ( shape == RS_TICKMARK ) {
	b = 5*w/2; // the "big" dimension
	c = w/2; // the "small" dimension
	P = [NSBezierPath bezierPath];
	// construct path
	[P moveToPoint:NSMakePoint(p.x + c, p.y + b)];
	[P lineToPoint:NSMakePoint(p.x - c, p.y + b)];
	[P lineToPoint:NSMakePoint(p.x - c, p.y - b)];
	[P lineToPoint:NSMakePoint(p.x + c, p.y - b)];
	[P closePath];
	
	NSRect r = NSMakeRect(0,0,b*2,b*2);
	r.origin = p;
	[P rotateInFrame:r byDegrees:-10];
    }
    
    
    // draw image
    [img lockFocus];
    [[NSColor blackColor] set];
    [P fill];
    [img unlockFocus];
    
    // set popup menu item
    [[[_shapePopUp menu] itemWithTag:shape] setImage:img];
}


#pragma mark -
#pragma mark Updating the display


- (void)updateThicknessControls:(RSGraphElement *)obj;
{
    if (![obj hasWidth]) {
	[_widthField setStringValue:@""];
	return;
    }
    
    CGFloat width = [self.editor widthForElement:obj];
    [_widthSlider setDoubleValue:width];
    [_widthField setDoubleValue:width];
}

- (void)updateColorControls:(RSGraphElement *)obj;
{
    OQColor *color = [obj color];
    
    if (![_s selected] && [[RSMode sharedModeController] mode] == RS_fill) {
	color = [OQColor colorForPreferenceKey:@"DefaultFillColor"];
    }
    
    if (!color || ![obj hasColor]) {
        return;
    }
        
    CGFloat opacity = [obj opacity];

    [_colorWell setColor:color.toColor];
    [_opacitySlider setDoubleValue:opacity];
    
    [[_opacityButtonLeft cell] setColor:color.toColor];
    [_opacityButtonLeft setNeedsDisplay];
    [[_opacityButtonRight cell] setColor:color.toColor];
    [_opacityButtonRight setNeedsDisplay];
}

- (NSUInteger)pointShapeFromSegmentTag:(NSInteger)tag;
{
    NSInteger shape;
    
    switch (tag) {
	case 0:
	    shape = [[_shapePopUp selectedItem] tag];
	    if (shape > RS_LAST_STANDARD_SHAPE)
		shape = RS_CIRCLE;
	    break;
	case 1:
	    shape = RS_TICKMARK;
	    break;
	case 2:
	    shape = RS_BAR_VERTICAL;
	    break;
	case 3:
	    shape = RS_BAR_HORIZONTAL;
	    break;
	case 4:
	    shape = RS_NONE;
	    break;
	default:
	    shape = RS_CIRCLE;
	    break;
    }
    return shape;
}

- (void)updatePointShapeControls:(RSGraphElement *)obj;
{
    NSInteger shape = [obj shape];
    
    if (![obj hasShape] || shape == RS_SHAPE_MIXED) {
	[_pointTypeControl deselectAllSegments];
	[_shapePopUp selectItemWithTag:99];
	return;
    }
    
    
    if (shape != RS_NONE && shape <= RS_LAST_STANDARD_SHAPE) {
	[_pointTypeControl selectSegmentWithTag:0];
	//[_shapePopUp setEnabled:YES];
	[_shapePopUp selectItemWithTag:shape];
	return;
    }
    
    // If not a "standard shape", select one of the segmented control cells
    [_shapePopUp selectItemWithTag:99];
    //[_shapePopUp setEnabled:NO];
    
    NSInteger tag;
    switch (shape) {
	case RS_TICKMARK:
	    tag = 1;
	    break;
	case RS_BAR_VERTICAL:
	    tag = 2;
	    break;
	case RS_BAR_HORIZONTAL:
	    tag = 3;
	    break;
	case RS_NONE:
	    tag = 4;
	    break;
	default:
	    tag = 4;
	    break;
    }
    [_pointTypeControl selectSegmentWithTag:tag];
}


- (void)selectSegmentWithConnectMethod:(RSConnectType)connectMethod;
{
    if (connectMethod == RSConnectMixed) {
	[_lineTypeControl deselectAllSegments];
	return;
    }
    
    NSInteger tag;
    switch (connectMethod) {
	case RSConnectStraight:
	    tag = 0;
	    break;
	case RSConnectCurved:
	    tag = 1;
	    break;
	case RSConnectLinearRegression:
	    tag = 2;
	    break;
	case RSConnectNone:
	    tag = 3;
	    break;
	default:
	    tag = 3;
	    break;
    }
    
    [_lineTypeControl selectSegmentWithTag:tag];
}

- (void)updateLineTypeControls:(RSGraphElement *)obj;
{
    if (![obj hasConnectMethod]) {
        [_lineTypeControl deselectAllSegments];
        [_dashPopUp selectItemWithTag:99];
        
        return;
    }

    [self selectSegmentWithConnectMethod:[obj connectMethod]];
    
    [_lineTypeControl setEnabled:![self.graph hasLogarithmicAxis] forSegment:2];

    NSUInteger dash = [obj dash];
    if ( !dash || dash == RS_DASH_MIXED )
        [_dashPopUp selectItemWithTag:99];
    else
        [_dashPopUp selectItemWithTag:dash];
}


- (void)updateArrowheadControls:(RSGraphElement *)obj;
{
    //NSInteger styleIndex = [obj shape];
    if (![obj canHaveArrows]) {
	[_leftArrowCheckBox setState:NSOffState];
	[_rightArrowCheckBox setState:NSOffState];
	[_arrowGraphic setImage:[NSImage imageNamed:@"arrowEndsDisabled"]];
	return;
    }
    
    // Otherwise, enabled
    [_arrowGraphic setImage:[NSImage imageNamed:@"arrowEndsEnabled"]];
    
    RSGraphEditor *editor = self.editor;
    [_leftArrowCheckBox setState:[editor hasMinArrow:obj] ? NSOnState : NSOffState];
    [_rightArrowCheckBox setState:[editor hasMaxArrow:obj] ? NSOnState : NSOffState];
}


- (void)updateLabelField:(RSGraphElement *)obj;
{
    if (![[_s selection] isLabelable]) {
	[_labelField setStringValue:@""];
	return;
    }
    
    RSLine *L = [RSGraph isLine:obj];
    if (L)
	obj = L;
    
    NSString *text = [obj text];
    if (!text)
	text = @"";
    
    [_labelField setStringValue:text];
}

- (void)updateLabelFontControls:(RSGraphElement *)obj;
{
    if (![[_s selection] hasLabel]) {
	// control is not enabled
	[_fontButton setTitle:@""];
	[_fontSizeField setStringValue:@""];
	return;
    }
    
    RSGraphElement <RSFontAttributes> *fontAttributes = [RSGraph fontAtrributeElementForElement:obj];
    if (!fontAttributes)
	return;
    
    NSFont *font = [[fontAttributes fontDescriptor] font];
    NSString *fontDisplayName = [font displayName];
    fontDisplayName = [fontDisplayName stringByAppendingString:@"..."];
    [_fontButton setTitle:fontDisplayName];
    
    CGFloat fontSize = [fontAttributes fontSize];
    [_fontSizeSlider setDoubleValue:fontSize];
    [_fontSizeField setDoubleValue:fontSize];
}

#define RS_AXIS_TITLE_DISTANCE_SLIDER_MAX 60
- (CGFloat)maxDistanceForTitle:(RSTextLabel *)title;
{
    OBPRECONDITION(title);
    
    RSAxis *axis = [self.graph axisOfElement:title];
    OBASSERT(axis);
    
    NSSize extraSize = [self.graph potentialWhitespaceExpansionSize];
    
    CGFloat extraDistance = 0;
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL)
	extraDistance = extraSize.height;
    else if ([axis orientation] == RS_ORIENTATION_VERTICAL)
	extraDistance = extraSize.width;
    
    CGFloat maxDistance = extraDistance + [axis titleDistance];
    
    if (maxDistance < RS_AXIS_TITLE_DISTANCE_SLIDER_MAX)
	return maxDistance;
    else
        return RS_AXIS_TITLE_DISTANCE_SLIDER_MAX;
}

#define RS_LABEL_DISTANCE_SLIDER_MAX 30
- (CGFloat)labelDistanceMaxValue:(RSGraphElement *)obj;
{
    if (![obj isKindOfClass:[RSAxis class]])
	return RS_LABEL_DISTANCE_SLIDER_MAX;
    
    // If an axis...
    RSAxis *axis = (RSAxis *)obj;
    NSSize extraSize = [self.graph potentialWhitespaceExpansionSize];
    CGFloat extraDistance = 0;
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL)
	extraDistance = extraSize.height;
    else if ([axis orientation] == RS_ORIENTATION_VERTICAL)
	extraDistance = extraSize.width;
    
    CGFloat maxDistance = extraDistance + [axis labelDistance];
    
    if (maxDistance < RS_LABEL_DISTANCE_SLIDER_MAX)
	return maxDistance;
    else  return RS_LABEL_DISTANCE_SLIDER_MAX;
}

- (void)updateLabelDistanceControls:(RSGraphElement *)obj;
{
    if (![[_s selection] hasLabelDistance]) {
	// control is not enabled
	[_distanceField setStringValue:@""];
	return;
    }
	
	
    RSAxis *axis = [self.graph axisOfElement:obj];
    
    // special case for axis titles
    if (axis && [obj isKindOfClass:[RSTextLabel class]] && [self.graph isAxisTitle:(RSTextLabel *)obj]) {
	CGFloat maxDistance = [self maxDistanceForTitle:(RSTextLabel *)obj];
	[_distanceSlider setMaxValue:maxDistance];
	[[_distanceField formatter] setMaximum:[NSNumber numberWithDouble:maxDistance]];
	[_distanceSlider setDoubleValue:[axis titleDistance]];
	[_distanceField setDoubleValue:[axis titleDistance]];
    }
    // not an axis title
    else {
	RSLine *L = nil;
	if( (L = [RSGraph isLine:obj]) ) {
	    obj = L;
	}
	else if( [obj isKindOfClass:[RSTextLabel class]] ) {
	    if ( [obj owner] )  obj = [obj owner];
	    if (axis)  obj = axis;
	}
	CGFloat maxDistance = [self labelDistanceMaxValue:obj];
	[_distanceSlider setMaxValue:maxDistance];
	[[_distanceField formatter] setMaximum:[NSNumber numberWithDouble:maxDistance]];
	[_distanceSlider setDoubleValue:[obj labelDistance]];
	[_distanceField setDoubleValue:[obj labelDistance]];
    }
    
}

- (void)updatePositionControls:(RSGraphElement *)obj;
{
    if (![[_s selection] hasUserCoords]) {
	[_x1 setStringValue:@""];
	[_y1 setStringValue:@""];
	return;
    }
    
//    [[_graph xAxis] configureInspectorNumberFormatter:[x1 formatter]];
//    [[_graph yAxis] configureInspectorNumberFormatter:[y1 formatter]];
    
    RSDataPoint position = [obj position];
    
    [_x1 setStringValue:[[self.graph xAxis] inspectorFormattedDataValue:position.x]];
    [_y1 setStringValue:[[self.graph yAxis] inspectorFormattedDataValue:position.y]];
}


- (void)updateDisplay;
{
    // -setEnabled: should be now handled using bindings in the xib file.
    
    if (!_editor || !_s || ![_s document] || ![_s context]) {
	
	[_colorWell setColor:[NSColor blackColor]];
	
	[_widthField setStringValue:@""];
	[_labelField setStringValue:@""];
	
	[_leftArrowCheckBox setState:NSOffState];
	[_rightArrowCheckBox setState:NSOffState];
	
	// The OAControlTextColorTransformer doesn't seem to be getting called by cocoa bindings when the selection is nil.
	[_labelText setTextColor:[NSColor disabledControlTextColor]];
	[_fontText setTextColor:[NSColor disabledControlTextColor]];
	[_fontSizeText setTextColor:[NSColor disabledControlTextColor]];
	[_distanceText setTextColor:[NSColor disabledControlTextColor]];
	
	return;
    }
    
    // Else, there is a document window open; update all the controls
    RSGraphElement *obj = [_s selection];
    
    //
    [self updateThicknessControls:obj];
    //
    [self updateColorControls:obj];
    
    //
    [self updatePointShapeControls:obj];
    
    //
    [self updateLineTypeControls:obj];
    [self updateArrowheadControls:obj];
    
    //
    [self updateLabelField:obj];
    [self updateLabelFontControls:obj];
    [self updateLabelDistanceControls:obj];
    
    //
    [self updatePositionControls:obj];
    
}



#pragma mark -
#pragma mark init/dealloc

- initWithDictionary:(NSDictionary *)dict bundle:(NSBundle *)sourceBundle;
{
    self = [super initWithDictionary:dict bundle:sourceBundle];
    if (!self)
        return nil;
    
    _s = nil;
    _editor = nil;
    
    _textDidChange = NO;
    
    return self;
}

- (void)dealloc;
{
    // unregister observer from notification center
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
    
    [_view release];
    
    [super dealloc];
}

- (void)awakeFromNib;
{
    // add pictures to dash popup menu
    NSInteger i;
    for( i=1; i<7; i++) {
	[self setDashPictureForTag:i];
    }
    [self setDashPictureForTag:RS_ARROWS_DASH];
    [self setDashPictureForTag:RS_REVERSE_ARROWS_DASH];
    [self setDashPictureForTag:RS_RAILROAD_DASH];
    
    // add pictures to shape popup menu
    for( i=1; i<=9; i++) {
	[self setShapePictureForTag:i];
    }
    
    // set up opacity buttons
    [(OpacityControlCell *)[_opacityButtonLeft cell] setOpacity:0.25f];
    [(OpacityControlCell *)[_opacityButtonRight cell] setOpacity:0.75f];
    
    // add default number formatters
//    [x1 setFormatter:[RSAxis inspectorNumberFormatter]];
//    [y1 setFormatter:[RSAxis inspectorNumberFormatter]];
    
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    // Register to receive notifications about selection changes
    [nc addObserver:self 
           selector:@selector(selectionChangedNotification:)
               name:@"RSSelectionChanged"
             object:nil]; // don't care who sent it
    
    // Register to receive notifications about context changes
    [nc addObserver:self 
           selector:@selector(contextChangedNotification:)
               name:@"RSContextChanged"
             object:nil]; // don't care who sent it
    
    // Register to receive notifications when the toolbar is clicked
    [nc addObserver:self 
           selector:@selector(toolbarClickedNotification:)
               name:@"RSToolbarClicked"
             object:nil]; // don't care who sent it
    
    // Register to receive notifications when the toolbar is clicked
    [nc addObserver:self 
           selector:@selector(modeDidChangeNotification:)
               name:@"RSModeDidChange"
             object:nil]; // don't care who sent it
    
    
    [self updateDisplay];
}



////////////////////////////////////////
#pragma mark -
#pragma mark Notifications
////////////////////////////////////////

- (void)selectionChangedNotification:(NSNotification *)note;
// sent by selection object when any object modifies the selection in any way
{
    // if the inspector sent the change notification, ignore it
    if ([note object] == self)  return;
    
    // otherwise, take heed:
    else {
	// remove keyboard focus from any fields
	//[panel makeFirstResponder:nil];
	
	[self updateSelection];
	
        // this will display the new values directly from the selection:
        [self updateDisplay];
    }
}
- (void)contextChangedNotification:(NSNotification *)note;
{
    [self updateSelection];
    [self updateDisplay];
}
- (void)toolbarClickedNotification:(NSNotification *)note;
{
    // deselect any selected fields (otherwise, a new unwanted (0,0) point could get created)
    [[_view window] makeFirstResponder:nil];
}

- (void)modeDidChangeNotification:(NSNotification *)note;
{
    [self updateDisplay];
}



////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate methods
////////////////////////////////////////////
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
    return [[_s document] undoManager];
}

- (void)controlTextDidChange:(NSNotification *)note
{
    _textDidChange = YES;
    
    if ( [note object] == _labelField ) {
	[self changeAssociatedLabel:_labelField];
    }
    
    _textDidChange = NO;
}



#pragma mark -
#pragma mark OIConcreteInspector protocol

- (NSView *)inspectorView;
// Returns the view which will be placed into a grouped Info window
{
    if (!_view) {
	if (![[self bundle] loadNibNamed:NSStringFromClass(self.class) owner:self topLevelObjects:NULL]) {
	    OBASSERT_NOT_REACHED("Error loading nib");
	}
    }
    return _view;
}

- (NSPredicate *)inspectedObjectsPredicate;
// Return a predicate to filter the inspected objects down to what this inspector wants sent to its -inspectObjects: method
{
    static NSPredicate *predicate = nil;
    if (!predicate)
	predicate = [[NSComparisonPredicate isKindOfClassPredicate:[GraphDocument class]] retain];
    return predicate;
}

- (void)inspectObjects:(NSArray *)objects;
// This method is called whenever the selection changes
{
    GraphDocument *newDocument = nil;
    
    for (id obj in objects) {
	if ([obj isKindOfClass:[GraphDocument class]]) {
	    newDocument = obj;
	    break;
	}
    }
    
    // The graph can change on "revert to saved", even if the document is the same.
    RSGraphEditor *newEditor = newDocument.editor;
    if (newEditor == _editor)
        return;
    
    if (_editor) {
	// stop observing changes to the old graph
	//[_graph removeObserver:self forKeyPath:@"canvasSize"];
    }
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    _s = [newDocument selectorObject];
    self.editor = newEditor;
    [self setSelection:[_s selection]];
    [pool release];
    
    if (newEditor) {
	// start observing changes to the new graph
	//[_graph addObserver:self forKeyPath:@"canvasSize" options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    [self updateDisplay];
}




#pragma mark -
#pragma mark KVO (instead of cocoa bindings)

+ (NSSet *)keyPathsForValuesAffectingGraphExists;
{
    return [NSSet setWithObject:@"graph"];
}

+ (NSSet *)keyPathsForValuesAffectingIsSelected;
{
    return [NSSet setWithObject:@"selection"];
}

+ (NSSet *)keyPathsForValuesAffectingHasWidth;
{
    return [NSSet setWithObject:@"selection"];
}

+ (NSSet *)keyPathsForValuesAffectingHasColor;
{
    return [NSSet setWithObject:@"selection"];
}

+ (NSSet *)keyPathsForValuesAffectingHasDash;
{
    return [NSSet setWithObject:@"selection"];
}

+ (NSSet *)keyPathsForValuesAffectingCanHaveArrows;
{
    return [NSSet setWithObject:@"selection"];
}


- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
{
    // for now we'll take the brute-force approach of just updating the entire display
    [self updateDisplay];
}



#pragma mark -
#pragma mark Accessors

@synthesize editor = _editor;

- (RSGraph *)graph;
{
    return _editor.graph;
}

- (BOOL)graphExists;
{
    return (_editor != nil);
}

- (RSGraphElement *)selection;
{
    return [_s selection];
}
- (void)setSelection:(RSGraphElement *)GE;
{
    // this is just here to update KVO / cocoa bindings
    ;
}
- (void)updateSelection;
// A convenience method to update KVO / cocoa bindings
{
    //DEBUG_RS(@"updateSelection");
    
    [self setSelection:nil];
    [self setSelection:[_s selection]];
}
- (BOOL)isSelected;
{
    if (!_s)
	return NO;
    
    return [_s selected];
}

// The following properties don't update properly when the inspector uses a binding directly on the selection.  I think this is because RSGroup wrappers don't send KVO notifications when some of their members are added or removed (which can change the value of these properties).  Putting the properties here, along with +keyPathsForValuesAffectingHasDash (etc.), seem to do the trick.
- (BOOL)hasWidth;
{
    return [[_s selection] hasWidth];
}
- (BOOL)hasColor;
{
    return [[_s selection] hasColor];
}
- (BOOL)hasDash;
{
    return [[_s selection] hasDash];
}
- (BOOL)canHaveArrows;
{
    return [[_s selection] canHaveArrows];
}




#pragma mark -
#pragma mark IBActions

- (IBAction)changeThickness:(id)sender;
{
    [self updateKeyWindowAndFirstResponder:sender];
    [self.editor setWidth:[sender floatValue] forElement:[_s selection] snapDistanceToNearestInteger:(sender == _widthSlider)];
    [_s sendChange:nil];
}

- (IBAction)changeColor:(id)sender;
{
    // Just let the first responder get the -changeColor: message
    //[_graph changeColor:sender];
}

- (IBAction)changeOpacity:(id)sender;
{
    RSGraphElement *obj = [_s selection];
    
    if (![obj isKindOfClass:[RSUnknown class]]) {
	// Set up Undo:
	[[_s undoer] registerRepetitiveUndoWithObject:obj action:@"setOpacity" 
						state:[NSNumber numberWithFloat:(float)[obj opacity]]
						 name:NSLocalizedStringFromTable(@"Change Opacity", @"UndoActions", @"Undo action name")];
    }
    
    float opacity = [sender floatValue];
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    // set the opacity
    [obj setOpacity:opacity];
    
    NSColor *newDefaultColor = [obj color].toColor;
    if (newDefaultColor) {
        if ( [obj isKindOfClass:[RSUnknown class]] ) {
            if ([[RSMode sharedModeController] mode] == RS_fill) {
                [[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newDefaultColor forKey:@"DefaultFillColor"];
            }
            else {
                [[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newDefaultColor forKey:@"DefaultLineColor"];	    
            }
        }
        else if ([RSGraph isLine:obj] || [obj isKindOfClass:[RSVertex class]]) {
            [[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newDefaultColor forKey:@"DefaultLineColor"];
        }
        else if ([obj isKindOfClass:[RSFill class]]) {
            [[OFPreferenceWrapper sharedPreferenceWrapper] setColor:newDefaultColor forKey:@"DefaultFillColor"];
        }
    }
    
    [_s sendChange:nil];
}




- (void)_setShape:(NSInteger)styleIndex forElement:(RSGraphElement *)obj;
{
    [_editor setShape:styleIndex forElement:obj];
    [_s sendChange:nil];
}

- (IBAction)changePointType:(id)sender;
{
    RSGraphElement *obj = [_s selection];
    NSInteger styleIndex = [self pointShapeFromSegmentTag:[_pointTypeControl selectedSegment]];
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    [self _setShape:styleIndex forElement:obj];
}

- (IBAction)changeShapePopUp:(id)sender;
{
    RSGraphElement *obj = [_s selection];
    NSInteger styleIndex = [[sender selectedItem] tag];
    
    if (styleIndex == 99)
	styleIndex = RS_NONE;
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    [self _setShape:styleIndex forElement:obj];
}

- (RSConnectType)connectMethodFromSegmentTag:(NSInteger)tag;
{
    switch (tag) {
	case 0:
	    return RSConnectStraight;
	    break;
	case 1:
	    return RSConnectCurved;
	    break;
	case 2:
	    return RSConnectLinearRegression;
	    break;
	case 3:
	    return RSConnectNone;
	    break;
	default:
	    OBASSERT_NOT_REACHED("Unknown segment tag");
	    break;
    }
    return RSConnectCurved;
}

- (IBAction)changeLineType:(id)sender;
{
    RSConnectType connectMethod = [self connectMethodFromSegmentTag:[_lineTypeControl selectedSegment]];
    
    [self updateKeyWindowAndFirstResponder:sender];
    RSGraphElement *newSelection = [_editor setConnectMethod:connectMethod forElement:[_s selection]];
    [_s setSelection:newSelection];
    
    [_s sendChange:nil];
}

- (IBAction)changeDashPopUp:(id)sender;
// aka "stroke"
{
    [self updateKeyWindowAndFirstResponder:sender];
    
    NSInteger styleIndex = [[_dashPopUp selectedItem] tag];
    RSGraphElement *obj = [_s selection];
    RSGraphElement *newSelection;
    
    // If the user selected the empty row, behave like clicking the "no connections" button
    if (styleIndex == 99)
        newSelection = [self.graph changeLineTypeOf:obj toConnectMethod:RSConnectNone];
    else
        newSelection = [self.editor setDash:styleIndex forElement:obj];
    
    [_s setSelection:newSelection];
    [_s sendChange:nil];
}


- (NSInteger)_arrowShapeIndexFromControls;
{
    if( [_leftArrowCheckBox state] == NSOffState ) {
	if( [_rightArrowCheckBox state] == NSOffState ) {
	    return RS_NONE;
	}
	else  return RS_RIGHT_ARROW;
    }
    else {
	if( [_rightArrowCheckBox state] == NSOffState ) {
	    return RS_LEFT_ARROW;
	}
	else  return RS_BOTH_ARROW;
    }
}

- (IBAction)changeArrowhead:(id)sender;
{
    RSGraphElement *obj = [_s selection];
    NSInteger styleIndex = [self _arrowShapeIndexFromControls];
    
    [self updateKeyWindowAndFirstResponder:sender];
    [self.editor changeArrowhead:styleIndex forElement:obj isLeft:(sender == _leftArrowCheckBox)];
    [_s sendChange:nil];
}


- (IBAction)changeAssociatedLabel:(id)sender;
{
    RSGraphElement *obj;
    RSTextLabel *TL;
    RSLine *L;
    //NSPoint p;
    
    Log2(@"changeAssociatedLabel called in Inspector");
    
    obj = [_s selection];
    
    if( [[sender stringValue] isEqualToString:@""] ) {
	if( [RSGraph labelOf:obj] ) {
	    [[[_s document] graph] removeElement:[RSGraph labelOf:obj]];
	}
	else  return;  // do nothing if there's no string
    }
    else if ( [obj isKindOfClass:[RSAxis class]] ) {
        [[(RSAxis *)obj title] setText:[sender stringValue]];
	[_s sendChange:nil];
    }
    else if ( (L = [RSGraph isLine:obj]) ) {
	TL = [L label];
	if (!TL) {
	    TL = [[RSTextLabel alloc] initWithGraph:self.graph];
	    [[[_s document] graph] addElement:[TL autorelease]];
	    [TL setOwner:L];
	}
        [L setText:[sender stringValue]];
	[_s sendChange:nil];
    }
    else if ( [obj isKindOfClass:[RSVertex class]] ) {
	TL = [obj label];
	if (!TL) {
	    TL = [[RSTextLabel alloc] initWithGraph:self.graph];
	    [[[_s document] graph] addElement:[TL autorelease]];
	    [TL setOwner:obj];
	}
        [obj setText:[sender stringValue]];
	[_s sendChange:nil];
    }
    else if ( [obj isKindOfClass:[RSFill class]] ) {
	TL = [obj label];
	if (!TL) {
	    TL = [[RSTextLabel alloc] initWithGraph:self.graph];
	    [[[_s document] graph] addElement:[TL autorelease]];
	    [TL setOwner:obj];
	}
        [obj setText:[sender stringValue]];
	[_s sendChange:nil];
    }
    else if ( [obj isKindOfClass:[RSTextLabel class]] ) {
        [obj setText:[sender stringValue]];
	[_s sendChange:nil];
    }
    else {
	NSLog(@"ERROR: changeAssociatedLabel doesn't support this context: %@", [obj class]);
	return;
    }
    
    if ( _textDidChange )	// a text-changed update
	[_s sendChange:self];
    else					// control text did ending editing (e.g. with return key)
	[_s sendChange:nil];	// will update display and possibly reject value
}

- (IBAction)showFontPicker:(id)sender;
{
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)changeFontSize:(id)sender;
{
    RSGraphElement <RSFontAttributes> *obj = [RSGraph fontAtrributeElementForElement:[_s selection]];
    OBASSERT(obj);  // otherwise, the inspector control shouldn't have been enabled
    if (!obj)
	return;
    
    // Set up Undo:
    [[_s undoer] registerRepetitiveUndoWithObject:obj action:@"setFontSize" 
					    state:[NSNumber numberWithDouble:[(RSTextLabel *)obj fontSize]]
					     name:NSLocalizedStringFromTable(@"Change Font Size", @"UndoActions", @"Undo action name")];
    
    CGFloat fontSize = [sender floatValue];
    
    // If using the slider, round the font size to an integer
    if (sender == _fontSizeSlider) {
        fontSize = nearbyint(fontSize);
    }
    
    [self updateKeyWindowAndFirstResponder:sender];
    
    // make the change
    [(RSTextLabel *)obj setFontSize:fontSize];
    
    // set defaults
    OAFontDescriptor *newFontDescriptor = [(RSTextLabel *)obj fontDescriptor];
    RSTextLabel *TL = (RSTextLabel *)obj;
    if( [self.graph isAxisTickLabel:TL] ) {
	;//[[OFPreferenceWrapper sharedPreferenceWrapper] setFontDescriptor:newFontDescriptor forKey:@"DefaultAxisTickLabelFont"];
    } else if( [self.graph isAxisTitle:TL] ) {
	;//[[OFPreferenceWrapper sharedPreferenceWrapper] setFontDescriptor:newFontDescriptor forKey:@"DefaultAxisTitleFont"];
    } else {
	[[OFPreferenceWrapper sharedPreferenceWrapper] setFontDescriptor:newFontDescriptor forKey:@"DefaultLabelFont"];
    }
    
    [_s sendChange:nil];
}

- (IBAction)changeDistanceSliderValue:(id)sender;
{
    Log3(@"changeDistanceSliderValue called in Inspector");
    [self updateKeyWindowAndFirstResponder:sender];
    
    [self.editor setDistanceValue:[sender floatValue] forElement:[_s selection] snapDistanceToNearestInteger:(sender == _distanceSlider)];
    
    [_s sendChange:nil];
}



- (IBAction)changeX1:(id)sender;
{
    RSGraphElement *obj = [_s selection];
    
    data_p value = [[self.graph xAxis] dataValueFromFormat:[sender stringValue]];
    [self.editor changeX:value forElement:obj];

    if ( _textDidChange )	// a text-changed update
	[_s sendChange:self];
    else					// control text did ending editing (e.g. with return key)
	//if( !_textDidChange )
	[_s sendChange:nil];	// will update display and possibly reject value
}

- (IBAction)changeY1:(id)sender;
{
    RSGraphElement *obj = [_s selection];
    
    data_p value = [[self.graph yAxis] dataValueFromFormat:[sender stringValue]];
    [self.editor changeY:value forElement:obj];

    if ( _textDidChange )	// a text-changed update
	[_s sendChange:self];
    else					// control text did ending editing (e.g. with return key)
	[_s sendChange:nil];	// will update display and possibly reject value
}






@end
