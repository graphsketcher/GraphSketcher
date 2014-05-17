// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSGraphRenderer.h>

#import <GraphSketcherModel/RSGraphElement-Rendering.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSEquationLine.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSGrid.h>
#import <GraphSketcherModel/NSBezierPath-RSExtensions.h>
#import <GraphSketcherModel/NSArray-RSExtensions.h>
#import <OmniQuartz/OQColor.h>

#import <OmniFoundation/OFPreference.h>
#import <OmniFoundation/CFArray-OFExtensions.h>

#import "RSText.h"

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/NSShadow.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSScreen.h>
#endif

#define AXIS_LINE_HINTING_WIDTH_CUTOFF (1.5)

static CGFloat nearestPixelIfEnabled(CGFloat f) {
    BOOL hintingEnabled = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"EnableLineHinting"];
    if (hintingEnabled) {
        return nearestPixel(f);
    }
    // else
    return f;
}

static OQColor *baseSelectionColor() {
    OQColor *selectionColor = [[OQColor selectedTextBackgroundColor] colorUsingColorSpace:OQColorSpaceRGB];
    selectionColor = [OQColor colorWithHue:[selectionColor hueComponent]
                                saturation:[selectionColor saturationComponent] * 2
                                brightness:[selectionColor brightnessComponent] * 0.92f
                                     alpha:1];
    return selectionColor;
}

void drawRectangularSelectRect(CGRect rect) {
    NSBezierPath *P = [NSBezierPath bezierPathWithRect:rect];
    [P setLineWidth:2.0f];
    OQColor *color = [baseSelectionColor() colorWithAlphaComponent:0.5f];
    [color set];
    [P stroke];
}

void RSAppendShapeToBezierPath(NSBezierPath *P, CGPoint p, NSInteger shape, CGFloat width, CGFloat rotation) {
    
    //    // Return the cached version if possible
    //    NSBezierPath *P = [_pathCache objectForKey:[V identifier]];
    //    if (P) {
    //        return P;
    //    }
    
    CGRect r;
    CGPoint s, t; // for creating the star, etc.
    CGFloat b, c; // for creating the X, etc.
    CGFloat w = width;
    
    //shape = [V shape];
    if ( shape < 1 ) { // round, same size as line
        // else
        r.origin.x = p.x - (w / 2);
        r.origin.y = p.y - (w / 2);
        r.size.width  = w;
        r.size.height = w;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        [P appendPath:[UIBezierPath bezierPathWithOvalInRect:r]];
#else
        [P appendBezierPathWithOvalInRect:r];
#endif
    }
    // Vertex Shapes meant for data points:
    else if ( shape == RS_CIRCLE ) {
        r.origin.x = p.x - w*2;
        r.origin.y = p.y - w*2;
        r.size.width = w*4;
        r.size.height = w*4;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        [P appendPath:[UIBezierPath bezierPathWithOvalInRect:r]];
#else
        [P appendBezierPathWithOvalInRect:r];
#endif
    }
    else if ( shape == RS_TRIANGLE ) {
        //s.x = w*0.8660254; //cos(30)
        //s.y = w*0.5; //sin(30);
        // these parameters give the triangle the same area as the square:
        s.x = (CGFloat)(w*0.759835686*4);
        s.y = (CGFloat)(w*0.438691338*4);
        // construct path
        [P moveToPoint:CGPointMake(p.x - s.x, p.y - s.y)];
        [P lineToPoint:CGPointMake(p.x + s.x, p.y - s.y)];
        [P lineToPoint:CGPointMake(p.x, p.y + s.x)]; // correct for equilateral triangle
        [P closePath];
    }
    else if ( shape == RS_SQUARE ) {
        r.origin.x = p.x - w*2;
        r.origin.y = p.y - w*2;
        r.size.width = w*4;
        r.size.height = w*4;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        [P appendPath:[UIBezierPath bezierPathWithRect:r]];
#else
        [P appendBezierPathWithRect:r];  // simply makes a rect bezier path
#endif
    }
    else if ( shape == RS_STAR ) {
        b = w*0.8f*4;  // scaling factor
        // offsets for star points:
        s.x = (CGFloat)(b*0.8660254);//cos(30);
        s.y = b*0.5f;//sin(30);
        // offsets for star inners:
        t.x = b/2*0.5f;//cos(60);
        t.y = (CGFloat)(b/2*0.8660254);//sin(60);
        // construct path
        [P moveToPoint:CGPointMake(p.x, p.y + b)];
        [P lineToPoint:CGPointMake(p.x - t.x, p.y + t.y)];
        [P lineToPoint:CGPointMake(p.x - s.x, p.y + s.y)];
        [P lineToPoint:CGPointMake(p.x - b/2, p.y)];
        [P lineToPoint:CGPointMake(p.x - s.x, p.y - s.y)];
        [P lineToPoint:CGPointMake(p.x - t.x, p.y - t.y)];
        [P lineToPoint:CGPointMake(p.x, p.y - b)];
        [P lineToPoint:CGPointMake(p.x + t.x, p.y - t.y)];
        [P lineToPoint:CGPointMake(p.x + s.x, p.y - s.y)];
        [P lineToPoint:CGPointMake(p.x + b/2, p.y)];
        [P lineToPoint:CGPointMake(p.x + s.x, p.y + s.y)];
        [P lineToPoint:CGPointMake(p.x + t.x, p.y + t.y)];
        [P closePath];
    }
    else if ( shape == RS_DIAMOND ) {
        b = (CGFloat)(w*0.70710678*4); // sqrt(2)/2
        // construct path
        [P moveToPoint:CGPointMake(p.x - b, p.y)];
        [P lineToPoint:CGPointMake(p.x, p.y - b)];
        [P lineToPoint:CGPointMake(p.x + b, p.y)];
        [P lineToPoint:CGPointMake(p.x, p.y + b)];
        [P closePath];
    }
    else if ( shape == RS_X ) {
        b = 5*w/2; // the "big" dimension of the X
        c = 3*w/2; // the "small" dimension of the X
        // construct path
        [P moveToPoint:CGPointMake(p.x + w/2, p.y)];
        [P lineToPoint:CGPointMake(p.x + b, p.y + c)];
        [P lineToPoint:CGPointMake(p.x + c, p.y + b)];
        [P lineToPoint:CGPointMake(p.x, p.y + w/2)];
        [P lineToPoint:CGPointMake(p.x - c, p.y + b)];
        [P lineToPoint:CGPointMake(p.x - b, p.y + c)];
        [P lineToPoint:CGPointMake(p.x - w/2, p.y)];
        [P lineToPoint:CGPointMake(p.x - b, p.y - c)];
        [P lineToPoint:CGPointMake(p.x - c, p.y - b)];
        [P lineToPoint:CGPointMake(p.x, p.y - w/2)];
        [P lineToPoint:CGPointMake(p.x + c, p.y - b)];
        [P lineToPoint:CGPointMake(p.x + b, p.y - c)];
        [P closePath];
    }
    else if ( shape == RS_CROSS ) {
        b = 5*w/2; // the "big" dimension of the cross
        c = w/2; // the "small" dimension of the cross
        // construct path
        [P moveToPoint:CGPointMake(p.x + c, p.y + c)];
        [P lineToPoint:CGPointMake(p.x + c, p.y + b)];
        [P lineToPoint:CGPointMake(p.x - c, p.y + b)];
        [P lineToPoint:CGPointMake(p.x - c, p.y + c)];
        [P lineToPoint:CGPointMake(p.x - b, p.y + c)];
        [P lineToPoint:CGPointMake(p.x - b, p.y - c)];
        [P lineToPoint:CGPointMake(p.x - c, p.y - c)];
        [P lineToPoint:CGPointMake(p.x - c, p.y - b)];
        [P lineToPoint:CGPointMake(p.x + c, p.y - b)];
        [P lineToPoint:CGPointMake(p.x + c, p.y - c)];
        [P lineToPoint:CGPointMake(p.x + b, p.y - c)];
        [P lineToPoint:CGPointMake(p.x + b, p.y + c)];
        [P closePath];
    }
    else if ( shape == RS_HOLLOW ) {
        // this is lovely but doesn't hide the line underneath
        b = w*2;  // outer width of circle / 2
        c = (CGFloat)(w*0.8 - 0.4)*2;  // inner width of circle / 2
        CGFloat d = .56f;  // percentage for control points (where does this number come from??)
        // construct outer circle
        [P moveToPoint:CGPointMake(p.x - b, p.y)];
        s = CGPointMake(p.x - b, p.y + b*d);
        t = CGPointMake(p.x - b*d, p.y + b);
        [P curveToPoint:CGPointMake(p.x, p.y + b) controlPoint1:s controlPoint2:t];
        s = CGPointMake(p.x + b*d, p.y + b);
        t = CGPointMake(p.x + b, p.y + b*d);
        [P curveToPoint:CGPointMake(p.x + b, p.y) controlPoint1:s controlPoint2:t];
        s = CGPointMake(p.x + b, p.y - b*d);
        t = CGPointMake(p.x + b*d, p.y - b);
        [P curveToPoint:CGPointMake(p.x, p.y - b) controlPoint1:s controlPoint2:t];
        s = CGPointMake(p.x - b*d, p.y - b);
        t = CGPointMake(p.x - b, p.y - b*d);
        [P curveToPoint:CGPointMake(p.x - b, p.y) controlPoint1:s controlPoint2:t];
        // now the inner circle
        b = c; // so I can copy and paste
        [P lineToPoint:CGPointMake(p.x - b, p.y)];
        s = CGPointMake(p.x - b, p.y + b*d);
        t = CGPointMake(p.x - b*d, p.y + b);
        [P curveToPoint:CGPointMake(p.x, p.y + b) controlPoint1:s controlPoint2:t];
        s = CGPointMake(p.x + b*d, p.y + b);
        t = CGPointMake(p.x + b, p.y + b*d);
        [P curveToPoint:CGPointMake(p.x + b, p.y) controlPoint1:s controlPoint2:t];
        s = CGPointMake(p.x + b, p.y - b*d);
        t = CGPointMake(p.x + b*d, p.y - b);
        [P curveToPoint:CGPointMake(p.x, p.y - b) controlPoint1:s controlPoint2:t];
        s = CGPointMake(p.x - b*d, p.y - b);
        t = CGPointMake(p.x - b, p.y - b*d);
        [P curveToPoint:CGPointMake(p.x - b, p.y) controlPoint1:s controlPoint2:t];
        //[P closePath];
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        P.usesEvenOddFillRule = YES;
#else
        [P setWindingRule:NSEvenOddWindingRule];
#endif
        
        // old method
        //	 r.origin.x = p.x - w*2;
        //	 r.origin.y = p.y - w*2;
        //	 r.size.width = w*4;
        //	 r.size.height = w*4;
        //	 P = [NSBezierPath bezierPathWithOvalInRect:r];
        //	 r.origin.x = p.x - w*2 + 1;  // yields 1-pixel width outline
        //	 r.origin.y = p.y - w*2 + 1;
        //	 r.size.width = w*4 - 2;
        //	 r.size.height = w*4 - 2;
        //	 [P appendBezierPath:[NSBezierPath bezierPathWithOvalInRect:r]];
    }
    
//    else if ( shape == RS_ARROW ) {
//	
//	b = 3*w;//5*w/8; // the "big" dimension of the ^
//	c = 3*w;//5*w/8; // the "small" dimension of the ^
//        
//        [P appendArrowheadAtPoint:p width:b height:c];
//	
//	// rotate the arrowhead if necessary
//        if (rotation) {
//            [P rotateInFrame:r byDegrees:rotation];
//        }
//    }
    
    //
    else { // if the end of an arrow, or something unspecified, make it round:
        //NSLog(@"Shouldn't happen?");
        w *= 4;
        r.origin.x = p.x - (w / 2);
        r.origin.y = p.y - (w / 2);
        r.size.width  = w;
        r.size.height = w;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        [P appendPath:[UIBezierPath bezierPathWithOvalInRect:r]];
#else
        [P appendBezierPathWithOvalInRect:r];
#endif
    }
    
    
    //    [_pathCache setObject:P forKey:[V identifier]];
}


@interface RSGraphRenderer (/*Private*/)
//- (void)_appendToPath:(NSBezierPath *)P shapeFromVertex:(RSVertex *)V newWidth:(CGFloat)width newShape:(NSInteger)shape;
@end

@implementation RSGraphRenderer


////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Positioning Axis labels
////

// Returns NO if the label doesn't fit into the existing labels, YES if ok
- (BOOL)positionLabelSized:(CGSize)size forTick:(data_p)tick onAxis:(RSAxis *)A {
    RSTextLabel *TL;
    RSTextLabel *newLabel = [A userLabelForTick:tick];
    CGPoint p;
    CGRect r, rNew;
    
    //NSLog(@"position label: '%@' tick: %f", [newLabel text], tick);
    
    // compute size of label:
    //if( CGSizeEqualToSize(size, CGSizeMake(0,0)) )  // if nothing specified, use real size
    rNew.size = [newLabel size];
    //else  // use the size specified thru the method's parameters
    //	rNew.size = size;
    
    // HORIZONTAL AXIS //
    if ( [A orientation] == RS_ORIENTATION_HORIZONTAL ) {
	// position the label:
        RSDataPoint pUser = RSDataPointMake(tick, [_mapper originPoint].y);
	p = [_mapper convertToViewCoords:pUser];
	p.y -= (rNew.size.height + [A labelDistance] + [A width]);
	p.x -= (rNew.size.width / 2);
	[newLabel setPosition:[_mapper convertToDataCoords:p]];
	
	// set up rectangle surrounded by the full buffer size:
	rNew.origin = p;
	if( (rNew.size.width < size.width) ) {  //&& (CGSizeEqualToSize(size, CGSizeMake(0,0))) ) {
	    // expand to fit constant label size
	    rNew.origin.x -= (size.width - rNew.size.width)/2;
	    rNew.size.width = size.width;
	}
	CGFloat padding = [A tickLabelPadding];
	rNew.origin.x -= padding;
	rNew.size.width += padding*2;
	
	//NSLog(@"tick %.3f rect:(%f,%f) size(%f,%f)", tick, rNew.origin.x, rNew.origin.y, rNew.size.width, rNew.size.height);
	
	// see if the new label overlaps with already-placed labels
	for (TL in _axisLabels) {
	    // don't worry about overlapping labels on other axes
	    if( [TL axisOrientation] != [A orientation] )  continue;  // skip it
	    // also don't worry about labels that are blank
	    if( [TL isDeletedString] )  continue;
	    
	    r.origin = [_mapper convertToViewCoords:[TL position]];
	    r.size = [TL size];
	    if( r.size.width < size.width )  {
		// expand appropriately
		r.origin.x -= (size.width - r.size.width)/2;
		r.size.width = size.width;
	    }
	    //NSLog(@"    compRect:(%f,%f) size(%f,%f)", r.origin.x, r.origin.y, r.size.width, r.size.height);
	    // Check if rects overlap:
            
            //
            if (CGRectIntersectsRect(r, rNew))
                return NO;
	}
	// If got this far...
	[newLabel setTickValue:tick axisOrientation:[A orientation]];
	return YES;
    }
    ///////////////////
    // VERTICAL AXIS //
    ///////////////////
    else if ( [A orientation] == RS_ORIENTATION_VERTICAL ) {
	// position the label:
        RSDataPoint pUser = RSDataPointMake([_mapper originPoint].x, tick);
	//if ( ![A stuckAtZero] || [_graph xMin] > 0 || [_graph xMax] < 0 )  p.x = [_graph xMin];
	//else  p.x = 0;
	p = [_mapper convertToViewCoords:pUser];
	p.x -= (rNew.size.width + [A labelDistance] + [A width]);
	p.y -= (rNew.size.height / 2);
	[newLabel setPosition:[_mapper convertToDataCoords:p]];
	
	// set up rectangle surrounded by the full buffer size:
	rNew.origin = p;
	if( (rNew.size.height < size.height) ) {  //&& (CGSizeEqualToSize(size, CGSizeMake(0,0))) ) {
	    // expand to fit constant label size
	    rNew.origin.y -= (size.height - rNew.size.height)/2;
	    rNew.size.height = size.height;
	}
	CGFloat padding = [A tickLabelPadding];
	rNew.origin.y -= padding;
	rNew.size.height += padding*2;
	
	//NSLog(@"tick %.3f rect:(%f,%f) size(%f,%f)", tick, rNew.origin.x, rNew.origin.y, rNew.size.width, rNew.size.height);
	
	// see if the new label overlaps with already-placed labels
	for (TL in _axisLabels) {
	    // don't worry about overlapping labels on other axes
	    if( [TL axisOrientation] != [A orientation] )  continue;  // skip it
	    // also don't worry about labels that are blank
	    if( [TL isDeletedString] )  continue;
	    
	    r.origin = [_mapper convertToViewCoords:[TL position]];
	    r.size = [TL size];
	    if( r.size.height < size.height )  {
		// expand appropriately
		r.origin.y -= (size.height - r.size.height)/2;
		r.size.height = size.height;
	    }
	    //NSLog(@"    compRect:(%f,%f) size(%f,%f)", r.origin.x, r.origin.y, r.size.width, r.size.height);
	    // Check if rects overlap:
            if (CGRectIntersectsRect(r, rNew))
                return NO;
	}
	// If got this far...
	[newLabel setTickValue:tick axisOrientation:[A orientation]];
	return YES;
    }
    else {
	NSLog(@"Error: unsupported axis type in positionLabelSized...");
	return NO;
    }
}
- (BOOL)positionLabelForTick:(data_p)tick onAxis:(RSAxis *)A {
    return [self positionLabelSized:CGSizeMake(0,0) forTick:tick onAxis:A];
}

- (void)positionLabelsForAxis:(RSAxis *)A {
    OBPRECONDITION([A maxLabel] && [A minLabel] && [A userLabelsDictionary]);
    
    // Find out whether the zero label is hidden.  this only occurs if it is overlapped by an axis, and is not a min/max label.
    BOOL zeroLabelIsHidden = [A zeroLabelIsHidden];
    
    // If the axis uses a data extent, don't put tick labels past that
    BOOL useDataExtent = ([A extent] == RSAxisExtentDataRange || [A extent] == RSAxisExtentDataQuartiles);
    data_p dataMin = 0, dataMax = 0;
    if (useDataExtent) {
        RSSummaryStatistics stats = [RSGraph summaryStatisticsOfGroup:[_graph dataVertices] inOrientation:[A orientation]];
        dataMin = stats.min;
        dataMax = stats.max;
        if (nearlyEqualDataValues(dataMin, dataMax)) {
            useDataExtent = NO;
        }
    }
    
    // Start positioning labels.
    // Min and max labels:
    [_axisLabels addObject:[A maxLabel]];
    [_axisLabels addObject:[A minLabel]];
    
    // Get the rest of the labels:
    NSArray *tickArray = [A allTicks];
    if (![tickArray count]) {
        return;
    }
    
    // It turns out that -userLabelIsCustomForTick: is moderately expensive.  So only look once for the tick labels that have customized text.
    NSMutableArray *customizedTicks = [NSMutableArray array];
    for (NSNumber *number in tickArray) {
        data_p tick = [number doubleValue];
        
        if ([A valueIsNearlyEqualToZero:tick] && zeroLabelIsHidden)
            continue;
        
        if (useDataExtent && (tick < dataMin || tick > dataMax))
            continue;
        
        if (![A userLabelIsCustomForTick:tick])
            continue;
        
        [customizedTicks addObject:number];
    }
    
    // 1. Labels with customized text:
    for (NSNumber *number in customizedTicks) {
        data_p tick = [number doubleValue];
        
        if( [self positionLabelForTick:tick onAxis:A] ) {
            [_axisLabels addObject:[A userLabelForTick:tick]];
        }
    }
    
    // 2. Estimate the size of the biggest label, using a manageable number of labels:
    NSMutableArray *samplingTicks = [A samplingTicks];
    if ([samplingTicks count] == 0) {
        [samplingTicks addObject:[NSNumber numberWithDouble:[A min]]];
        [samplingTicks addObject:[NSNumber numberWithDouble:[A max]]];
    }
    
    CGSize biggestLabelSize = CGSizeZero;
    for (NSNumber *number in samplingTicks) {
        data_p tick = [number doubleValue];
        
        if ([A valueIsNearlyEqualToZero:tick] && zeroLabelIsHidden)
            continue;
        
        if (useDataExtent && (tick < dataMin || tick > dataMax))
            continue;
        
        if ([customizedTicks containsObject:number])
            continue;
        
        CGSize curSize = [[A userLabelForTick:tick] size];
        if( biggestLabelSize.width < curSize.width ) {
            biggestLabelSize.width = curSize.width;
        }
        if( biggestLabelSize.height < curSize.height ) {
            biggestLabelSize.height = curSize.height;
        }
    }
    
    // 2b. We need to know the size necessary with and without min/max labels
    CGSize biggestLabelSizeWithoutEndLabels = biggestLabelSize;
    NSMutableArray *endTicks = [NSMutableArray arrayWithCapacity:2];
    [endTicks addObject:[NSNumber numberWithDouble:[A min]]];
    [endTicks addObject:[NSNumber numberWithDouble:[A max]]];
    
    for (NSNumber *number in endTicks) {
        data_p tick = [number doubleValue];
        
        if ([A valueIsNearlyEqualToZero:tick] && zeroLabelIsHidden)
            continue;
        
        if (useDataExtent && (tick < dataMin || tick > dataMax))
            continue;
        
        if ([customizedTicks containsObject:number])
            continue;
        
        CGSize curSize = [[A userLabelForTick:tick] size];
        if( biggestLabelSize.width < curSize.width ) {
            biggestLabelSize.width = curSize.width;
        }
        if( biggestLabelSize.height < curSize.height ) {
            biggestLabelSize.height = curSize.height;
        }
    }
    
    
    // 3. Decide what tick spacing to use for the non-custom labels
    CGFloat axisLength = [_mapper viewLengthOfAxis:A];
    CGFloat labelLength = dimensionOfSizeInOrientation(biggestLabelSize, [A orientation]) + [A tickLabelPadding];
    NSInteger tickLimit = floor(axisLength/labelLength);
    // Store the resulting tick label spacing value so we can use it for tick rendering.
    A.tickLabelSpacing = [A tickSpacingWithTickLimit:tickLimit];
    //DEBUG_RS(@"labelLength: %g, tickLimit: %d; tickLabelSpacing: %g", labelLength, tickLimit, A.tickLabelSpacing);
    
    
    RSAxisType axisType = [A axisType];
    
    //
    if ([A usesEvenlySpacedTickMarks]) {
        
        // 4. Display the non-custom labels (except for those that don't fit due to unusual formatting)
        NSArray *labelingTicks = [A linearTicksWithSpacing:A.tickLabelSpacing min:[A min] max:[A max]];
        for (NSNumber *number in labelingTicks) {
            data_p tick = [number doubleValue];
            
            if ([A valueIsNearlyEqualToZero:tick] && zeroLabelIsHidden)
                continue;
            
            if (useDataExtent && (tick < dataMin || tick > dataMax))
                continue;
            
            if ([customizedTicks containsObject:number])
                continue;
            
            if( [self positionLabelSized:biggestLabelSize forTick:tick onAxis:A] ) {
                [_axisLabels addObject:[A userLabelForTick:tick]];
            }
        }
    }
    
    //
    else if (axisType == RSAxisTypeLogarithmic) {
        
        // 4. For log axes, start by placing regime boundaries (tick spacing multiples of 10)
        data_p spacingMagnitude = MAX(1, A.tickLabelSpacing);
        NSMutableArray *regimeBoundaryTicks = [A logarithmicTicksWithRegimeBoundarySpacing:spacingMagnitude min:[A min] max:[A max]];
        for (NSNumber *number in regimeBoundaryTicks) {
            data_p tick = [number doubleValue];
            
            if ([A valueIsNearlyEqualToZero:tick] && zeroLabelIsHidden)
                continue;
            
            if (useDataExtent && (tick < dataMin || tick > dataMax))
                continue;
            
            if ([customizedTicks containsObject:number])
                continue;
            
            if( [self positionLabelForTick:tick onAxis:A] ) {
                [_axisLabels addObject:[A userLabelForTick:tick]];
            }
        }
        
        // If the axis spans many orders of magnitude, never add any more tick labels (even if the axis is long).
        if ([A ordersOfMagnitude] >= RSLogarithmicMinorLabelsMaxMagnitude) {
            return;
        }
        
        // Decide if there's enough room for non-regime-boundary tick labels.
        CGFloat space = [_mapper viewLengthOfAxis:A]/(CGFloat)[A ordersOfMagnitude];
        CGFloat neededPerLabel = dimensionOfSizeInOrientation(biggestLabelSize, [A orientation]) + [A tickLabelPadding];
        CGFloat neededPerLabelWithoutEndLabels = dimensionOfSizeInOrientation(biggestLabelSizeWithoutEndLabels, [A orientation]) + [A tickLabelPadding];
        
        BOOL labelRegimeBoundariesOnly = (space < neededPerLabelWithoutEndLabels * 11);
        BOOL labelFirstFiveOnly = (space < neededPerLabel * 22);
        
        if (labelRegimeBoundariesOnly) {
            return;
        } else {
            A.tickLabelSpacing = 0;
        }

        
        // 4. Fill in left-to-right using the big label size
        for (NSNumber *number in tickArray) {
            data_p tick = [number doubleValue];
            //NSLog(@"tick: %g", tick);
            
            if ([A valueIsNearlyEqualToZero:tick] && zeroLabelIsHidden)
                continue;
            
            if (useDataExtent && (tick < dataMin || tick > dataMax))
                continue;
            
            if ([customizedTicks containsObject:number])
                continue;
            
            if (labelFirstFiveOnly) {
                data_p log = log10(fabs(tick));
                data_p frac = log - trunc(log);
                if (log < 0) {
                    frac = 1 + frac;
                }
                if (frac > log10(5.0000000001))
                    continue;
            }
            
            if( [self positionLabelSized:biggestLabelSizeWithoutEndLabels forTick:tick onAxis:A] ) {
                [_axisLabels addObject:[A userLabelForTick:tick]];
            }
        }
    }
    
}

- (void)resetAxisLabels {
    RSTextLabel *TL;
    for (TL in _axisLabels) {
	[TL setVisible:NO];
    }
    
    CFArrayRemoveAllValues((CFMutableArrayRef)_axisLabels);
}



///////////
#pragma mark -
#pragma mark init/dealloc
///////////

- (id)initWithMapper:(RSDataMapper *)mapper;
{
    if (!(self = [super init]))
        return nil;
    
    _mapper = [mapper retain];
    _graph = [[_mapper graph] retain];
    
    _axisLabels = (NSMutableArray *)OFCreateNonOwnedPointerArray();  // Creates an NSMutableArray that doesn't retain its members.
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    _shadow = [[NSShadow alloc] init];
#endif
    _pathCache = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)dealloc;
{
    [_graph release];
    [_mapper release];
    
    [_axisLabels release];
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    [_shadow release];
#endif
    [_pathCache release];
    
    [super dealloc];
}


////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Auto-adjusting whitespace
////

- (CGSize)tickLabelMaxSizeForAxis:(RSAxis *)A;
{
    if( ![_graph displayAxisLabels] )
	return CGSizeMake(0, 0);
    
    OBASSERT([_axisLabels count] > 0);  // if assertion fails, [positionAxisTickLabels] probably hasn't been called
    
    CGSize s, max = CGSizeMake(0, 0);
    RSTextLabel *TL;
    for (TL in _axisLabels) {
	if( [TL axisOrientation] == [A orientation] ) {
	    s = [TL size];
	    if( s.width > max.width )  max.width = s.width;
	    if( s.height > max.height )  max.height = s.height;
	}
    }
    return max;
}

- (CGFloat)tickLabelDistanceNeededPastAxis:(RSAxis *)A;
{
    OBASSERT([A displayTickLabels]);
    
    CGFloat distance = [A labelDistance];  // distance to tick labels
    CGSize tickLabelMaxSize = [self tickLabelMaxSizeForAxis:A];  // tick label size
    
    // Handle the case where the tick labels are partially or fully inside the margin borders.
    CGPoint origin = [_mapper convertToViewCoords:[_mapper originPoint]];
    CGPoint viewMins = [_mapper viewMins];
    if ([A orientation] == RS_ORIENTATION_HORIZONTAL) {
	distance += tickLabelMaxSize.height;
	if (origin.y > viewMins.y) {
	    distance -= origin.y - viewMins.y;
	}
    }
    else if ([A orientation] == RS_ORIENTATION_VERTICAL) {
	distance += tickLabelMaxSize.width;
	if (origin.x > viewMins.x) {
	    distance -= origin.x - viewMins.x;
	}
    }
    
    if (distance < 0)
	distance = 0;
    return distance;
}

- (RSBorder)tickLabelWhitespaceBorderForAxis:(RSAxis *)A;
{
    RSBorder border = RSMakeBorder(0, 0, 0, 0);
    CGFloat tickBorder = 0;
    
    if ([A displayTicks]) {
        tickBorder = [A width] * 0.5f;  // thickness of the edge ticks on the axis
    }
    
    if ([A orientation] == RS_ORIENTATION_HORIZONTAL) {
        
        // RIGHT
        if ([A displayTickLabels] && ![[[A maxLabel] text] isEqualToString:RS_DELETED_STRING]) {
            border.right = [[A maxLabel] size].width * 0.5f;  // x-max label
        }
        if (tickBorder > border.right)
            border.right = tickBorder;
        
        // LEFT
        if ([A displayTickLabels] && ![[[A minLabel] text] isEqualToString:RS_DELETED_STRING]) {
            border.left = [[A minLabel] size].width * 0.5f;  // x-min label
        }
        if (tickBorder > border.left)
            border.left = tickBorder;
        
        // TOP
        if ([A displayTicks]) {
            border.top = [A tickWidthIn];
        }
        
        // BOTTOM
        if ([A displayAxis]) {
            border.bottom = [A width];
        }
        if ([A displayTickLabels]) {
            border.bottom += [self tickLabelDistanceNeededPastAxis:A];
        }
    }
    else if ([A orientation] == RS_ORIENTATION_VERTICAL) {
        
        // TOP
        if ([A displayTickLabels] && ![[[A maxLabel] text] isEqualToString:RS_DELETED_STRING]) {
            border.top = [[A maxLabel] size].height * 0.5f;  // y-max label
        }
        if (tickBorder > border.top)
            border.top = tickBorder;
        
        // BOTTOM
        if ([A displayTickLabels] && ![[[A minLabel] text] isEqualToString:RS_DELETED_STRING]) {
            border.bottom = [[A minLabel] size].height * 0.5f;  // y-min label
        }
        if (tickBorder > border.bottom)
            border.bottom = tickBorder;
        
        // RIGHT
        if ([A displayTicks]) {
            border.right = [A tickWidthIn];
        }
        
        // LEFT
        if ([A displayAxis]) {
            border.left = [A width];
        }
        if ([A displayTickLabels]) {
            border.left += [self tickLabelDistanceNeededPastAxis:A];
        }
    }

    return border;
}

- (RSBorder)tickLabelWhitespaceBorder;
{
    RSBorder xAxisBorder = [self tickLabelWhitespaceBorderForAxis:[_graph xAxis]];
    RSBorder yAxisBorder = [self tickLabelWhitespaceBorderForAxis:[_graph yAxis]];
    
    RSBorder comboBorder = RSUnionBorder(xAxisBorder, yAxisBorder);
    
    // TODO: Some border edges shouldn't be unioned, although it should depend on the arrangement of the axes
    if (comboBorder.top > yAxisBorder.top) {
        comboBorder.top = yAxisBorder.top;
    }
    if (comboBorder.right > xAxisBorder.right) {
        comboBorder.right = xAxisBorder.right;
    }
    
    return comboBorder;
}

- (RSBorder)axisTitleWhitespaceBorder;
// returns the border required by the axis titles
{
    RSBorder border = RSMakeBorder(0, 0, 0, 0);
    
    if ([[[_graph xAxis] title] isVisible]) {
	border.bottom += [[_graph xAxis] titleDistance];
	border.bottom += [[[_graph xAxis] title] size].height;  // size of title
    }
    
    if ([[[_graph yAxis] title] isVisible]) {
	border.left += [[_graph yAxis] titleDistance];
	border.left += [[[_graph yAxis] title] size].height;
    }
    
    return border;
}

- (RSBorder)axisArrowsWhitespaceBorder;
{
    RSBorder border = RSMakeBorder(0, 0, 0, 0);

    RSAxis *xAxis = [_graph xAxis];
    if ([xAxis displayAxis]) {
        CGFloat arrowWidth = [xAxis width] * 3;
        if ([xAxis shouldDrawMinArrow]) {
            border.left = arrowWidth;
        }
        if ([xAxis shouldDrawMaxArrow]) {
            border.right = arrowWidth;
        }
    }
    
    RSAxis *yAxis = [_graph yAxis];
    if ([yAxis displayAxis]) {
        CGFloat arrowWidth = [yAxis width] * 3;
        if ([yAxis shouldDrawMinArrow]) {
            border.bottom = arrowWidth;
        }
        if ([yAxis shouldDrawMaxArrow]) {
            border.top = arrowWidth;
        }
    }
    
    return border;
}

- (RSBorder)totalAutoWhitespaceBorder;
{
    RSBorder tickLabelBorder = [self tickLabelWhitespaceBorder];
    RSBorder axisTitleBorder = [self axisTitleWhitespaceBorder];
    RSBorder summedAxisBorder = RSSumBorder(tickLabelBorder, axisTitleBorder);
    RSBorder axisArrowsBorder = [self axisArrowsWhitespaceBorder];
    RSBorder unionedAxisBorder = RSUnionBorder(summedAxisBorder, axisArrowsBorder);
    
    RSBorder paddedBorder = RSSumBorder(unionedAxisBorder, [_graph edgePadding]);
    return paddedBorder;
}

- (void)autoUpdateWhitespaceEvenIfShrinks:(BOOL)always;
{
    // This seems to keep the number formatters happier. <bug:///69966>
    [[_graph xAxis] resetNumberFormatters];
    [[_graph yAxis] resetNumberFormatters];
    
    [[_graph xAxis] updateTickMarks];
    [[_graph yAxis] updateTickMarks];
    
    [self positionAxisTickLabels];
    RSBorder autoBorder = [self totalAutoWhitespaceBorder];
    
    if (always)
	[_graph setWhitespace:autoBorder];
    else {
	// Only expand the whitespace
	RSBorder expandedBorder = RSUnionBorder(autoBorder, [_graph whitespace]);
	[_graph setWhitespace:expandedBorder];
    }
}

- (void)updateWhitespace;
// The public method
{
    //DEBUG_RS(@"updateWhitespace");
    [self autoUpdateWhitespaceEvenIfShrinks:[_graph autoMaintainsWhitespace]];
}



////////////////
#pragma mark -
#pragma mark Laying out axis labels
////////////////

// The wrapper method called by RSGraphView to set up axis labels
- (void)positionAllAxisLabels;
{
    [self positionAxisEndLabels];
    [self positionAxisTickLabels];
    [self positionAxisTitles];
}

- (void)positionAxisTickLabels;
{
    // reset the axis labels holder
    [self resetAxisLabels];
    
    if ( [[_graph xAxis] displayTickLabels] )
	[self positionLabelsForAxis:[_graph xAxis]];
    if ( [[_graph yAxis] displayTickLabels] )
	[self positionLabelsForAxis:[_graph yAxis]];
    
    RSTextLabel *TL;
    //NSLog(@"_axisLabels:");
    for (TL in _axisLabels) {
	[TL setVisible:YES];
	//NSLog(@"  '%@'", [TL text]);
    }
    
    [[_graph xAxis] purgeUnnecessaryUserLabels];
    [[_graph yAxis] purgeUnnecessaryUserLabels];
}

- (void)positionAxisTitles;
{
    RSAxis *axis;
    CGPoint p;
    CGSize titleSize;
    CGFloat axisLength;
    
    // position the titles outside the axes and tick labels (if visible)
    RSBorder tickLabelBorder = [self tickLabelWhitespaceBorder];
    
    // x-Axis Title
    axis = [_graph xAxis];
    titleSize = [[axis title] size];
    p = [_mapper viewMins];
    p.y -= tickLabelBorder.bottom;
    p.y -= [axis titleDistance];
    p.y -= titleSize.height;
    
    RSBorder singleAxisBorder = [self tickLabelWhitespaceBorderForAxis:axis];
    CGFloat viewMin = [_mapper viewMins].x - singleAxisBorder.left;
    CGFloat viewMax = [_mapper viewMaxes].x + singleAxisBorder.right;
    axisLength = viewMax - viewMin;
    p.x = viewMin;
    p.x += axisLength * [axis titlePlacement];
    p.x -= titleSize.width * [axis titlePlacement];
    
    [[axis title] setPosition:[_mapper convertToDataCoords:p]];
    
    
    // y-Axis Title
    axis = [_graph yAxis];
    titleSize = [[axis title] size];
    p = [_mapper viewMins];
    p.x -= tickLabelBorder.left;
    p.x -= [axis titleDistance];
    //p.x -= titleSize.height; // we don't want this extra shift because rotating 90 degrees around the lower-left corner makes already makes that the lower-right corner.
    
    singleAxisBorder = [self tickLabelWhitespaceBorderForAxis:axis];
    viewMin = [_mapper viewMins].y - singleAxisBorder.bottom;
    viewMax = [_mapper viewMaxes].y + singleAxisBorder.top;
    axisLength = viewMax - viewMin;
    p.y = viewMin;
    p.y += axisLength * [axis titlePlacement];
    p.y -= titleSize.width * [axis titlePlacement];
    
    [[axis title] setPosition:[_mapper convertToDataCoords:p]];
}

- (void)positionAxisEndLabels;
// Updates axis min and max labels only
{
    RSDataPoint pUser, origin;
    CGPoint p, viewOrigin;
    
    data_p xMin = [_graph xMin];
    data_p xMax = [_graph xMax];
    data_p yMin = [_graph yMin];
    data_p yMax = [_graph yMax];
    
    pUser = origin = [_mapper originPoint];
    //p.y = p.x = 0.0;
    // the "origin" of the axes may or may not actually be at 0,0:
    //if ( ![[_graph xAxis] stuckAtZero] || _yMin > 0 || _yMax < 0 ) p.y = _yMin;
    //if ( ![[_graph yAxis] stuckAtZero] || _xMin > 0 || _xMax < 0 ) p.x = _xMin;
    viewOrigin = [_mapper convertToViewCoords:pUser];
    
    
    // xMin
    pUser.x = xMin;
    p = [_mapper convertToViewCoords:pUser];
    if( origin.x == xMin && origin.y != yMin )  // x-axis is in the way of the min label
	p.x += [[_graph yAxis] width] + [[_graph yAxis] labelDistance];
    else
	p.x -= ( [[[_graph xAxis] minLabel] size].width / 2 );
    p.y = viewOrigin.y - [[[_graph xAxis] minLabel] size].height 
    - [[_graph xAxis] labelDistance] - [[_graph xAxis] width];
    [[[_graph xAxis] minLabel] setPosition:[_mapper convertToDataCoords:p]];
    
    /*
     // xMin
     p.x = _xMin;
     p = [_mapper convertToViewCoords:p];
     if ( _yMin >= 0 || _xMin < 0 ) { // y axis is NOT in the way of label
     p.x -= ( [[[_graph xAxis] minLabel] size].width / 2 );
     p.y = viewOrigin.y - [[[_graph xAxis] minLabel] size].height 
     - [[_graph xAxis] labelDistance] - [[_graph xAxis] width];
     }
     else {  // y axis IS in the way
     //p.x -= [[_graph yAxis] width] + [[_graph yAxis] labelDistance];
     p.x -= [[[_graph xAxis] minLabel] size].width + [[_graph yAxis] labelDistance] + [[_graph yAxis] width];
     p.y -= ([[[_graph xAxis] minLabel] size].height / 2.0);
     }
     [[[_graph xAxis] minLabel] setPosition:[_mapper convertToDataCoords:p]];
     if ( view && [_s selection] == [[_graph xAxis] minLabel] )
     [view setFrameOrigin:p];
     */
    
    // xMax
    pUser.x = xMax;
    p = [_mapper convertToViewCoords:pUser];
    p.x -= ( [[[_graph xAxis] maxLabel] size].width / 2 );
    p.y = viewOrigin.y - [[[_graph xAxis] maxLabel] size].height 
    - [[_graph xAxis] labelDistance] - [[_graph xAxis] width];
    [[[_graph xAxis] maxLabel] setPosition:[_mapper convertToDataCoords:p]];
    
    // yMin
    pUser.y = yMin;
    p = [_mapper convertToViewCoords:pUser];
    if( origin.x != xMin && origin.y == yMin )  // x-axis is in the way of the min label
	p.y += [[_graph xAxis] width] + [[_graph xAxis] labelDistance];
    else  // not in the way
	p.y -= ( [[[_graph yAxis] minLabel] size].height / 2 );
    p.x = viewOrigin.x - [[[_graph yAxis] minLabel] size].width 
    - [[_graph yAxis] labelDistance] - [[_graph yAxis] width];
    [[[_graph yAxis] minLabel] setPosition:[_mapper convertToDataCoords:p]];
    
    // yMax
    pUser.y = yMax;
    p = [_mapper convertToViewCoords:pUser];
    p.y -= ( [[[_graph yAxis] minLabel] size].height / 2 );
    p.x = viewOrigin.x - [[[_graph yAxis] maxLabel] size].width 
    - [[_graph yAxis] labelDistance] - [[_graph yAxis] width];
    [[[_graph yAxis] maxLabel] setPosition:[_mapper convertToDataCoords:p]];
}

- (NSArray *)_sortedUserLabels;
// Sort by y descending and then x ascending
{
    NSArray *userLabels = [_graph userLabels];
    if (![userLabels count])
        return nil;
    
    NSSortDescriptor *yDescriptor = [[NSSortDescriptor alloc] initWithKey:@"positiony" ascending:NO];
    NSSortDescriptor *xDescriptor = [[NSSortDescriptor alloc] initWithKey:@"positionx" ascending:YES];
    NSArray *sortedLabels = [userLabels sortedArrayUsingDescriptors:[NSArray arrayWithObjects:yDescriptor, xDescriptor, nil]];
    [yDescriptor release];
    [xDescriptor release];
    
    return sortedLabels;
}

- (RSTextLabel *)nextLabel:(RSGraphElement *)GE;
// Returns the next label that should be edited after TL (i.e. when pressing the tab key)
{
    RSTextLabel *TL = nil;
    
    // Handle GE that is nil or not a text label
    if (![GE isKindOfClass:[RSTextLabel class]]) {
        TL = [GE label];
        if (TL) {
            return TL;
        }
        // otherwise, return the first user label, if any
        NSArray *sortedLabels = [self _sortedUserLabels];
        if ([sortedLabels count]) {
            return [sortedLabels objectAtIndex:0];
        }
        return nil;
    }
    else {
        TL = (RSTextLabel *)GE;
    }
    
    // Handle labels that are on an axis
    if ([TL isPartOfAxis]) {
            
        data_p tickValue = [TL tickValue];
        int axisOrientation = [TL axisOrientation];
        RSTextLabel *nextLabel = nil;
        
        // First, some special cases
        if (TL == [[_graph yAxis] minLabel]) {
            return [[_graph xAxis] minLabel];
        }
        else if (TL == [[_graph xAxis] maxLabel]) {
            return [[_graph xAxis] title];
        }
        else if (TL == [[_graph xAxis] title]) {
            return [[_graph yAxis] title];
        }
        else if (TL == [[_graph yAxis] title]) {
            return [[_graph yAxis] maxLabel];
        }
        
        // Otherwise, go left to right and top to bottom along the tick labels
        else if (axisOrientation == RS_ORIENTATION_HORIZONTAL) {  // tab from left to right
            data_p closestValue = [_graph xMax];
            
            // Assuming that the total number of tick labels is small, the brute-force approach is plenty fast.
            for (RSTextLabel *tickLabel in _axisLabels) {
                if ([tickLabel axisOrientation] != axisOrientation)
                    continue;
                
                data_p newValue = [tickLabel tickValue];
                if (newValue <= tickValue)
                    continue;
                if (newValue <= closestValue) {
                    closestValue = newValue;
                    nextLabel = tickLabel;
                }
            }
        }
        else if (axisOrientation == RS_ORIENTATION_VERTICAL) {  // tab from top to bottom
            data_p closestValue = [_graph yMin];
            
            for (RSTextLabel *tickLabel in _axisLabels) {
                if ([tickLabel axisOrientation] != axisOrientation)
                    continue;
                
                data_p newValue = [tickLabel tickValue];
                if (newValue >= tickValue)
                    continue;
                if (newValue >= closestValue) {
                    closestValue = newValue;
                    nextLabel = tickLabel;
                }
            }
        }
        
        if (nextLabel) {
            return nextLabel;
        }
    }
    
    // Handle labels not attached to the axes by traversing y descending and then x ascending
    else {
        NSArray *sortedLabels = [self _sortedUserLabels];
        if (![sortedLabels count]) {
            return nil;
        }
        
        NSUInteger index = [sortedLabels indexOfObjectIdenticalTo:TL];
        if (index == NSNotFound) {
            return [sortedLabels objectAtIndex:0];
        }
        
        if (index == [sortedLabels count] - 1) {
            index = 0;
        } else {
            index += 1;
        }
        OBASSERT_NONNEGATIVE(index);
        OBASSERT(index < [sortedLabels count]);
        
        return [sortedLabels objectAtIndex:index];
    }
    
    return nil;
}

- (RSTextLabel *)previousLabel:(RSGraphElement *)GE;
// Returns the previous label that should be edited after TL (i.e. when pressing shift-tab)
{
    RSTextLabel *TL = nil;
    
    // Handle GE that is nil or not a text label
    if (![GE isKindOfClass:[RSTextLabel class]]) {
        TL = [GE label];
        if (TL) {
            return TL;
        }
        // otherwise, return the last user label, if any
        NSArray *sortedLabels = [self _sortedUserLabels];
        if ([sortedLabels count]) {
            return [sortedLabels objectAtIndex:[sortedLabels count] - 1];
        }
        return nil;
    }
    else {
        TL = (RSTextLabel *)GE;
    }
    
    // Handle labels that are on an axis
    if ([TL isPartOfAxis]) {
        
        data_p tickValue = [TL tickValue];
        int axisOrientation = [TL axisOrientation];
        RSTextLabel *nextLabel = nil;
        
        // First, some special cases
        if (TL == [[_graph xAxis] minLabel]) {
            return [[_graph yAxis] minLabel];
        }
        else if (TL == [[_graph xAxis] title]) {
            return [[_graph xAxis] maxLabel];
        }
        else if (TL == [[_graph yAxis] title]) {
            return [[_graph xAxis] title];
        }
        else if (TL == [[_graph yAxis] maxLabel]) {
            return [[_graph yAxis] title];
        }
        
        // Otherwise, go right to left and bottom to top along the tick labels
        else if (axisOrientation == RS_ORIENTATION_HORIZONTAL) {  // tab from left to right
            data_p closestValue = [_graph xMin];
            
            for (RSTextLabel *tickLabel in _axisLabels) {
                if ([tickLabel axisOrientation] != axisOrientation)
                    continue;
                
                data_p newValue = [tickLabel tickValue];
                if (newValue >= tickValue)
                    continue;
                if (newValue >= closestValue) {
                    closestValue = newValue;
                    nextLabel = tickLabel;
                }
            }
        }
        else if (axisOrientation == RS_ORIENTATION_VERTICAL) {  // tab from top to bottom
            data_p closestValue = [_graph yMax];
            
            for (RSTextLabel *tickLabel in _axisLabels) {
                if ([tickLabel axisOrientation] != axisOrientation)
                    continue;
                
                data_p newValue = [tickLabel tickValue];
                if (newValue <= tickValue)
                    continue;
                if (newValue <= closestValue) {
                    closestValue = newValue;
                    nextLabel = tickLabel;
                }
            }
        }
        
        if (nextLabel) {
            return nextLabel;
        }
    }
    
    // Handle labels not attached to the axes by traversing the opposite of [y descending and then x ascending].
    else {
        NSArray *sortedLabels = [self _sortedUserLabels];
        if (![sortedLabels count]) {
            return nil;
        }
        
        NSUInteger index = [sortedLabels indexOfObjectIdenticalTo:TL];
        if (index == NSNotFound) {
            return [sortedLabels objectAtIndex:0];
        }
        
        if (index == 0) {
            index = [sortedLabels count] - 1;
        } else {
            index -= 1;
        }
        OBASSERT_NONNEGATIVE(index);
        OBASSERT(index < [sortedLabels count]);
        
        return [sortedLabels objectAtIndex:index];
    }
    
    return nil;
}



////////////////
#pragma mark -
#pragma mark Laying out labels attached to objects
////////////////
- (CGPoint)positionLabel:(RSTextLabel *)TL forOwner:(RSGraphElement *)e;
// updates the position of the text label owned by graph element e.
// if no such label is attached, a new blank one is created and added to the graph.
{
    RSLine *L;
    
    // Vertex labels //
    if ( [e isKindOfClass:[RSVertex class]] ) {
	if( !TL ){
	    TL = [_graph makeLabelForOwner:e];
	}
	return [self positionLabel:TL onVertex:(RSVertex *)e];
    }
    // Line labels //
    else if ( (L = [RSGraph isLine:e]) ) {
	if( !TL ){
	    TL = [_graph makeLabelForOwner:L];
	}
	return [self positionLabel:TL onLine:L];
    }
    // Fill labels //
    else if ( [e isKindOfClass:[RSFill class]] ) {
	if( !TL ){
	    TL = [_graph makeLabelForOwner:e];
	}
	return [self positionLabel:TL onFill:(RSFill *)e];
    }
    else if ( e ) {
        OBASSERT_NOT_REACHED("Non-supported owner element in positionLabel:ForOwner:");
    }
    return CGPointMake(0, 0);
}

- (CGPoint)positionLabel:(RSTextLabel *)TL inDirection:(CGPoint)direction distance:(CGFloat)w fromPoint:(CGPoint)p flip:(BOOL)shouldFlip;
// All in view coords.
{
    CGPoint norm = v2Normalized(direction);
    CGFloat angle = (CGFloat)(v2Angle(direction)*180/M_PI);
    
    CGFloat flip = 1;
    if (shouldFlip)
        flip = -1;
    
    //DEBUG_RS(@"norm: %f, angle: %f, direction: %@, flip: %f", norm, angle, NSStringFromPoint(direction), flip);
    
    // slide down the line by the length of half the text label
    CGFloat f = [TL size].width * 0.5f;
    p.x += f*norm.x * flip;
    p.y += f*norm.y * flip;
    
    // move away from the line by the specified distance
    p.x += w*norm.y * flip;
    p.y -= w*norm.x * flip;
    
    
    [TL setRotation:angle];
    [TL setPosition:[_mapper convertToDataCoords:p]];
    
    return p;
}

- (CGPoint)positionLabel:(RSTextLabel *)TL onLine:(RSLine *)L;
{
    if ([L hasNoLength]) {
	RSDataPoint p = [L startPoint];
	[TL setPosition:p];
	
	return [_mapper convertToViewCoords:p];  // return view coords position in case it needs to be altered further
    }
    
    // EQUATION LINE
    else if ([L isKindOfClass:[RSEquationLine class]]) {
//        RSEquationLine *EL = (RSEquationLine *)L;
//        
//        // Get xVal at "slide" percentage of the way across the graph
//        CGFloat viewCoordX = [L slide] * CGRectGetWidth([_mapper bounds]);
//        data_p xVal = [_mapper convertToDataCoords:viewCoordX inDimension:RS_ORIENTATION_HORIZONTAL];
//        data_p yVal = [EL yValueForXValue:xVal];
//        
//        CGPoint p = [_mapper convertToViewCoords:RSDataPointMake(xVal, yVal)];
//        
//        CGFloat d = [L width]*0.5 + [L labelDistance];
//        CGPoint direction = CGPointMake(1, 0);
//        
//        return [self positionLabel:TL inDirection:direction distance:d fromPoint:p flip:NO];
        
        // for now
        return [_mapper convertToViewCoords:[TL position]];
    }
    
    // STRAIGHT
    else if( [L vertexCount] == 2 || [L connectMethod] == RSConnectStraight) {
	
	CGPoint p = [_mapper locationOnCurve:L atTime:[L slide]];
	CGPoint direction = [_mapper directionOfLine:L atTime:[L slide]];
	CGFloat d = [L width]*0.5f + [L labelDistance];
        
        BOOL shouldFlip = NO;
        if (nearlyEqualFloats(direction.x, 0) || direction.x > 0)
            shouldFlip = YES;
	
	return [self positionLabel:TL inDirection:direction distance:d fromPoint:p flip:shouldFlip];
    }
    
    // CURVED
    else if( [L vertexCount] > 2 ) {
	OBASSERT([L isKindOfClass:[RSConnectLine class]]);
	OBASSERT([L connectMethod] == RSConnectCurved);
        
//        BOOL shouldFlip = NO;
//        CGFloat t = [L slide];
//        CGFloat z = [_mapper curvatureOfLine:L atTime:t useDelta:0.001];
//        NSLog(@"z: %f", z);
//        if (z > 0) {  // left turn
//            shouldFlip = YES;
//        }
//        
//        CGPoint p = [_mapper locationOnCurve:L atTime:t];
//	CGPoint direction = [_mapper directionOfLine:L atTime:t];
//        CGFloat d = [L width]*0.5 + [L labelDistance];
//        
//        //This doesn't work because we are dealing with different notions of "flipping".
//	return [self positionLabel:TL inDirection:direction distance:d fromPoint:p flip:shouldFlip];
        
	
	CGPoint p, p1, p2;
	CGPoint p0, p3, sp, v1, v2; // for curves
	BOOL leftHand, pointRight, pointUp; // also for curves
	CGFloat w, h, extra, t;
	
	// calculate control points
	RSBezierSpec spec = [_mapper bezierSpecOfConnectLine:(RSConnectLine *)L atTime:[L slide]];
	p0 = spec.p0;
	p1 = spec.p1;
	p2 = spec.p2;
	p3 = spec.p3;
	t = spec.t;  // local t relative to the bezier path
	
	//no curve points in connectlines//cp = [_mapper convertToViewCoords:[L curvePoint]];
	
	// calculate slide point:
	sp = evaluateBezierPathAtT(p0, p1, p2, p3, t);
	
	// position label:
	// first check the direction of the bulge
	v1.x = p3.x - p0.x;  // vector pointing from p0 to p3
	v1.y = p3.y - p0.y;
	v2.x = p2.x - p0.x;  // vector pointing from p0 to cp (i think p2 is equivalent here)
	v2.y = p2.y - p0.y;
	
	if( (v1.x*v2.y - v2.x*v1.y) > 0 ) // bulge is to the left of vector v1 (ccw)
	    leftHand = YES;
	else  leftHand = NO;  // bulge is to the right of vector v1 (clockwise)
	if( p3.x - p0.x > 0 )  pointRight = YES;
	else  pointRight = NO;
	if( p3.y - p0.y > 0 )  pointUp = YES;
	else  pointUp = NO;
	
	
	extra = [L width]*0.5f + [L labelDistance];
	
//	CGFloat angle = [_mapper degreesFromHorizontalOfLine:L atTime:[L slide]];
//	angle *= M_PI/180;  // radians
//	angle = -1/angle;  // perpendicular
//	NSLog(@"%.3f", sinf(angle));
	
	if( (leftHand && pointRight && pointUp) || (!leftHand && !pointRight && !pointUp) ) {
	    // position label with bottom right corner near the slide point
	    w = [TL size].width;
	    p.x = sp.x - w - extra;
	    p.y = sp.y + extra;
	} 
	else if( (leftHand && !pointRight && !pointUp) || (!leftHand && pointRight && pointUp) ) {
	    // position label with top left corner near the slide point
	    h = [TL size].height;
	    p.x = sp.x + extra;
	    p.y = sp.y - h - extra;
	} 
	else if( (leftHand && !pointRight && pointUp) || (!leftHand && pointRight && !pointUp) ) {
	    // top right corner near the slide point
	    p.x = sp.x - [TL size].width - extra;
	    p.y = sp.y - [TL size].height - extra;
	} else {
	    // bottom left corner near the slide point
	    p.x = sp.x + extra;
	    p.y = sp.y + extra;
	}
	
	[TL setRotation:0];
	[TL setPosition:[_mapper convertToDataCoords:p]];
	
	return p; // return view coords position in case it needs to be altered further
    }
    
    NSLog(@"Shouldn't have gotten here in positionLabel: onConnectLine");
    return [_mapper convertToViewCoords:[L startPoint]];
}

- (CGPoint)positionLabel:(RSTextLabel *)TL onVertex:(RSVertex *)V;
{
    // p is initially vertex position in window coords
    CGFloat angle = [V labelPosition];
//    if ([V shape] == RS_BAR_VERTICAL) {  // On vertical bars, the label position setting starts at north instead of east.
//        angle += (CGFloat)PIOVER2;
//    }
    
    CGSize tlSize = [TL size];
    CGFloat w = tlSize.width/2;
    CGFloat h = tlSize.height/2 - 1;
    CGFloat extra;
    if( [V shape] > 0 ) //2.8
	extra = [V width]*2 + [V labelDistance]; // * ( abs(cos( (angle + 0.7854) * 2 ) * 1.1) + 1 );
    else
	extra = [V width]*0.5f + [V labelDistance];
    
    // let offset be the offset of the middle of the label from the vertex
    CGPoint offset = CGPointMake(0 - w, 0 - h);
    // cos/sin squared calculations:
    CGFloat c = cos(angle);
    CGFloat s = sin(angle);
    if( c>=0 )  c = sqrt(c);   else  c = sqrt(c*-1)*-1;
    if( s>=0 )  s = sqrt(s);   else  s = sqrt(s*-1)*-1;
    // move away from vertex:
    offset.x += (w + extra)*c;
    offset.y += (h + extra)*s;
    
    CGPoint p = [_mapper convertToViewCoords:[V position]];
    p.x += offset.x;
    p.y += offset.y;
    
    [TL setPosition:[_mapper convertToDataCoords:p]];
    
    // return position in view coords in case it needs to be altered further
    return p;
}

- (CGPoint)positionLabel:(RSTextLabel *)TL onFill:(RSFill *)F;
    // find center of fill based on extremal points
{
    CGPoint p = [_mapper convertToViewCoords:[F position]];  // lower-left corner
    CGPoint pur = [_mapper convertToViewCoords:[[F vertices] positionUR]];  // upper-right corner
    // get middle:
    CGPoint placement = [F labelPlacement];
    p.x += (pur.x - p.x) * placement.x;
    p.y += (pur.y - p.y) * placement.y;
    
    // reposition based on size of label
    CGSize labelSize = [TL size];
    p.x -= labelSize.width/2;
    p.y -= labelSize.height/2;
    
    [TL setPosition:[_mapper convertToDataCoords:p]];
    
    return p;  // return in view coords
}

- (void)centerLabelInCanvas:(RSTextLabel *)TL;
{
    CGSize canvasSize = [_graph canvasSize];
    CGPoint center = CGPointMake(canvasSize.width/2, canvasSize.height/2);
    CGSize labelSize = [TL size];
    CGPoint downLeftPoint = CGPointMake(center.x - labelSize.width/2, center.y - labelSize.height/2);
    
    [TL setPosition:[_mapper convertToDataCoords:downLeftPoint]];
}


////////////////
#pragma mark -
#pragma mark Information about layout
////////////////
- (NSArray *)visibleAxisLabels;
{
    return _axisLabels;
}


////////////////
#pragma mark -
#pragma mark Path creation methods (Graph Element to BezierPath)
////////////////

- (void)invalidateCache;
{
    //DEBUG_RS(@"invalidating cache");
    [_pathCache removeAllObjects];
}

- (CGRect)rectFromBar:(RSVertex *)V width:(CGFloat)w;
{
    OBASSERT(w > 0);
    NSInteger shape = [V shape];
    CGPoint p = [_mapper convertToViewCoords:[V position]];
    CGRect r;
    
    if( shape == RS_BAR_VERTICAL ) {
	// scaling factor
	CGFloat b = w*RS_BAR_WIDTH_FACTOR;
	// find axis location
	CGPoint vo = [_mapper convertToViewCoords:[_mapper originPoint]];  // "view origin"
	// make a rectangle
	r.size.width = b*2;
	r.size.height = p.y - vo.y;
	r.origin.x = p.x - b;
	r.origin.y = vo.y;
        return r;
    }
    else if( shape == RS_BAR_HORIZONTAL ) {
	// scaling factor
	CGFloat b = w*RS_BAR_WIDTH_FACTOR;
	// find axis location
	CGPoint vo = [_mapper convertToViewCoords:[_mapper originPoint]];  // "view origin"
	// make a rectangle
	r.size.height = b*2;
	r.size.width = p.x - vo.x;
	r.origin.y = p.y - b;
	r.origin.x = vo.x;
        return r;
    }
    else {
        OBASSERT_NOT_REACHED("Vertex is not a bar.");
        return CGRectMake(0, 0, 10, 10);
    }
}

//- (NSBezierPath *)pathFromVertex:(RSVertex *)V;
//{
//    return [self pathFromVertex:V newWidth:0];
//}
//- (NSBezierPath *)pathFromVertex:(RSVertex *)V newWidth:(CGFloat)width;
//{
//    return [self pathFromVertex:V newWidth:width newShape:[V shape]];
//}
//- (NSBezierPath *)pathFromVertex:(RSVertex *)V newWidth:(CGFloat)width newShape:(NSInteger)shape;
//{
//    NSBezierPath *P = [NSBezierPath bezierPath];
//    [self _appendToPath:P shapeFromVertex:V newWidth:width newShape:shape];
//    return P;
//}
//- (void)_appendToPath:(NSBezierPath *)P shapeFromVertex:(RSVertex *)V newWidth:(CGFloat)width newShape:(NSInteger)shape;
//{
//    
////    [self appendToBezierPath:P vertexShape:shape width:width position:[_mapper convertToViewCoords:[V position]]];
////}
//
////- (void)appendToBezierPath:(NSBezierPath *)P vertexShape:(NSInteger)shape width:(CGFloat)width position:(CGPoint)p;
////{
//
////    // Return the cached version if possible
////    NSBezierPath *P = [_pathCache objectForKey:[V identifier]];
////    if (P) {
////        return P;
////    }
//    
//    CGRect r;
//    CGPoint p = [_mapper convertToViewCoords:[V position]];
//    //CGPoint s, t; // for creating the star, etc.
//    CGFloat b, c; // for creating the X, etc.
//    CGFloat w;
//    if ( width )
//	w = width;
//    else
//	w = [V width];
//    
//    if (shape <= RS_LAST_STANDARD_SHAPE) {
//        RSAppendShapeToBezierPath(P, p, shape, w);
//    }
//    else if ( shape == RS_TICKMARK ) {
//	b = 5*w; // the length of the tick mark
//	RSLine *L;
//	
//	// Find out how much the tick should be rotated, if snapped to something.  Default is rotated a bit to the left, like in the inspector button.
//	CGFloat rotation = 20;
//        
//	// snapped to an axis?
//	RSAxis *A = (RSAxis *)[[V snappedTo] firstElementWithClass:[RSAxis class]];
//	if( A ) {
//	    CGFloat length = w*2 + [A tickWidthOut] + [A tickWidthIn];
//	    
//	    if ( [A orientation] == RS_ORIENTATION_VERTICAL ) {
//		rotation = 90;
//		p.x += length/2 - [A tickWidthOut] - w;
//		b = length;
//	    }
//	    else if ( [A orientation] == RS_ORIENTATION_HORIZONTAL ) {
//                rotation = 0;
//		p.y += length/2 - [A tickWidthOut] - w;
//		b = length;
//	    }
//	}
//	// part of a line?
//	else if( (L = [RSGraph firstParentLineOf:V]) ) {
//	    CGFloat t = [[L paramForElement:V] floatValue];
//	    rotation = [_mapper degreesFromHorizontalOfLine:L atTime:t];
//	}
//	// snapped to a line?
//	else if( (L = (RSLine *)[[V snappedTo] firstElementWithClass:[RSLine class]]) ) {
//	    CGFloat t = [[V paramOfSnappedToElement:L] floatValue];
//	    rotation = [_mapper degreesFromHorizontalOfLine:L atTime:t];
//	}
//	// construct path
//        [P appendTickAtPoint:p width:w height:b];
//	// rotate if necessary
//	if( rotation ) {
//	    CGRect r = CGRectMake(0,0,b,b);
//	    r.origin = p;
//	    [P rotateInFrame:r byDegrees:rotation];
//	}
//	
//    }
//    else if ( shape == RS_ARROW ) {
//	
//	b = 3*w;//5*w/8; // the "big" dimension of the ^
//	c = 3*w;//5*w/8; // the "small" dimension of the ^
//
//        [P appendArrowheadAtPoint:p width:b height:c];
//	
//	// now, rotate the arrowhead if necessary
//	RSLine *arrowParent = [V arrowParent];
//	
//	//OBASSERT(!(arrowParent != nil && [arrowParent hasNoLength]));
//	if (arrowParent && ![arrowParent hasNoLength]) {
//	    // rotation will be based on the first line connected to the vertex
//	    r.size.width  = w;
//	    r.size.height = w;
//	    r.origin = p;
//	    
//	    CGFloat degrees = [_mapper degreesFromHorizontalOfAdjustedEnd:V onLine:arrowParent];
//
//	    [P rotateInFrame:r byDegrees:degrees];
//	}
//    }
//    // Bar chart shapes
//    else if( shape == RS_BAR_VERTICAL || shape == RS_BAR_HORIZONTAL ) {
//        r = [V rectFromBarUsingMapper:_mapper width:w];
//#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
//        [P appendPath:[UIBezierPath bezierPathWithRect:r]];
//#else
//        [P appendBezierPathWithRect:r];
//#endif
//    }
//    //
//    else { // if the end of an arrow, or something unspecified, make it round:
//	//NSLog(@"Shouldn't happen?");
//	r.origin.x = p.x - (w / 2);
//	r.origin.y = p.y - (w / 2);
//	r.size.width  = w;
//	r.size.height = w;
//#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
//        [P appendPath:[UIBezierPath bezierPathWithOvalInRect:r]];
//#else
//        [P appendBezierPathWithOvalInRect:r];
//#endif
//    }
//    
//    
////    [_pathCache setObject:P forKey:[V identifier]];
//}


- (NSBezierPath *)pathFromInteriorVertex:(RSVertex *)V newWidth:(CGFloat)width;
{
    CGPoint p = [_mapper convertToViewCoords:[V position]];
    // stroke a circle
    CGRect r = CGRectMake(p.x - width, p.y - width, width*2, width*2);
    NSBezierPath *P = [NSBezierPath bezierPathWithOvalInRect:r];
    
    return P;
}



- (NSBezierPath *)pathFromEquationLine:(RSEquationLine *)L;
{
    NSBezierPath *P = [NSBezierPath bezierPath];
    
//    CGFloat start = [_mapper viewMins].x;
//    CGFloat end = [_mapper viewMaxes].x;
    CGFloat start = CGRectGetMinX([_mapper bounds]);
    CGFloat end = CGRectGetMaxX([_mapper bounds]);
    CGFloat step = 1.0f;  // pixels
    
    BOOL firstPass = YES;
    for (CGFloat viewX = start; viewX <= end; viewX += step) {
        
        data_p dataX = [_mapper convertToDataCoords:viewX inDimension:RS_ORIENTATION_HORIZONTAL];
        data_p dataY = [L yValueForXValue:dataX];
        CGFloat viewY = [_mapper convertToViewCoords:dataY inDimension:RS_ORIENTATION_VERTICAL];
        
        CGPoint p = CGPointMake(viewX, viewY);
        
        if (firstPass) {
            [P moveToPoint:p];
            firstPass = NO;
        }
        else {
            [P lineToPoint:p];
        }
    }
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    [P setLineJoinStyle:kCGLineJoinRound];
#else
    [P setLineJoinStyle:NSRoundLineJoinStyle];
#endif
    
    return P;
}

- (NSBezierPath *)pathFromLine:(RSLine *)L;
{
    // Return the cached version if possible
    NSBezierPath *P = [_pathCache objectForKey:[L identifier]];
    if (P) {
        return P;
    }
    
    if ([L isKindOfClass:[RSEquationLine class]]) {
        P = [self pathFromEquationLine:(RSEquationLine *)L];
        
        [_pathCache setObject:P forKey:[L identifier]];
        return P;
    }
    
    P = [NSBezierPath bezierPath];
    
    NSArray *VArray = [[L vertices] elements];
    if( [VArray count] < 2 ) {
	OBASSERT_NOT_REACHED("Line has fewer than 2 vertices");
	return P;
    }
    
    CGFloat startT = 0;
    CGFloat endT = 1;
    RSVertex *startVertex = [VArray objectAtIndex:0];
    RSVertex *endVertex = [VArray lastObject];
    
    // Adjust for arrow ends
    if ([startVertex arrowParentIsLine:L]) {
	// adjust the line ending
	startT = [_mapper timeOfAdjustedEnd:startVertex onLine:L];
    }
    if ([endVertex arrowParentIsLine:L]) {
	endT = [_mapper timeOfAdjustedEnd:endVertex onLine:L];
    }

    
    //////
    // construct path:
    
    // if only 2 vertices, it's a straight line
    if( [VArray count] == 2 ) {
	[P moveToPoint:[_mapper locationOnCurve:L atTime:startT]];
	[P lineToPoint:[_mapper locationOnCurve:L atTime:endT]];
    }
    
    // otherwise, it's a ConnectLine
    else {
	OBASSERT([L isKindOfClass:[RSConnectLine class]]);
	
	// move to the first point
	[P moveToPoint:[_mapper locationOnCurve:L atTime:startT]];
	
	// if straight-line connections
	if( [(RSConnectLine *)L connectMethod] == RSConnectStraight ) {
	    for (NSUInteger i=1; i < [VArray count] - 1; i++) {
		RSVertex *V = [VArray objectAtIndex:i];
		[P lineToPoint:[_mapper convertToViewCoords:[V position]]];
	    }
	    // last point
	    [P lineToPoint:[_mapper locationOnCurve:L atTime:endT]];
            
            // In case of sharp angles, make the segment connections rounded.  <bug:///71015>
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
            [P setLineJoinStyle:kCGLineJoinRound];
#else
            [P setLineJoinStyle:NSRoundLineJoinStyle];
#endif
	}
	
	// if curved connections
	else if( [(RSConnectLine *)L connectMethod] == RSConnectCurved ) {
	    NSInteger n = [VArray count] - 1;
	    CGPoint segs[n + 1][3];
	    // compute the curve
	    [_mapper bezierSegmentsFromVertexArray:VArray putInto:segs];
	    
	    // first segment
	    int i = 0;
	    [_mapper curvePath:P alongConnectLine:(RSConnectLine *)L start:startT finish:[_mapper timeOfVertex:[VArray objectAtIndex:1] onLine:L]];
	    
	    for ( i=1; i < (n - 1); i++ ) {
		[P curveToPoint:segs[i+1][0] controlPoint1:segs[i][1] controlPoint2:segs[i][2]];
	    }
	    
	    // last point
	    //i = n - 1;
	    [_mapper curvePath:P alongConnectLine:(RSConnectLine *)L start:[_mapper timeOfVertex:[VArray objectAtIndex:([VArray count] - 2)] onLine:L] finish:endT];
	}
	
	// no connections?
	else {
            OBASSERT_NOT_REACHED("Unsupported connection type");
	    return nil;
	}
    }
    
    
    [_pathCache setObject:P forKey:[L identifier]];
    return P;
}

- (void)applyDashStyleForLine:(RSLine *)L toPath:(NSBezierPath *)P;
{
    NSInteger dash = [L dash];
    
    CGFloat style[] = {0,0,0,0};
    
    // set dash and endcap style
    if ( dash > 1 && dash < RS_ARROWS_DASH ) {
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
    
    // if not dashed, can use round endcaps
    else {
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        P.lineCapStyle = kCGLineCapRound;
#else
	[P setLineCapStyle:NSRoundLineCapStyle];  // new in OGS
#endif
    }
    
    // if dash is 7 or more, it's an entirely different construction,  handled in -drawLine: because it involves filling (not just stroking)
}



//- (NSBezierPath *)pathForCurvePointFromLine:(RSLine *)L {	
//    return [self pathForCurvePointFromLine:L width:[L width]];  // width of line
//}
//- (NSBezierPath *)pathForCurvePointFromLine:(RSLine *)L width:(CGFloat)w {
//    NSBezierPath *P;
//    CGPoint p0, p3, cp = [_mapper convertToViewCoords:[L curvePoint]];
//    //CGFloat m, m2;
//    CGPoint r, u, u2, u0, uw;
//    CGFloat rlen;
//    
//    CGFloat g = 0.618033; // golden ratio
//    CGFloat g1 = 1 - g;
//    
//    CGFloat _hitOffset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
//    CGFloat size = 5 + _hitOffset*g1;
//    
//    p0 = [_mapper convertToViewCoords:[L startPoint]];
//    p3 = [_mapper convertToViewCoords:[L endPoint]];
//    
//    /*
//     // calculate slope of line:
//     if ( p3.x - p0.x != 0 ) {
//     m = (p3.y - p0.y) / (p3.x - p0.x);
//     } else {
//     m = 1000;
//     }
//     if ( p3.y - p0.y != 0 ) {
//     m2 = (p0.x - p3.x) / (p3.y - p0.y);   // (perpendicular -1/m)
//     } else {
//     m2 = 1000;
//     }
//     */
//    
//    // or maybe we should do this with vectors?
//    // - convert line vector to unit length
//    // - find perpendicular unit vector
//    // - multiply by w and do the addition
//    r.x = p3.x - p0.x; // the vector along the line
//    r.y = p3.y - p0.y;
//    rlen = sqrt(r.x*r.x + r.y*r.y);  // length of r
//    u0.x = r.x/rlen; // unit vector
//    u0.y = r.y/rlen;
//    u.x = u0.x*size; // "scaled" unit vector
//    u.y = u0.y*size;
//    u2.x = -u.y; // perpendicular "scaled" unit vector
//    u2.y = u.x;
//    uw.x = -u0.y*w*0.5;  // perpendicular vector to get to edge of line
//    uw.y = u0.x*w*0.5;
//    
//    // now we can move with respect to these vectors
//    P = [NSBezierPath bezierPath];
//    [P moveToPoint:CGPointMake(cp.x + uw.x + u.x + u2.x, cp.y + uw.y + u.y + u2.y)];
//    //[P lineToPoint:CGPointMake(cp.x - u.x + u2.x, cp.y - u.y + u2.y)];
//    [P curveToPoint:CGPointMake(cp.x + uw.x - u.x + u2.x, cp.y + uw.y - u.y + u2.y)
//      controlPoint1:CGPointMake(cp.x + uw.x + u.x*g + u2.x*g1, cp.y + uw.y + u.y*g + u2.y*g1)
//      controlPoint2:CGPointMake(cp.x + uw.x - u.x*g + u2.x*g1, cp.y + uw.y - u.y*g + u2.y*g1)];
//    
//    [P moveToPoint:CGPointMake(cp.x - uw.x + u.x - u2.x, cp.y - uw.y + u.y - u2.y)];
//    [P curveToPoint:CGPointMake(cp.x - uw.x - u.x - u2.x, cp.y - uw.y - u.y - u2.y)
//      controlPoint1:CGPointMake(cp.x - uw.x + u.x*g - u2.x*g1, cp.y - uw.y + u.y*g - u2.y*g1)
//      controlPoint2:CGPointMake(cp.x - uw.x - u.x*g - u2.x*g1, cp.y - uw.y - u.y*g - u2.y*g1)];
//    
//    [P setLineCapStyle:NSRoundLineCapStyle];
//    return P;
//}
//- (NSBezierPath *)pathForCurvePointFromLine:(RSLine *)L atTime:(CGFloat)t width:(CGFloat)w {
//    // Initializations
//    NSBezierPath *P;
//    CGPoint r, u, u2, u0, uw;
//    CGFloat rlen;
//    
//    CGFloat g = 0.618033; // golden ratio
//    CGFloat g1 = 1 - g;
//    
//    CGFloat _hitOffset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
//    CGFloat size = 5 + _hitOffset*g1;
//    
//    // Get curve point location:
//    CGPoint cp = [_mapper locationOnCurve:L atTime:t];
//    
//    // Get vector perpendicular to the curve at the curve point:
//    CGFloat time = t;
//    CGFloat delta = 0.001;
//    if( time <= 0 )  time = delta;
//    if( time >= 1 )  time = 1 - delta;
//    CGPoint p0 = [_mapper locationOnCurve:L atTime:(time - delta)];
//    CGPoint p3 = [_mapper locationOnCurve:L atTime:(time + delta)];
//    
//    // Construct measurements using vector math:
//    // - convert line vector to unit length
//    // - find perpendicular unit vector
//    // - multiply by w and do the addition
//    r.x = p3.x - p0.x; // the vector along the line
//    r.y = p3.y - p0.y;
//    rlen = sqrt(r.x*r.x + r.y*r.y);  // length of r
//    u0.x = r.x/rlen; // unit vector
//    u0.y = r.y/rlen;
//    u.x = u0.x*size; // "scaled" unit vector
//    u.y = u0.y*size;
//    u2.x = -u.y; // perpendicular "scaled" unit vector
//    u2.y = u.x;
//    uw.x = -u0.y*w*0.5;  // perpendicular vector to get to edge of line
//    uw.y = u0.x*w*0.5;
//    
//    // now we can move with respect to these vectors
//    P = [NSBezierPath bezierPath];
//    [P moveToPoint:CGPointMake(cp.x + uw.x + u.x + u2.x, cp.y + uw.y + u.y + u2.y)];
//    //[P lineToPoint:CGPointMake(cp.x - u.x + u2.x, cp.y - u.y + u2.y)];
//    [P curveToPoint:CGPointMake(cp.x + uw.x - u.x + u2.x, cp.y + uw.y - u.y + u2.y)
//      controlPoint1:CGPointMake(cp.x + uw.x + u.x*g + u2.x*g1, cp.y + uw.y + u.y*g + u2.y*g1)
//      controlPoint2:CGPointMake(cp.x + uw.x - u.x*g + u2.x*g1, cp.y + uw.y - u.y*g + u2.y*g1)];
//    
//    [P moveToPoint:CGPointMake(cp.x - uw.x + u.x - u2.x, cp.y - uw.y + u.y - u2.y)];
//    [P curveToPoint:CGPointMake(cp.x - uw.x - u.x - u2.x, cp.y - uw.y - u.y - u2.y)
//      controlPoint1:CGPointMake(cp.x - uw.x + u.x*g - u2.x*g1, cp.y - uw.y + u.y*g - u2.y*g1)
//      controlPoint2:CGPointMake(cp.x - uw.x - u.x*g - u2.x*g1, cp.y - uw.y - u.y*g - u2.y*g1)];
//    
//    [P setLineCapStyle:NSRoundLineCapStyle];
//    return P;
//}


- (RSGroup *)actuallySnappedToBoth:(RSVertex *)V1 and:(RSVertex *)V2;
// When there is an intersection constraint on a vertex, manipulation of the intersecting lines can cause the point to not actually be near the intersection.  In these cases, the fill should not actually curve along the line (otherwise strange things happen).
{
    CGFloat maxApproxDistance = 4;  // This is the distance that was experimentally determined to usually be greater than the distance between an intersection-constrained point and its t-value location on each individual line.  When this is not the case, we assume that the intersection has been broken (for example, the lines no longer cross).
    
    RSGroup *shared = [V1 snappedToThisAnd:V2];
    
    for (RSLine *GE in [[shared elements] reverseObjectEnumerator]) {
	if (![GE isKindOfClass:[RSLine class]])
	    continue;
	
	CGFloat d1 = distanceBetweenPoints([_mapper convertToViewCoords:[V1 position]],
                                           [_mapper locationOnCurve:GE atTime:[[V1 paramOfSnappedToElement:GE] floatValue]]);
	if ( d1 > maxApproxDistance ) {
//#ifdef DEBUG
//	    //[RSGraphRenderer drawCircleAt:[_mapper locationOnCurve:GE atTime:[[V1 paramOfSnappedToElement:GE] floatValue]]];
//	    [RSGraphRenderer drawCircleAt:[_mapper convertToViewCoords:[V1 position]]];
//#endif
	    [shared removeElement:GE];
	}
	else {
	    CGFloat d2 = distanceBetweenPoints([_mapper convertToViewCoords:[V2 position]],
                                               [_mapper locationOnCurve:GE atTime:[[V2 paramOfSnappedToElement:GE] floatValue]]);
	    if ( d2 > maxApproxDistance ) {
		[shared removeElement:GE];
	    }
	}
    }
    
    return shared;
}

- (NSBezierPath *)pathFromFill:(RSFill *)F;
{
    return [self pathFromFill:F closed:YES];
}

- (NSBezierPath *)pathFromFill:(RSFill *)F closed:(BOOL)closed;
{
    // Return the cached version if possible
    NSBezierPath *P = [_pathCache objectForKey:[F identifier]];
    if (P) {
        return P;
    }
    
    RSVertex *V;
    RSVertex *prev;
    RSVertex *prevprev;
    RSVertex *first;
    RSLine *L;
    RSGroup *shared;
    
    // construct path
    P = [NSBezierPath bezierPath];
    //
    NSArray *A = [[F vertices] elements];
    NSEnumerator *E = [A objectEnumerator];
    first = prevprev = prev = V = [E nextObject];
    [P moveToPoint:[_mapper convertToViewCoords:[V position]]];
    while ((V = [E nextObject])) {
	shared = [self actuallySnappedToBoth:V and:prev];//[V snappedToThisAnd:prev];
	L = (RSLine *)[shared firstElementWithClass:[RSLine class]];
	// if both vertices are snapped to a line, curve the fill edge along that line
	if (L && [L isCurved]) {
	    CGFloat t1 = [(NSNumber *)[prev paramOfSnappedToElement:L] floatValue];
	    CGFloat t2 = [(NSNumber *)[V paramOfSnappedToElement:L] floatValue];
	    [_mapper curvePath:P alongConnectLine:(RSConnectLine *)L start:t1 finish:t2];
	}
	else { // L doesn't exist or is straight
	    [P lineToPoint:[_mapper convertToViewCoords:[V position]]];
	}
	prevprev = prev;
	prev = V;
    }
    
    
    if (closed) {
        // Finish by making the last-to-first connection as follows:
        // If the second-to-last vertex, last vertex, and first vertex are all on the same curved line, then draw a straight connection (because the fill already had a chance to curve along the portion of the line between these vertices).  Otherwise, curve the fill along the line as usual.
        NSArray *threeShared = [RSVertex elementsTheseVerticesAreSnappedTo:[NSArray arrayWithObjects:prev, prevprev, first, nil]];
        RSLine *threeLine = (RSLine *)[threeShared firstObjectWithClass:[RSLine class]];
        V = first;
        shared = [self actuallySnappedToBoth:V and:prev];//[V snappedToThisAnd:prev];
        L = (RSLine *)[shared firstElementWithClass:[RSLine class]];
        if( (L && [L isCurved]) && !threeLine ) {
            CGFloat t1 = [(NSNumber *)[prev paramOfSnappedToElement:L] floatValue];
            CGFloat t2 = [(NSNumber *)[V paramOfSnappedToElement:L] floatValue];
            [_mapper curvePath:P alongConnectLine:(RSConnectLine *)L start:t1 finish:t2];
        }
        else { // make a straight connection
            [P lineToPoint:[_mapper convertToViewCoords:[V position]]];
        }
        
        // end
        [P closePath];
    }
    
    [_pathCache setObject:P forKey:[F identifier]];
    return P;
}



- (NSBezierPath *)pathFromAxis:(RSAxis *)A width:(CGFloat)width;
{
    return [self pathFromAxis:A width:width disableTicks:NO];
}

- (NSBezierPath *)pathFromAxis:(RSAxis *)A width:(CGFloat)width disableTicks:(BOOL)disableTicks;
{
    NSBezierPath *path = [self pathFromAxis:A width:width startPoint:[_mapper viewOriginPoint] disableTicks:disableTicks bezierPath:nil];
    
    if ([A placement] == RSBothEdgesPlacement) {
	path = [self pathFromAxis:A width:width startPoint:[_mapper viewMaxes] disableTicks:disableTicks bezierPath:path];
    }
    
    return path;
}

static void appendTick(NSBezierPath *path, int axisOrientation, CGFloat p, CGFloat line, CGFloat inner, CGFloat outer, BOOL isMinor) {
    CGPoint t, b;
    
    if (isMinor) {
        inner *= RS_MINOR_TICK_LENGTH_MULTIPLIER;
        outer *= RS_MINOR_TICK_LENGTH_MULTIPLIER;
    }
    
    if (axisOrientation == RS_ORIENTATION_HORIZONTAL) {
        t.x = b.x = p;
        t.y = line + inner;
        b.y = line - outer;
    }
    else {  // RS_ORIENTATION_VERTICAL
        t.y = b.y = p;
        t.x = line + inner;
        b.x = line - outer;
    }
    
    [path moveToPoint:t];
    [path lineToPoint:b];
}

- (BOOL)_appendTicks:(NSArray *)tickArray toPath:(NSBezierPath *)path forAxis:(RSAxis *)A width:(CGFloat)width startPoint:(CGPoint)startp;
{
    int axisOrientation = [A orientation];
    
    BOOL useDataExtent = ([A extent] == RSAxisExtentDataRange || [A extent] == RSAxisExtentDataQuartiles);
    data_p dataMin = 0, dataMax = 0;
    if (useDataExtent) {
        RSSummaryStatistics stats = [RSGraph summaryStatisticsOfGroup:[_graph dataVertices] inOrientation:axisOrientation];
        dataMin = stats.min;
        dataMax = stats.max;
        if (nearlyEqualDataValues(dataMin, dataMax)) {
            useDataExtent = NO;
        }
    }
    
    NSUInteger count = 0;
    CGFloat p;
    
    CGFloat line = dimensionOfPointInOrientation(startp, [[_graph otherAxis:A] orientation]);
        
    // move perpendicularly to nearest pixel, to avoid antialiasing
    if (width <= AXIS_LINE_HINTING_WIDTH_CUTOFF) {
        line = nearestPixelIfEnabled(line);
    }
    
    // set up length of ticks:
    CGFloat inner = width + [A tickWidthIn];
    CGFloat outer = width + [A tickWidthOut];
    
    // draw the axis min tick
    if ([A shouldDrawMinTick]) {
        p = nearestPixelIfEnabled(dimensionOfPointInOrientation([_mapper viewMins], axisOrientation));
        appendTick(path, axisOrientation, p, line, inner, outer, NO);
        
        count += 1;
    }
    
    // draw the other ticks specified
    for (NSNumber *number in tickArray) {
        data_p tickValue = [number doubleValue];
        
        if (useDataExtent && (tickValue < dataMin || tickValue > dataMax)) {
            continue;
        }
        
        p = nearestPixelIfEnabled([_mapper convertToViewCoords:tickValue inDimension:axisOrientation]);
        BOOL isMinor = [A tickIsMinor:tickValue];
        
        appendTick(path, axisOrientation, p, line, inner, outer, isMinor);
        
        count += 1;
    }
    
    // draw the axis max tick
    if ([A shouldDrawMaxTick]) {
        p = nearestPixelIfEnabled(dimensionOfPointInOrientation([_mapper viewMaxes], axisOrientation));
        appendTick(path, axisOrientation, p, line, inner, outer, NO);
        
        count += 1;
    }
    
    //DEBUG_RS(@"appended %d ticks in orientation %d", count, [A orientation]);
    
    return (count > 0);
}

- (NSBezierPath *)pathFromAxis:(RSAxis *)A width:(CGFloat)width startPoint:(CGPoint)startp disableTicks:(BOOL)disableTicks  bezierPath:(NSBezierPath *)path;
// p is in view coords
{
    if (!path)
	path = [NSBezierPath bezierPath]; // new empty path
    [path setLineWidth:width];
    
    CGPoint p = startp;
    
    CGPoint viewMins = [_mapper viewMins];
    CGPoint viewMaxes = [_mapper viewMaxes];
    
    CGFloat adj = 0.45f;  // 0.5 sometimes anti-aliases too far
    
    ////////////////
    // HORIZONTAL
    ////////////////
    if ([A orientation] == RS_ORIENTATION_HORIZONTAL) {
	
        // draw main line
	if( [A displayAxis] ) {
            // move perpendicularly to nearest pixel, to avoid antialiasing
            if (width <= AXIS_LINE_HINTING_WIDTH_CUTOFF) {
                p.y = nearestPixelIfEnabled(p.y);
            }
            
            if ([A extent] == RSAxisExtentDataQuartiles) {
                RSGroup *dataVertices = [_graph dataVertices];
                if ([dataVertices count] > 2) {
                    RSSummaryStatistics stats = [RSGraph summaryStatisticsOfGroup:dataVertices inOrientation:[A orientation]];
                    CGFloat viewMin = [_mapper convertToViewCoords:RSDataPointMake(stats.min, 0)].x;
                    CGFloat viewFirstQuartile = [_mapper convertToViewCoords:RSDataPointMake(stats.firstQuartile, 0)].x;
                    CGFloat viewMedian = [_mapper convertToViewCoords:RSDataPointMake(stats.median, 0)].x;
                    CGFloat viewThirdQuartile = [_mapper convertToViewCoords:RSDataPointMake(stats.thirdQuartile, 0)].x;
                    CGFloat viewMax = [_mapper convertToViewCoords:RSDataPointMake(stats.max, 0)].x;
                    
                    CGFloat medianGapWidth = 1.0f;
                    
                    p.x = viewMin - width*adj;
                    [path moveToPoint:p];
                    p.x = viewFirstQuartile;
                    [path lineToPoint:p];
                    
                    // offset quartiles
                    p.y += width;
                    [path moveToPoint:p];
                    p.x = viewMedian - medianGapWidth;
                    [path lineToPoint:p];
                    p.x = viewMedian + medianGapWidth;
                    [path moveToPoint:p];
                    p.x = viewThirdQuartile;
                    [path lineToPoint:p];
                    
                    p.y -= width;
                    [path moveToPoint:p];
                    p.x = viewMax + width*adj;
                    [path lineToPoint:p];
                    
                }
            }
            else {
                if ([A extent] == RSAxisExtentDataRange) {
                    RSGroup *dataVertices = [_graph dataVertices];
                    if ([dataVertices count] > 1) {
                        viewMins.x = [_mapper convertToViewCoords:[dataVertices position]].x;
                        viewMaxes.x = [_mapper convertToViewCoords:[dataVertices positionUR]].x;
                    }
                }
                
                p.x = viewMins.x - width*adj;  // 0.5 sometimes anti-aliases too far
                [path moveToPoint:p];
                p.x = viewMaxes.x + width*adj;
                [path lineToPoint:p];
            }
	}
    }
    
    ////////////////
    // VERTICAL
    ////////////////
    else if ([A orientation] == RS_ORIENTATION_VERTICAL) {
        
	// draw main line:
	if( [A displayAxis] ) {
            // move perpendicularly to nearest pixel, to avoid antialiasing
            if (width <= AXIS_LINE_HINTING_WIDTH_CUTOFF) {
                p.x = nearestPixelIfEnabled(p.x);
            }
            
            if ([A extent] == RSAxisExtentDataQuartiles) {
                RSGroup *dataVertices = [_graph dataVertices];
                if ([dataVertices count] > 2) {
                    RSSummaryStatistics stats = [RSGraph summaryStatisticsOfGroup:dataVertices inOrientation:[A orientation]];
                    CGFloat viewMin = [_mapper convertToViewCoords:RSDataPointMake(0, stats.min)].y;
                    CGFloat viewFirstQuartile = [_mapper convertToViewCoords:RSDataPointMake(0, stats.firstQuartile)].y;
                    CGFloat viewMedian = [_mapper convertToViewCoords:RSDataPointMake(0, stats.median)].y;
                    CGFloat viewThirdQuartile = [_mapper convertToViewCoords:RSDataPointMake(0, stats.thirdQuartile)].y;
                    CGFloat viewMax = [_mapper convertToViewCoords:RSDataPointMake(0, stats.max)].y;
                    
                    CGFloat medianGapWidth = 1.0f;
                    
                    p.y = viewMin - width*adj;
                    [path moveToPoint:p];
                    p.y = viewFirstQuartile;
                    [path lineToPoint:p];
                    
                    // offset quartiles
                    p.x += width;
                    [path moveToPoint:p];
                    p.y = viewMedian - medianGapWidth;
                    [path lineToPoint:p];
                    p.y = viewMedian + medianGapWidth;
                    [path moveToPoint:p];
                    p.y = viewThirdQuartile;
                    [path lineToPoint:p];
                    
                    p.x -= width;
                    [path moveToPoint:p];
                    p.y = viewMax + width*adj;
                    [path lineToPoint:p];
                    
                }
            }
            else {
                if ([A extent] == RSAxisExtentDataRange) {
                    RSGroup *dataVertices = [_graph dataVertices];
                    if ([dataVertices count] > 1) {
                        viewMins.y = [_mapper convertToViewCoords:[dataVertices position]].y;
                        viewMaxes.y = [_mapper convertToViewCoords:[dataVertices positionUR]].y;
                    }
                }
                
                p.y = viewMins.y - width*adj;
                [path moveToPoint:p];
                p.y = viewMaxes.y + width*adj;
                [path lineToPoint:p];
            }
	}
    }
    
    
    // If not drawing ticks, stop here
    if( disableTicks || ![A displayTicks] ) {
        return path;
    }
    
    // Add tick marks to the path
    NSArray *tickArray;
    if (A.tickLayout == RSAxisTickLayoutAtData) {
        tickArray = [A dataTicks];
    } else {
        tickArray = [A allTicks];
    }
    [self _appendTicks:tickArray toPath:path forAxis:A width:width startPoint:startp];
    
    return path;
}


- (NSBezierPath *)pathFromGrid:(RSGrid *)grid width:(CGFloat)width
{
    NSBezierPath *path = [NSBezierPath bezierPath]; // new empty path
    
    CGPoint viewMins, viewMaxes;
    RSDataPoint dataMins, dataMaxes;
    
    if ( [_graph noAxisComponentsAreDisplayed] ) {
        // extend lines all the way to edge of screen
        viewMins = CGPointMake(0, 0);
        CGRect bounds = [_mapper bounds];
        viewMaxes = CGPointMake(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
        dataMins = [_mapper convertToDataCoords:viewMins];
        dataMaxes = [_mapper convertToDataCoords:viewMaxes];
    }
    else {
        // Normally, grid lines are bounded by the axis rect
        viewMins = [_mapper viewMins];
        viewMaxes = [_mapper viewMaxes];
        dataMins = RSDataPointMake([_graph xMin], [_graph yMin]);
        dataMaxes = RSDataPointMake([_graph xMax], [_graph yMax]);
    }
    
    CGPoint p, t, b; // current working points
    NSUInteger count = 0;
    
    // Adjust for the width of the grid lines
    CGFloat adj = width/2.0f;
    
    
    if ([grid orientation] == RS_ORIENTATION_VERTICAL) {  // xGrid
        
        RSAxis *A = [_graph xAxis];
        
        // set up length of grid lines:
        t.y = viewMaxes.y + adj;
        b.y = viewMins.y - adj;
        
        // Get tick locations
        NSMutableArray *tickArray = nil;
        if ([A axisType] == RSAxisTypeLogarithmic) {
            data_p spacingMagnitude = 0;
            if ([A ordersOfMagnitude] > RSLogarithmicMinorGridLinesMaxMagnitude) {
                spacingMagnitude = 1;
            }
            tickArray = [A logarithmicTicksWithRegimeBoundarySpacing:spacingMagnitude min:dataMins.x max:dataMaxes.x];
        }
        else {  // Linear
            tickArray = [A linearTicksWithSpacing:[A spacing] min:dataMins.x max:dataMaxes.x];
        }
        
        if (![_graph noAxisComponentsAreDisplayed]) {
            [tickArray addObject:[NSNumber numberWithDouble:[_graph xMin]]];
            [tickArray addObject:[NSNumber numberWithDouble:[_graph xMax]]];
        }
        
        // Draw the grid lines
        for (NSNumber *number in tickArray) {
            RSDataPoint tickPoint = RSDataPointMake([number doubleValue], 0);
            
            p.x = [_mapper convertToViewCoords:tickPoint].x;
            b.x = t.x = nearestPixelIfEnabled(p.x);
            [path moveToPoint:t];
            [path lineToPoint:b];
            
            count += 1;
        }
        
        //DEBUG_RS(@"appended %d grid lines in orientation %d", count, [A orientation]);
    }
    
    else if ([grid orientation] == RS_ORIENTATION_HORIZONTAL) {  // yGrid
        
        RSAxis *A = [_graph yAxis];
        
        // set up length of grid lines:
        t.x = viewMaxes.x + adj;
        b.x = viewMins.x - adj;
        
        // Get tick locations
        NSMutableArray *tickArray = nil;
        if ([A axisType] == RSAxisTypeLogarithmic) {
            data_p spacingMagnitude = 0;
            if ([A ordersOfMagnitude] > RSLogarithmicMinorGridLinesMaxMagnitude) {
                spacingMagnitude = 1;
            }
            tickArray = [A logarithmicTicksWithRegimeBoundarySpacing:spacingMagnitude min:dataMins.y max:dataMaxes.y];
        }
        else {  // Linear
            tickArray = [A linearTicksWithSpacing:[A spacing] min:dataMins.y max:dataMaxes.y];
        }
        
        if (![_graph noAxisComponentsAreDisplayed]) {
            [tickArray addObject:[NSNumber numberWithDouble:[_graph yMin]]];
            [tickArray addObject:[NSNumber numberWithDouble:[_graph yMax]]];
        }
        
        // Draw the grid lines
        for (NSNumber *number in tickArray) {
            RSDataPoint tickPoint = RSDataPointMake(0, [number doubleValue]);
            
            p.y = [_mapper convertToViewCoords:tickPoint].y;
            b.y = t.y = nearestPixelIfEnabled(p.y);
            [path moveToPoint:t];
            [path lineToPoint:b];
            
            count += 1;
        }
    }
    
    [path setLineWidth:width];
    
    if (grid.dotted) {
        CGFloat style[] = {0.5f, 2.5f};
        [path setLineDash:style count:2 phase:0.0f];
    }
    
    return path;
}



/////////////////
#pragma mark -
#pragma mark Drawing methods
/////////////////

//- (void)drawVertex:(RSVertex *)V
//{
//    NSBezierPath *P;
//    
//    if ([V width] <= 0)
//	return;
//    
//    if ([V shape] == RS_NONE)
//        return;
//    
//    if( [V shape] == RS_HOLLOW ) {
//	// clear what's behind it
//	P = [self pathFromVertex:V newWidth:(CGFloat)([V width]*0.8 - 0.4) newShape:RS_CIRCLE];
//	[[_graph backgroundColor] set];
//	[P fill];
//	// draw the hollow point
//	P = [self pathFromVertex:V];
//	[[V color] set];
//	[P fill];
//    }
//    else if( [V isBar] ) {
//	P = [self pathFromVertex:V];
//	[[V color] set];
//	[P fill];
//    }
//    else {
//	P = [self pathFromVertex:V];
//	[[V color] set];
//	[P fill];
//    }
//}

- (void)drawLine:(RSLine *)L {
    
    // if the line does not have more than one point, draw it with a point shape
    if ([L isTooSmall] || [L hasNoLength]) {
	//OBASSERT_NOT_REACHED("I don't think we allow lines with fewer than 2 vertices.");
	RSVertex *V = [L startVertex];
	//int shape = [V shape];
	//[V setShape:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultVertexShape"]];
	[V drawUsingMapper:_mapper];
	//[V setShape:shape];
	return;
	// if there are no vertices at all, don't do anything
    }
    else if( [L vertexCount] < 1 ) {
	return;
    }
    
    NSBezierPath *P = [self pathFromLine:L];
    [self applyDashStyleForLine:L toPath:P];
    CGFloat w = [L width];
    [P setLineWidth:w];
    [[L color] set];
    
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    CGRect allScreens = CGRectZero;
    NSArray *screens = [NSScreen screens];
    
    for(NSScreen *currScreen in screens){
        allScreens = CGRectUnion(allScreens, currScreen.frame);
    }

    if(!CGRectContainsRect(allScreens, P.bounds))
    {
        return;
    }
#endif
    
    [P stroke];
    
    // make rounded edges
    if ([L dash] > 1) {
        if ([[L startVertex] shape] == RS_NONE) {
            CGPoint p = [_mapper convertToViewCoords:[L startPoint]];
            CGRect r = CGRectMake(p.x - w*0.5f, p.y - w*0.5f, w, w);
            P = [NSBezierPath bezierPathWithOvalInRect:r];
            [P fill];
        }
        
        if ([[L endVertex] shape] == RS_NONE) {
            CGPoint p = [_mapper convertToViewCoords:[L endPoint]];
            CGRect r = CGRectMake(p.x - w*0.5f, p.y - w*0.5f, w, w);
            P = [NSBezierPath bezierPathWithOvalInRect:r];
            [P fill];
        }
    }
    
    //
    // Special dash styles
    //
    // make mini arrows along the line's length
    if( [L dash] == RS_ARROWS_DASH ) {  
	CGFloat t = 0;
	CGFloat w = [L width];
	CGFloat b = w*3;
	CGRect r = CGRectMake(0,0,b,b);
	CGFloat rotation;
	//CGPoint p;
	CGFloat spacing = w*12;  // space between arrows
        
	// draw arrow heads
        NSUInteger maxIters = 500;
        NSUInteger iters = 0;
	while( t < 1 && iters < maxIters ) {
            iters++;
            
	    // first, find the next t-value
	    t = [_mapper timeOnLine:L viewDistance:spacing fromTime:t direction:RS_FORWARD];
	    
	    // only draw it if it doesn't go past the end of the line
	    if( t >= 1 /*|| [self viewLengthOfLineSegment:L fromTime:t toTime:1] < b*/ )
		break;
	    // otherwise construct an arrowhead at that t-value
	    P = [[NSBezierPath bezierPath] appendArrowheadAtPoint:[_mapper locationOnCurve:L atTime:t] 
					 width:b height:b];
	    r.origin = [_mapper locationOnCurve:L atTime:t];
	    //if( [L dash] == RS_ARROWS_DASH ) {
	    rotation = 180 + [_mapper degreesFromHorizontalOfLine:L atTime:t];
	    //}
	    //else if( [L dash] == RS_REVERSE_ARROWS_DASH ) {
	    //	rotation = [_mapper degreesFromHorizontalOfLine:L atTime:t];
	    //}
	    [P rotateInFrame:r byDegrees:rotation];
	    // draw the arrowhead
	    [P fill];
	}
    }
    // reverse direction
    else if( [L dash] == RS_REVERSE_ARROWS_DASH ) {  
	CGFloat t = 1;
	CGFloat w = [L width];
	CGFloat b = w*3;
	CGRect r = CGRectMake(0,0,b,b);
	CGFloat rotation;
	//CGPoint p;
	CGFloat spacing = w*12;  // space between arrows
        
	// draw arrow heads
        NSUInteger maxIters = 500;
        NSUInteger iters = 0;
	while( t > 0 && iters < maxIters ) {
            iters++;
            
	    // first, find the next t-value
	    t = [_mapper timeOnLine:L viewDistance:spacing fromTime:t direction:RS_BACKWARD];
	    
	    // only draw it if it doesn't go past the end of the line
	    if( t <= 0 /*|| [self viewLengthOfLineSegment:L fromTime:t toTime:1] < b*/ )
		break;
	    // otherwise construct an arrowhead at that t-value
	    P = [[NSBezierPath bezierPath] appendArrowheadAtPoint:[_mapper locationOnCurve:L atTime:t] 
					 width:b height:b];
	    r.origin = [_mapper locationOnCurve:L atTime:t];
	    rotation = [_mapper degreesFromHorizontalOfLine:L atTime:t];
	    [P rotateInFrame:r byDegrees:rotation];
	    // draw the arrowhead
	    [P fill];
	}
    }
    //////
    // tick marks along the line
    //
    else if( [L dash] == RS_RAILROAD_DASH ) {  
	CGFloat t = 0;
	CGFloat w = [L width];
	CGFloat b = w*4;
	CGRect r = CGRectMake(0,0,b,b);
	CGFloat rotation;
	CGFloat spacing = 12 + w*4;  // space between tick marks
        
        NSUInteger maxIters = 500;
        NSUInteger iters = 0;
	// draw tick marks
	while( t < 1 && iters < maxIters ) {
            iters++;
            
	    // first, find the next t-value
	    t = [_mapper timeOnLine:L viewDistance:spacing fromTime:t direction:RS_FORWARD];
	    
	    // only draw it if it doesn't go past the end of the line
	    if( t >= 1 )
		break;
	    // otherwise construct a tick mark at that t-value
	    P = [[NSBezierPath bezierPath] appendTickAtPoint:[_mapper locationOnCurve:L atTime:t] 
				    width:w height:b];
	    
	    r.origin = [_mapper locationOnCurve:L atTime:t];
	    rotation = [_mapper degreesFromHorizontalOfLine:L atTime:t];
	    [P rotateInFrame:r byDegrees:rotation];
	    
	    [P fill];
	}
    }
}



- (void)drawFill:(RSFill *)F;
{
    [self drawFill:F inProgress:NO];
}

- (void)drawFill:(RSFill *)F inProgress:(BOOL)inProgress;
{
    NSBezierPath *P;
    NSArray *A;
    CGFloat width;
    RSVertex *V1;
    RSVertex *V2;
    
    // just to be safe,
    if ( !F )  return;
    
    // first, check to see that snappedTos are correct
    //now done in [RSGraphView recomputeGroupIfNecessary]//[self updateSnappedTosForFill:F];
    
    if ( [F isVertex] ) {	// only contains one vertex
	// draw as an oversized vertex
	// actually, don't - UI consultant thought it was confusing
	// actually, do - it helps with snapping feedback.  but make the size meaningful
	CGFloat snapWidth = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"] * 2;
	
	RSVertex *V = [F firstVertex];
	width = [V width];
	BOOL hasShape = [RSGraph vertexHasShape:V];
	if (hasShape) {
	    width *= 4;
	}
	width *= 1.4f;
	width += 10;
	    
	if (width < snapWidth)
	    width = snapWidth;
	if (hasShape)
	    width /= 4;
	
	P = [[F firstVertex] pathUsingMapper:_mapper newWidth:width];
	[[F color] set];
	[P fill];
    }
    else if ( [F isTwoVertices] ) {	// only contains two vertices
	// draw as an oversized line
	// get the vertices
	A = [[F vertices] elements];
	V1 = [A objectAtIndex:0];
	V2 = [A objectAtIndex:1];
	// make a new empty path
	P = [NSBezierPath bezierPath];
	// construct path
	[P moveToPoint:[_mapper convertToViewCoords:[V1 position]]];
	// maybe curve it
	RSGroup *shared = [self actuallySnappedToBoth:V2 and:V1];//[V2 snappedToThisAnd:V1];
	RSLine *L = (RSLine *)[shared firstElementWithClass:[RSLine class]];
	if( L && [L isCurved] ) {
	    CGFloat t1 = [(NSNumber *)[V1 paramOfSnappedToElement:L] floatValue];
	    CGFloat t2 = [(NSNumber *)[V2 paramOfSnappedToElement:L] floatValue];
	    [_mapper curvePath:P alongConnectLine:(RSConnectLine *)L start:t1 finish:t2];
	}
	else {  // nothing shared, or it's a straight line
	    [P lineToPoint:[_mapper convertToViewCoords:[V2 position]]];
	}
	
	// apply formatting
	width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"] * 2;
	//width = ([V1 width] + [V2 width])/2.0 + 5.0;
	//if( ![V1 shape] )  width *= 2;
	//if( ![V2 shape] )  width *= 2;
	[P setLineWidth:width];
	[[F color] set];
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        [P setLineCapStyle:kCGLineCapRound];
#else
	[P setLineCapStyle:NSRoundLineCapStyle];
#endif
	[P stroke];
    }
    
    // more than two vertices
    else {
	[[F color] set];
        
        CGFloat area = 0;
        if (inProgress) {
            area = [_mapper viewAreaOfFill:F];
        }
        if ([F shouldBeDrawnAsLine] || (inProgress && area < 200)) {
            // Draw as line
            P = [self pathFromFill:F closed:NO];
            [P setLineWidth:[[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"] * 2];
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
            [P setLineCapStyle:kCGLineCapRound];
#else
            [P setLineCapStyle:NSRoundLineCapStyle];
#endif
            [P stroke];
        } else {
            // Otherwise, draw normally (as a filled-in area)
            P = [self pathFromFill:F];
            [P fill];
        }

	
    }
}



- (void)drawLabel:(RSTextLabel *)TL;
{
    if ([TL length] == 0)
        return;
    
    CGPoint p = [_mapper convertToViewCoords:[TL position]];
    //NSLog(@"mapped label position from %@ to %@ for '%@'", NSStringFromPoint([T position]), NSStringFromPoint(p), T.text);
    CGFloat degrees = [TL rotation];
    
    [TL drawAtPoint:p baselineRotatedByDegrees:degrees];
}


- (void)drawGridPoint:(RSDataPoint)gridPoint;
{
    // gridPoint is in user coords
    RSVertex *V;
    NSBezierPath *P;
    CGPoint min, max, p;
    
    // original behavior is to draw a light-colored version of where the point will be drawn:
    OQColor *color = [OQColor colorForPreferenceKey:@"DefaultLineColor"];
    CGFloat width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"];
    V = [[RSVertex alloc] initWithGraph:_graph identifier:nil point:gridPoint width:width color:color shape:0];
    //use current default//[V setWidth:(_hitOffset*2)];
    
    P = [V pathUsingMapper:_mapper];
    OQColor *backgroundColor = [[_graph backgroundColor] colorUsingColorSpace:OQColorSpaceRGB];
    if ( [backgroundColor brightnessComponent] < 0.5 )
	[[backgroundColor blendedColorWithFraction:0.2f ofColor:[OQColor whiteColor]] set];
    else
	[[backgroundColor blendedColorWithFraction:0.2f ofColor:[OQColor blackColor]] set];
    [P fill];
    [V release];
    
    
    // new behavior highlights the grid lines (guide lines) around the point:
    min = [_mapper viewMins];
    max = [_mapper viewMaxes];
    p = [_mapper convertToViewCoords:gridPoint];
    
    P = [NSBezierPath bezierPath];
    // vertical line
    if( [_mapper isGridLine:gridPoint.x onAxis:[_graph xAxis]] ) {
	[P moveToPoint:CGPointMake(p.x, min.y)];
	[P lineToPoint:CGPointMake(p.x, max.y)];
    }
    // horizontal line
    if( [_mapper isGridLine:gridPoint.y onAxis:[_graph yAxis]] ) {
	[P moveToPoint:CGPointMake(min.x, p.y)];
	[P lineToPoint:CGPointMake(max.x, p.y)];
    }
    [P setLineWidth:1];
    // if grids are turned on, use grid line color as the base color
    //if ( [[_graph gridColor] brightnessComponent] < 0.5 )
    //	[[[_graph gridColor] blendedColorWithFraction:0.2 ofColor:[OQColor whiteColor]] set];
    //else
    //	[[[_graph gridColor] blendedColorWithFraction:0.2 ofColor:[OQColor blackColor]] set];
    // or just use a standard color
    [[[OQColor blueColor] colorWithAlphaComponent:0.38f] set];
    [P stroke];
}





- (void)drawGrid;
{
    NSBezierPath *P;
    if ( [[_graph xGrid] displayGrid] ) {
	P = [self pathFromGrid:[_graph xGrid] width:[[_graph xGrid] width]];
	[[_graph gridColor] set];
	[P stroke];
    }
    if ( [[_graph yGrid] displayGrid] ) {
	P = [self pathFromGrid:[_graph yGrid] width:[[_graph yGrid] width]];
	[[_graph gridColor] set];
	[P stroke];
    }
}


- (void)drawAxis:(RSAxis *)A {
    
    if( ![A displayAxis] )
	return;
    
    NSBezierPath *P = [self pathFromAxis:A width:[A width]];
    [[A color] set];
    [P stroke];
    
    //
    // Arrow shape extras:
    //
    
    NSInteger shape;
    CGPoint p;
    CGFloat w, b, c;
    CGRect r;
    
    shape = [A shape];
    if ( shape == RS_LEFT_ARROW || shape == RS_RIGHT_ARROW || shape == RS_BOTH_ARROW ) {
	w = [A width];
	
	// construct arrow shaft:	
	/*should do this as part of the main axis line//
	 CGFloat length = 15 + w;
	 P = [NSBezierPath bezierPath];
	 //
	 if( [A orientation] == RS_ORIENTATION_HORIZONTAL ) {
	 p = [_mapper convertToViewCoords:CGPointMake([_graph xMax],[_mapper originPoint].y)];
	 [P moveToPoint:p];
	 p.x += length;
	 [P lineToPoint:p];
	 }
	 else if( [A orientation] == RS_ORIENTATION_VERTICAL ) {
	 p = [_mapper convertToViewCoords:CGPointMake([_mapper originPoint].x, [_graph yMax])];
	 [P moveToPoint:p];
	 p.y += length;
	 [P lineToPoint:p];
	 }
	 // draw the arrow shaft
	 [P setLineWidth:w];
	 [P stroke];
	 */
	
	// arrowhead dimensions:
	b = 3*w;//5*w/8; // the "big" dimension of the ^
	c = 3*w;//5*w/8; // the "small" dimension of the ^
	
	// rotation rectangle
	r.size.width  = w;
	r.size.height = w;
	
	// shift, rotate, and draw the arrowheads
	if( [A orientation] == RS_ORIENTATION_HORIZONTAL && [[_graph otherAxis:A] placement] != RSBothEdgesPlacement) {
	    // arrowhead at min-end
	    if( [A shouldDrawMinArrow] ) {
		p = [_mapper convertToViewCoords:RSDataPointMake([_graph xMin],[_mapper originPoint].y)];
                // the axis line may have moved perpendicularly to nearest pixel to avoid antialiasing
                if ([A width] <= AXIS_LINE_HINTING_WIDTH_CUTOFF) {
                    p.y = nearestPixelIfEnabled(p.y);
                }
		P = [NSBezierPath arrowheadWithBaseAtPoint:p width:b height:c];
		//r.origin = p;
		//[self rotateBezierPath:P inFrame:r byDegrees:180];
		[P fill];
	    }
	    // arrowhead at max-end
	    if( [A shouldDrawMaxArrow] ) {
		p = [_mapper convertToViewCoords:RSDataPointMake([_graph xMax],[_mapper originPoint].y)];
                
                // the axis line may have moved perpendicularly to nearest pixel to avoid antialiasing
                if ([A width] <= AXIS_LINE_HINTING_WIDTH_CUTOFF) {
                    p.y = nearestPixelIfEnabled(p.y);
                }
		/*
		 // draw shaft
		 P = [NSBezierPath bezierPath];
		 [P moveToPoint:p];
		 p.x += length;
		 [P lineToPoint:p];
		 [P setLineWidth:w];
		 [P stroke];
		 */
		// draw head
		P = [NSBezierPath arrowheadWithBaseAtPoint:p width:b height:c];
		r.origin = p;
		[P rotateInFrame:r byDegrees:180];
		[P fill];
	    }
	}
	else if( [A orientation] == RS_ORIENTATION_VERTICAL && [[_graph otherAxis:A] placement] != RSBothEdgesPlacement ) {
	    // arrowhead at min-end
	    if( [A shouldDrawMinArrow] ) {
		p = [_mapper convertToViewCoords:RSDataPointMake([_mapper originPoint].x,[_graph yMin])];
                // the axis line may have moved perpendicularly to nearest pixel to avoid antialiasing
                if ([A width] <= AXIS_LINE_HINTING_WIDTH_CUTOFF) {
                    p.x = nearestPixelIfEnabled(p.x);
                }
		P = [NSBezierPath arrowheadWithBaseAtPoint:p width:b height:c];
		r.origin = p;
		[P rotateInFrame:r byDegrees:90];
		[P fill];
	    }
	    // arrowhead at max-end
	    if( [A shouldDrawMaxArrow] ) {
		p = [_mapper convertToViewCoords:RSDataPointMake([_mapper originPoint].x,[_graph yMax])];
                // the axis line may have moved perpendicularly to nearest pixel to avoid antialiasing
                if ([A width] <= AXIS_LINE_HINTING_WIDTH_CUTOFF) {
                    p.x = nearestPixelIfEnabled(p.x);
                }
		P = [NSBezierPath arrowheadWithBaseAtPoint:p width:b height:c];
		r.origin = p;
		[P rotateInFrame:r byDegrees:270];
		[P fill];
	    }
	}
    }
}


- (void)drawAxisLabelsExcept:(RSGraphElement *)selection;
{
    // This seems to keep the number formatters happier. <bug:///69966>
    [[_graph xAxis] resetNumberFormatters];
    [[_graph yAxis] resetNumberFormatters];
    
    RSTextLabel *TL;
    Log3(@"drawAxisLabels (size: %d)", [_axisLabels count]);
    for (TL in _axisLabels) {
        if (TL != selection)
            [self drawLabel:TL];
    }
}


///////////////////////
#pragma mark -
#pragma mark Drawing methods for interactive feedback
///////////////////////

// draws little stripes on the axes to demonstrate where the mouse cursor is
// position in user coords
- (void)drawPosition:(RSDataPoint)p onAxis:(RSAxis *)A;
{
    NSBezierPath *P = [NSBezierPath bezierPath];
    RSDataPoint d;
    CGPoint v;
    CGFloat width = [A width];
    
    // don't do anything if the axis isn't visible
    if( ![A displayAxis] ) {
	return;
    }
    
    
    // the x-axis
    if ( [A orientation] == RS_ORIENTATION_HORIZONTAL ) {
	// don't do anything if the position is outside the axis range
	if( p.x < [A min] || p.x > [A max] ) {
	    return;
	}
	// setup
	d = p;
	// move to axis
	d.y = [_mapper originPoint].y;
	// convert to view coords
	v = [_mapper convertToViewCoords:d];
        
        // move to nearest pixel to avoid antialiasing
        v.x = nearestPixel(v.x);
        
	// move to top end
	v.y += width + [A tickWidthIn];
	[P moveToPoint:v];
	// move to bottom end
	v.y -= width + [A tickWidthIn] + width + [A tickWidthOut];
	[P lineToPoint:v];
    }
    else if ( [A orientation] == RS_ORIENTATION_VERTICAL ) {
	// don't do anything if the position is outside the axis range
	if( p.y < [A min] || p.y > [A max] ) {
	    return;
	}
	// setup
	d = p;
	// move to axis
	d.x = [_mapper originPoint].x;
	// convert to view coords
	v = [_mapper convertToViewCoords:d];
        
        // move to nearest pixel to avoid antialiasing
        v.y = nearestPixel(v.y);
        
	// move to top end
	v.x += width + [A tickWidthIn];
	[P moveToPoint:v];
	// move to bottom end
	v.x -= width + [A tickWidthIn] + width + [A tickWidthOut];
	[P lineToPoint:v];
    }
    
    // Bezier path settings
    [P setLineWidth:1];
    [[A color] set];
    
    // draw it
    [P stroke];
}

- (void)drawHalfSelectedPosition:(data_p)pos onAxis:(RSAxis *)axis;
// pos is the tick value (in data coords)
{
    CGRect r = [_mapper rectFromPosition:pos onAxis:axis];
    
    NSBezierPath *P = [NSBezierPath bezierPathWithRect:r];
    [[[[axis color] colorUsingColorSpace:OQColorSpaceRGB] colorWithAlphaComponent:0.25f] set];
    [P fill];
}


- (void)drawMarginGuide:(NSUInteger)edge;
{
    OBPRECONDITION(edge);
    
    NSBezierPath *P = [NSBezierPath bezierPath];
    
    switch (edge) {
	case RSBORDER_LEFT:
	    [P moveToPoint:CGPointMake([_mapper viewMins].x, 0)];
	    [P lineToPoint:CGPointMake([_mapper viewMins].x, [_graph canvasSize].height)];
	    break;
	case RSBORDER_RIGHT:
	    [P moveToPoint:CGPointMake([_mapper viewMaxes].x, 0)];
	    [P lineToPoint:CGPointMake([_mapper viewMaxes].x, [_graph canvasSize].height)];
	    break;
	case RSBORDER_BOTTOM:
	    [P moveToPoint:CGPointMake(0, [_mapper viewMins].y)];
	    [P lineToPoint:CGPointMake([_graph canvasSize].width, [_mapper viewMins].y)];
	    break;
	case RSBORDER_TOP:
	    [P moveToPoint:CGPointMake(0, [_mapper viewMaxes].y)];
	    [P lineToPoint:CGPointMake([_graph canvasSize].width, [_mapper viewMaxes].y)];
	    break;
	default:
	    return;
	    break;
    }
    
    [[OQColor purpleColor] set];
    [P setLineWidth:1];
    [P stroke];
}

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (void)drawFocusRingAroundRect:(CGRect)r;
{
    OQColor *focusColor = [[OQColor keyboardFocusIndicatorColor] colorUsingColorSpace:OQColorSpaceRGB];
    NSInteger nmofRings = 5;
    
    for (NSInteger i = nmofRings - 1; i >= 0; i-- ) {
        CGFloat offset = (CGFloat)i * 1;  // 1 pixel
        
        CGRect newRect = r;
        newRect.origin.x -= offset;
        newRect.origin.y -= offset;
        newRect.size.width += 2 * offset;
        newRect.size.height += 2 * offset;
        
        CGFloat alpha = ((CGFloat)(nmofRings - i))/(CGFloat)nmofRings;  // outer rings are lighter
        [[focusColor colorWithAlphaComponent:alpha] set];
        
        NSBezierPath *B = [NSBezierPath bezierPathWithRoundedRect:newRect xRadius:offset yRadius:offset];
        [B fill];
    }
}
#endif


#define RS_SELECTION_BORDER_WIDTH 4  /*was 1.1*/
#define RS_SELECTION_RINGS 1  /*was 4 -- number of "rings" to draw around the selection*/
#define RS_SELECTION_BASE_COLOR selectionColor /*was [OQColor keyboardFocusIndicatorColor]*/
#define RS_SELECTION_STARTING_ALPHA ((CGFloat)0.618033)

- (void)drawSelected:(RSGraphElement *)selection windowIsKey:(BOOL)windowIsKey;
{
    OQColor *selectionColor = nil;
    if (!windowIsKey) {
        // Use a gray selection color to help distinguish key from non-key windows
        selectionColor = [OQColor colorWithWhite:0.618033f alpha:1];
    }
    else {
        selectionColor = baseSelectionColor();
    }
    
    NSBezierPath *P;
    CGFloat adjustedBorderWidth;
    CGFloat newWidth;
    int i;
//    NSBezierPath *selectedVerticesPath = [NSBezierPath bezierPath];
    
    for ( RSGraphElement *obj in [selection elements] )
    {
	// reduce memory footprint if there are a lot of elements to be drawn
	NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
	
        // VERTICES //
	if ( [obj isKindOfClass:[RSVertex class]] ) {
            
            [(RSVertex *)obj drawSelectedUsingMapper:_mapper selectionColor:selectionColor borderWidth:RS_SELECTION_BORDER_WIDTH alpha:RS_SELECTION_STARTING_ALPHA fingerWidth:0 subpart:RSGraphElementSubpartWhole];
            
	}
        
        // LINES //
	else if ( [obj isKindOfClass:[RSLine class]] ) {
	    P = [self pathFromLine:(RSLine *)obj];  // don't add the dash style, if any
	    newWidth = [obj width] + (RS_SELECTION_RINGS * RS_SELECTION_BORDER_WIDTH * 2);
	    
	    CGFloat alpha = RS_SELECTION_STARTING_ALPHA;
	    for( i = 0; i < RS_SELECTION_RINGS; i++ ) {
		[P setLineWidth:newWidth];
		[[RS_SELECTION_BASE_COLOR colorWithAlphaComponent:alpha] set];
		[P stroke];
		newWidth -= RS_SELECTION_BORDER_WIDTH * 2;
		alpha += 1/(CGFloat)RS_SELECTION_RINGS;
	    }
	    
	    //[[OQColor colorWithRed:107 green:166 blue:225 alpha:1.0] set];
	    //[[[OQColor selectedControlColor] 
	    //		blendedColorWithFraction:0.0 
	    //						 ofColor:[OQColor blackColor]] set];
	    
	    [self drawLine:(RSLine *)obj];
	}
        
        // FILLS //
	else if ( [obj isKindOfClass:[RSFill class]] ) {
	    adjustedBorderWidth = RS_SELECTION_BORDER_WIDTH * 2;
	    newWidth = (RS_SELECTION_RINGS * adjustedBorderWidth);
	    
	    CGFloat alpha = RS_SELECTION_STARTING_ALPHA;
	    for( i = 0; i < RS_SELECTION_RINGS; i++ ) {
		P = [self pathFromFill:(RSFill *)obj];
		[P setLineWidth:newWidth];
		[[RS_SELECTION_BASE_COLOR colorWithAlphaComponent:alpha] set];
		[P stroke];
		newWidth -= adjustedBorderWidth;
		alpha += 1/(CGFloat)RS_SELECTION_RINGS;
	    }
	}
        
        // TEXT LABELS //
	else if ( [obj isKindOfClass:[RSTextLabel class]] ) {
            
            [(RSTextLabel *)obj drawSelectedUsingMapper:_mapper selectionColor:selectionColor borderWidth:RS_SELECTION_BORDER_WIDTH alpha:RS_SELECTION_STARTING_ALPHA fingerWidth:0 subpart:RSGraphElementSubpartWhole];
            
	}
        
        // AXES //
	else if ( [obj isKindOfClass:[RSAxis class]] ) {
	    P = [self pathFromAxis:(RSAxis *)obj width:[obj width] disableTicks:YES];
            P.lineCapStyle = kCGLineCapSquare;
	    newWidth = [obj width] + (RS_SELECTION_RINGS * RS_SELECTION_BORDER_WIDTH * 2);
	    
	    CGFloat alpha = RS_SELECTION_STARTING_ALPHA;
	    for( i = 0; i < RS_SELECTION_RINGS; i++ ) {
		[P setLineWidth:newWidth];
		[[RS_SELECTION_BASE_COLOR colorWithAlphaComponent:alpha] set];
		[P stroke];
		newWidth -= RS_SELECTION_BORDER_WIDTH * 2;
		alpha += 1/(CGFloat)RS_SELECTION_RINGS;
	    }
	    // draw the axis itself on top
            P = [self pathFromAxis:(RSAxis *)obj width:[obj width]];  // path with ticks enabled again
	    [P setLineWidth:newWidth];
	    [[obj color] set];
	    [P stroke];
	}
	else {
	    NSLog(@"RSGraphView doesn't know how to draw selected version of object.");
	}
	
	[subPool release];
    }
}



#define RS_HALF_SELECTION_BORDER_WIDTH ((CGFloat)2.2)

- (void)drawHalfSelected:(RSGraphElement *)halfSelection;
{
    NSBezierPath *P;
    CGFloat newWidth;
    CGFloat adjustedBorderWidth;
    
    for (RSGraphElement *obj in [halfSelection elements])
    {
        OQColor *color = [[obj color] colorUsingColorSpace:OQColorSpaceRGB];
        
	// Line
	if ( [obj isKindOfClass:[RSLine class]] ) {
	    P = [self pathFromLine:(RSLine *)obj];
            [self applyDashStyleForLine:(RSLine *)obj toPath:P];
	    newWidth = [obj width] + RS_HALF_SELECTION_BORDER_WIDTH;
	    [P setLineWidth:newWidth];
	    [[color blendedColorWithFraction:0.3f ofColor:[_graph backgroundColor]] set];
	    [P stroke];
	    newWidth -= RS_HALF_SELECTION_BORDER_WIDTH;
	    [P setLineWidth:newWidth];
	    if ( [color brightnessComponent] < 0.5 )
		[[color blendedColorWithFraction:0.5f ofColor:[OQColor whiteColor]] set];
	    else
		[[color blendedColorWithFraction:0.5f ofColor:[OQColor blackColor]] set];
	    [P stroke];
	}
        
	// Vertex
	else if ( [obj isKindOfClass:[RSVertex class]] ) {
	    // special case for bar chart style
	    if( [(RSVertex *)obj isBar] ) {
		P = [(RSVertex *)obj pathUsingMapper:_mapper];
		if ( [color brightnessComponent] < 0.5 )
		    [[[color blendedColorWithFraction:0.3f ofColor:[OQColor whiteColor]] 
		      colorWithAlphaComponent:0.66f] set];
		else
		    [[[color blendedColorWithFraction:0.2f ofColor:[OQColor blackColor]] 
		      colorWithAlphaComponent:0.66f] set];
		[P fill];
	    }
	    // normal vertex shapes
	    else {
		
		if( [RSGraph vertexHasShape:(RSVertex *)obj] )  adjustedBorderWidth = RS_HALF_SELECTION_BORDER_WIDTH / 3;
		else  adjustedBorderWidth = RS_HALF_SELECTION_BORDER_WIDTH * 3.5f;
		
		P = [(RSVertex *)obj pathUsingMapper:_mapper newWidth:([obj width] + adjustedBorderWidth)];
		[[color blendedColorWithFraction:0.3f ofColor:[_graph backgroundColor]] set];
		//[[color colorWithAlphaComponent:0.5] set];
		[P fill];
		P = [(RSVertex *)obj pathUsingMapper:_mapper];
		if ( [color brightnessComponent] < 0.5 )
		    [[color blendedColorWithFraction:0.5f ofColor:[OQColor whiteColor]] set];
		else
		    [[color blendedColorWithFraction:0.5f ofColor:[OQColor blackColor]] set];
		[P fill];
	    }
	}
        
	// Text Label
	else if ( [obj isKindOfClass:[RSTextLabel class]] ) {
	    P = [NSBezierPath bezierPathWithRect:[_mapper rectFromLabel:(RSTextLabel *)obj offset:1]];
	    CGRect r = [_mapper rectFromLabel:(RSTextLabel *)obj offset:0];
	    // take care of possible rotation:
	    [P rotateInFrame:r byDegrees:[(RSTextLabel *)obj rotation]];
	    [P setLineWidth:1];
	    //if ( [[_graph color] brightnessComponent] < 0.5 )
	    //	[[[_graph color] blendedColorWithFraction:0.2 ofColor:[OQColor whiteColor]] set];
	    //else
	    //	[[[_graph color] blendedColorWithFraction:0.2 ofColor:[OQColor blackColor]] set];
	    //[[OQColor selectedControlColor] set];
	    //[[[_graph color] blendedColorWithFraction:0.2 ofColor:color] set];
	    [[color colorWithAlphaComponent:0.25f] set];
	    [P fill];
	}
	else if ( [obj isKindOfClass:[RSFill class]] ) {
	    P = [self pathFromFill:(RSFill *)obj];
	    if ( [color brightnessComponent] < 0.5 )
		[[[color blendedColorWithFraction:0.3f ofColor:[OQColor whiteColor]] 
		  colorWithAlphaComponent:(CGFloat)(0.2 + [(RSFill *)obj opacity]/2)] set];
	    else
		[[[color blendedColorWithFraction:0.2f ofColor:[OQColor blackColor]] 
		  colorWithAlphaComponent:(CGFloat)(0.2 + [(RSFill *)obj opacity]/2)] set];
	    [P fill];
	}
        
	// Axis
	else if ( [obj isKindOfClass:[RSAxis class]] ) {
	    newWidth = [obj width];
	    P = [self pathFromAxis:(RSAxis *)obj width:newWidth];
	    newWidth += RS_HALF_SELECTION_BORDER_WIDTH;
	    [P setLineWidth:newWidth];
	    [[color blendedColorWithFraction:0.3f ofColor:[_graph backgroundColor]] set];
	    [P stroke];
	    newWidth -= RS_HALF_SELECTION_BORDER_WIDTH;
	    [P setLineWidth:newWidth];
	    [[color blendedColorWithFraction:0.5f ofColor:[OQColor whiteColor]] set];
	    [P stroke];
	}
	else {
	    NSLog(@"RSGraphView doesn't know how to draw half-selected version of object.");
	}
    }
}



/////////////////
#pragma mark -
#pragma mark Highest-level graph rendering methods
/////////////////
- (void)drawBackgroundWithColor:(OQColor *)backgroundColor;
{
    CGRect bounds = [_mapper bounds];
    if (bounds.size.width <= 1 || bounds.size.height <= 1) {
	OBASSERT_NOT_REACHED("RSGraphView bounds is not set");
	return;
    }
    
    //////////////////
    // Fill view with background color
    [backgroundColor set];

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    CGContextFillRect(UIGraphicsGetCurrentContext(), bounds);
#else
    [NSBezierPath fillRect: bounds];
#endif
    
    ///////////////////
    // Draw grid lines
    [self drawGrid];
}

- (void)turnOnShadows;
{
    if (![_graph shadowStrength])
        return;

    CGFloat normalOffset = 1 + 3*[_graph shadowStrength];

    OQColor *shadowColor;
    if( [[[_graph backgroundColor] colorUsingColorSpace:OQColorSpaceRGB] brightnessComponent] > 0.2 )
        shadowColor = [[OQColor blackColor] colorWithAlphaComponent:[_graph shadowStrength]];
    else  // dark background
        shadowColor = [[OQColor whiteColor] colorWithAlphaComponent:[_graph shadowStrength]];
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);


    CGContextSetShadowWithColor(ctx,
                                CGSizeMake(normalOffset, normalOffset),
                                (CGFloat)(3.0 + 1.5*[_graph shadowStrength]),
                                [shadowColor.toColor CGColor]);
#else
    [NSGraphicsContext saveGraphicsState];

    [_shadow setShadowOffset:CGSizeMake(normalOffset, -normalOffset)];
    [_shadow setShadowBlurRadius:(CGFloat)(3.0 + 1.5*[_graph shadowStrength])];
    [_shadow setShadowColor:shadowColor.toColor];
    
    [_shadow set];
#endif
}
- (void)turnOffShadows;
{
    if (![_graph shadowStrength])
        return;
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
#else
    [NSGraphicsContext restoreGraphicsState];
#endif
}

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (void)informAllLabelsOfEffectiveScale:(CGFloat)scale;
{
    for (RSTextLabel *T in [_graph Labels])
        [T useEffectiveScale:scale];
}
#endif

- (void)drawAllGraphElementsExcept:(RSGraphElement *)selection;
{
    
    ////////////////////
    // Draw any bar chart bars:
    for (RSVertex *V in [_graph Vertices])
    {
	if ( [V isVisible] && [V isBar] ) {
	    [V drawUsingMapper:_mapper];
	}
    }
    
    
    ///////////////////
    // Draw library of fills:
    for (RSFill *F in [_graph Fills])
    {
	[self drawFill:F];
    }
    
    
    ///////////////////
    // Draw axes
    [self drawAxis:[_graph xAxis]];
    [self drawAxis:[_graph yAxis]];
    
    
    ///////////////////
    // Draw axis labels
    // remember, -[RSGraphRenderer positionAxisLabels] needs to be called first - this is done in [updateDisplay]
    [self drawAxisLabelsExcept:selection];
    
    
    ////////////////
    // turn on shadows
    [self turnOnShadows];
    
    
    ///////////////////
    // Draw library of lines:
    for (RSLine *L in [_graph userLineElements])
    {
        [self drawLine:L];
    }
    
    
    ////////////////////
    // Draw library of vertices:
    for (RSVertex *V in [_graph Vertices]) {
	// reduce memory footprint if there are a lot of vertices
	NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
	
	if ( ![V isBar] ) {
	    [V drawUsingMapper:_mapper];
	}
	
	[subPool release];
    }
    
    
    /////////////
    // turn off the shadow rendering
    [self turnOffShadows];
    
    
    ////////////////////
    // Draw library of user-created labels (not tick labels)
    for (RSTextLabel *T in [_graph Labels])
    {
	if ( T == selection )
            continue;
        if ( [_graph isAxisTickLabel:T] )  // (because tick labels are drawn separately)
            continue;
        if ( ![T isVisible] )
            continue;
		
	[self drawLabel:T];
    }
    
}



/////////////////
#pragma mark -
#pragma mark Experimental
/////////////////

- (void)drawHistogram:(int *)bins;
{
    // get max count
    int i;
    int max = 0;
    for( i=0; bins[i] > -1; i++ ) {
	if ( max < bins[i] )  max = bins[i];
    }
    // now we should scale accordingly:
    data_p scale = ([_graph yMax] - [_graph yMin]) / max;
    
    // make a new empty path
    NSBezierPath *P = [NSBezierPath bezierPath];
    
    // construct path
    data_p x = [_graph xMin];
    data_p yMin = [_graph yMin];
    data_p y;
    for( i=0; bins[i] > -1; i++ ) {
	y = yMin;
	[P moveToPoint:[_mapper convertToViewCoords:RSDataPointMake(x,y)]];
	y = ((data_p)bins[i])*scale;
	[P lineToPoint:[_mapper convertToViewCoords:RSDataPointMake(x,y)]];
	x += [[_graph xAxis] spacing];
	[P lineToPoint:[_mapper convertToViewCoords:RSDataPointMake(x,y)]];
	y = yMin;
	[P lineToPoint:[_mapper convertToViewCoords:RSDataPointMake(x,y)]];
	[P closePath];
    }
    
    // fill in boxes
    [[OQColor colorWithRed:0 green:0 blue:0 alpha:0.15f] set];
    [P fill];
    // draw borders
    [[OQColor colorWithRed:0 green:0 blue:0 alpha:0.2f] set];
    [P setLineWidth:2];
    [P stroke];
    
}


////////////////////////////////////////////
#pragma mark -
#pragma mark DEBUGGING
////////////////////////////////////////////

#ifdef DEBUG
+ (void)drawCircleAt:(CGPoint)p;
{
    CGFloat offset = 3;  // pixels
    CGRect r = CGRectMake(p.x - offset, p.y - offset, offset*2, offset*2);
    NSBezierPath *P = [NSBezierPath bezierPathWithOvalInRect:r];
    [[OQColor redColor] set];
    [P stroke];
}
#endif


@end
