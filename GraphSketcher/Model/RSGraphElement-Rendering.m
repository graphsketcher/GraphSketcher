// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGraphElement-Rendering.m 200244 2013-12-10 00:11:55Z correia $

#import "RSGraphElement-Rendering.h"

#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/NSBezierPath-RSExtensions.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSNumber.h>
#import <OmniQuartz/OQColor.h>




#pragma mark -
@implementation RSGraphElement (Rendering)

- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper;
{
    NSLog(@"Subclass (%@) should override", NSStringFromClass([self class]));
    return nil;
}

- (void)drawSelectedUsingMapper:(RSDataMapper *)mapper selectionColor:(OQColor *)selectionColor borderWidth:(CGFloat)borderWidth alpha:(CGFloat)startingAlpha fingerWidth:(CGFloat)fingerWidth subpart:(RSGraphElementSubpart)subpart;
{
    NSLog(@"Subclass (%@) should override", NSStringFromClass([self class]));
}

- (void)drawSelectionAtPoint:(CGPoint)p borderWidth:(CGFloat)borderWidth color:(OQColor *)selectionColor minSize:(CGSize)minSize;
{
    [self drawSelectionAtPoint:p borderWidth:borderWidth color:selectionColor minSize:minSize subpart:RSGraphElementSubpartWhole];
}

- (void)drawSelectionAtPoint:(CGPoint)p borderWidth:(CGFloat)borderWidth color:(OQColor *)selectionColor minSize:(CGSize)minSize subpart:(RSGraphElementSubpart)subpart;
{
    NSLog(@"Subclass (%@) should override", NSStringFromClass([self class]));
}

- (CGSize)selectionSize;
{
    NSLog(@"Subclass (%@) should override", NSStringFromClass([self class]));
    return CGSizeZero;
}

- (CGSize)selectionSizeWithMinSize:(CGSize)minSize;
{
    NSLog(@"Subclass (%@) should override", NSStringFromClass([self class]));
    return CGSizeZero;
}

- (CGRect)viewRectWithMapper:(RSDataMapper *)mapper;
{
    //NSLog(@"Subclass should override");
    return CGRectZero;
}

- (CGRect)selectionViewRectWithMapper:(RSDataMapper *)mapper;
{
    CGRect viewRect = [self viewRectWithMapper:mapper];
    if (CGRectEqualToRect(viewRect, CGRectZero))
        return CGRectZero;
    
    CGFloat delta = 30;  // i.e. FUDGE FACTOR
    return CGRectInset(viewRect, -delta, -delta);
}

@end


#pragma mark -
@implementation RSVertex (Rendering)

- (CGRect)rectFromBarUsingMapper:(RSDataMapper *)mapper width:(CGFloat)w;
{
    OBASSERT(w > 0);
    NSInteger shape = [self shape];
    CGPoint p = [mapper convertToViewCoords:[self position]];
    CGRect r;
    
    if( shape == RS_BAR_VERTICAL ) {
	// scaling factor
	CGFloat b = w*RS_BAR_WIDTH_FACTOR;
	// find axis location
	CGPoint vo = [mapper convertToViewCoords:[mapper originPoint]];  // "view origin"
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
	CGPoint vo = [mapper convertToViewCoords:[mapper originPoint]];  // "view origin"
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

- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper;
{
    return [self pathUsingMapper:mapper newWidth:0];
}
- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper newWidth:(CGFloat)width;
{
    return [self pathUsingMapper:mapper newWidth:width newShape:[self shape]];
}
- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper newWidth:(CGFloat)width newShape:(NSInteger)shape;
{
    CGPoint p = [mapper convertToViewCoords:[self position]];
    return [self pathUsingMapper:mapper newWidth:width newShape:shape newPoint:p];
}
- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper newWidth:(CGFloat)width newShape:(NSInteger)shape newPoint:(CGPoint)p;
{
    NSBezierPath *P = [NSBezierPath bezierPath];
    
    //    [self appendToBezierPath:P vertexShape:shape width:width position:[mapper convertToViewCoords:[self position]]];
    //}
    
    //- (void)appendToBezierPath:(NSBezierPath *)P vertexShape:(NSInteger)shape width:(CGFloat)width position:(CGPoint)p;
    //{
    
    //    // Return the cached version if possible
    //    NSBezierPath *P = [_pathCache objectForKey:[self identifier]];
    //    if (P) {
    //        return P;
    //    }
    
    CGRect r;
    //CGPoint s, t; // for creating the star, etc.
    CGFloat b, c; // for creating the X, etc.
    CGFloat w;
    if ( width )
	w = width;
    else
	w = [self width];
    
    if (shape <= RS_LAST_STANDARD_SHAPE) {
        RSAppendShapeToBezierPath(P, p, shape, w, 0);
    }
    else if ( shape == RS_TICKMARK ) {
	b = 5*w; // the length of the tick mark
	RSLine *L;
	
	// Find out how much the tick should be rotated, if snapped to something.  Default is rotated a bit to the left, like in the inspector button.
	CGFloat rotation = 20;
        
	// snapped to an axis?
	RSAxis *A = (RSAxis *)[[self snappedTo] firstElementWithClass:[RSAxis class]];
	if( A ) {
	    CGFloat length = w*2 + [A tickWidthOut] + [A tickWidthIn];
	    
	    if ( [A orientation] == RS_ORIENTATION_VERTICAL ) {
		rotation = 90;
		p.x += length/2 - [A tickWidthOut] - w;
		b = length;
	    }
	    else if ( [A orientation] == RS_ORIENTATION_HORIZONTAL ) {
                rotation = 0;
		p.y += length/2 - [A tickWidthOut] - w;
		b = length;
	    }
	}
	// part of a line?
	else if( (L = [RSGraph firstParentLineOf:self]) ) {
	    CGFloat t = [[L paramForElement:self] floatValue];
	    rotation = [mapper degreesFromHorizontalOfLine:L atTime:t];
	}
	// snapped to a line?
	else if( (L = (RSLine *)[[self snappedTo] firstElementWithClass:[RSLine class]]) ) {
	    CGFloat t = [[self paramOfSnappedToElement:L] floatValue];
	    rotation = [mapper degreesFromHorizontalOfLine:L atTime:t];
	}
	// construct path
        [P appendTickAtPoint:p width:w height:b];
	// rotate if necessary
	if( rotation ) {
	    CGRect r = CGRectMake(0,0,b,b);
	    r.origin = p;
	    [P rotateInFrame:r byDegrees:rotation];
	}
	
    }
    else if ( shape == RS_ARROW ) {
	
	b = 3*w;//5*w/8; // the "big" dimension of the ^
	c = 3*w;//5*w/8; // the "small" dimension of the ^
        
        [P appendArrowheadAtPoint:p width:b height:c];
	
	// now, rotate the arrowhead if necessary
	RSLine *arrowParent = [self arrowParent];
        
	if (arrowParent && ![arrowParent hasNoLength]) {
	    // rotation will be based on the first line connected to the vertex
	    r.size.width  = w;
	    r.size.height = w;
	    r.origin = p;
	    
	    self.rotation = [mapper degreesFromHorizontalOfAdjustedEnd:self onLine:arrowParent];
            
	    [P rotateInFrame:r byDegrees:self.rotation];
	}
    }
    // Bar chart shapes
    else if( shape == RS_BAR_VERTICAL || shape == RS_BAR_HORIZONTAL ) {
        r = [self rectFromBarUsingMapper:mapper width:w];
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        [P appendPath:[UIBezierPath bezierPathWithRect:r]];
#else
        [P appendBezierPathWithRect:r];
#endif
    }
    //
    else { // if the end of an arrow, or something unspecified, make it round:
	//NSLog(@"Shouldn't happen?");
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
    
    
    //    [_pathCache setObject:P forKey:[self identifier]];
    return P;
}


- (void)drawUsingMapper:(RSDataMapper *)mapper;
{
    NSBezierPath *P;
    
    if ([self width] <= 0)
	return;
    
    if ([self shape] == RS_NONE)
        return;
    
    if( [self shape] == RS_HOLLOW ) {
	// clear what's behind it
	P = [self pathUsingMapper:mapper newWidth:(CGFloat)([self width]*0.8 - 0.4) newShape:RS_CIRCLE];
	[[_graph backgroundColor] set];
	[P fill];
	// draw the hollow point
	P = [self pathUsingMapper:mapper];
	[[self color] set];
	[P fill];
    }
    else if( [self isBar] ) {
	P = [self pathUsingMapper:mapper];
	[[self color] set];
	[P fill];
    }
    else {
	P = [self pathUsingMapper:mapper];
	[[self color] set];
	[P fill];
    }
}




- (CGSize)selectionSize;
{
    return [self size];
}

- (CGSize)selectionSizeWithMinSize:(CGSize)minSize;
{
    CGFloat minWidth = minSize.width;
    
    CGFloat width = self.width;
    if (width < minWidth) {
        width = minWidth;
    }
    
    return CGSizeMake(width, width);
}


#define RS_SELECTION_RINGS 1  /*was 4 -- number of "rings" to draw around the selection*/

- (void)drawSelectedUsingMapper:(RSDataMapper *)mapper selectionColor:(OQColor *)selectionColor borderWidth:(CGFloat)borderWidth alpha:(CGFloat)startingAlpha fingerWidth:(CGFloat)fingerWidth subpart:(RSGraphElementSubpart)subpart;
{
    NSBezierPath *P;
    CGFloat adjustedBorderWidth;
    CGFloat newWidth;
    NSInteger i;
    
    // special case for bar-chart style
    if( [self isBar] ) {
        adjustedBorderWidth = borderWidth;
        newWidth = RS_SELECTION_RINGS * adjustedBorderWidth;
        
        CGFloat width = self.width;
        if (width < fingerWidth) {
            width = fingerWidth;
        }
        
        if (subpart == RSGraphElementSubpartBarEnd) {
            CGFloat height = 20;
            CGPoint p = [mapper convertToViewCoords:self.position];
            CGRect rect = CGRectMake(p.x - width/2, p.y - height/2, width, height);
            NSBezierPath *P = [NSBezierPath bezierPathWithRect:rect];
            [P setLineWidth:newWidth];
            [selectionColor set];
            [P stroke];
        }
        else {
            CGFloat alpha = startingAlpha;
            for( i = 0; i < RS_SELECTION_RINGS; i++ ) {
//                CGRect rect = [self rectFromBarUsingMapper:mapper width:width];
//                P = [NSBezierPath bezierPathWithRect:rect];
                P = [self pathUsingMapper:mapper];
                [P setLineWidth:newWidth];
                [[selectionColor colorWithAlphaComponent:alpha] set];
                [P stroke];
                newWidth -= adjustedBorderWidth;
                alpha += 1/(CGFloat)RS_SELECTION_RINGS;
            }
        }
    }
    // normal vertex shapes
    else {
        if( [RSGraph vertexHasShape:self] )  adjustedBorderWidth = borderWidth * 0.5f;
        else  adjustedBorderWidth = borderWidth * 3;
        
        newWidth = [self width] + (RS_SELECTION_RINGS * adjustedBorderWidth);
        CGFloat alpha = startingAlpha;
        for( i = 0; i < RS_SELECTION_RINGS; i++ ) {
            //                    [self _appendToPath:selectedVerticesPath fromVertex:self newWidth:newWidth newShape:[self shape]];
            P = [self pathUsingMapper:mapper newWidth:newWidth];
            [[selectionColor colorWithAlphaComponent:alpha] set];
            [P fill];
            newWidth -= adjustedBorderWidth;
            alpha += 1/(CGFloat)RS_SELECTION_RINGS;
        }
        
        [self drawUsingMapper:mapper];
    }
}

- (void)drawSelectionAtPoint:(CGPoint)p borderWidth:(CGFloat)borderWidth color:(OQColor *)selectionColor minSize:(CGSize)minSize subpart:(RSGraphElementSubpart)subpart;
{
    CGFloat minWidth = [self widthFromSize:minSize];
    
    CGFloat width = self.width;
    if (width < minWidth) {
        width = minWidth;
    }
    
    NSBezierPath *path;
    
    if( [self isBar] ) {
        if (subpart == RSGraphElementSubpartBarEnd) {
            CGFloat height = 20;
            width = minSize.width;
            if (self.shape == RS_BAR_HORIZONTAL) {
                height = width;
                width = 20;
            }
            CGRect rect = CGRectMake(p.x - width/2, p.y - height/2, width, height);
            path = [NSBezierPath bezierPathWithRect:rect];
        }
        else {
            //CGRect rect = [self rectFromBarUsingMapper:];
            path = nil;
        }
    }
    else {
        path = [NSBezierPath bezierPath];
        NSInteger shape = self.shape;
        // The naive selection ring for hollow points looks weird, so just pretend it's a circle:
        if (shape == RS_HOLLOW)
            shape = RS_CIRCLE;
        RSAppendShapeToBezierPath(path, p, shape, width, self.rotation);
    }
    
    path.lineWidth = borderWidth;
    [selectionColor set];
    [path stroke];
}

- (void)drawAtPoint:(CGPoint)p size:(CGSize)size;
{
    CGFloat width = [self widthFromSize:size];
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    RSAppendShapeToBezierPath(path, p, self.shape, width, self.rotation);
    
    [[self color] set];
    [path fill];
}

- (CGRect)viewRectWithMapper:(RSDataMapper *)mapper;
{
    if ([self isBar]) {
        CGRect rect = [self rectFromBarUsingMapper:mapper width:[self width]];
        CGFloat delta = [self size].width * 0.2f;
        return CGRectInset(rect, -delta, -delta);
    }
    
    // Normal points (non-bars):
    CGSize size = [self size];
    CGPoint center = [mapper convertToViewCoords:[self position]];
    CGRect firstRect = CGRectMake(center.x - size.width/2, center.y - size.height/2, size.width, size.height);
    
    // Vertices are actually bigger than they claim
    CGFloat delta = -2.0f;
    CGRect rect = CGRectInset(firstRect, delta, delta);
    
    return rect;
}

@end


#pragma mark -
@implementation RSTextLabel (Rendering)

- (CGSize)selectionSize;
{
    CGSize size = [self size];
    return RSSizeRotate(size, self.rotation);
}

- (CGSize)selectionSizeWithMinSize:(CGSize)minSize;
{
    CGSize size = [self size];
    
    CGFloat smallDimension = RSMinSizeDimension(size);
    CGFloat minSmallDimension = RSMinSizeDimension(minSize);
    if (smallDimension < minSmallDimension) {
        CGFloat delta = minSmallDimension - smallDimension;
        size.width += delta;
        size.height += delta;
    }
    
    return RSSizeRotate(size, self.rotation);
}

- (void)drawSelectedUsingMapper:(RSDataMapper *)mapper selectionColor:(OQColor *)selectionColor borderWidth:(CGFloat)borderWidth alpha:(CGFloat)startingAlpha fingerWidth:(CGFloat)fingerWidth subpart:(RSGraphElementSubpart)subpart;
{
    NSBezierPath *P;
    CGFloat newWidth;
    NSInteger i;
    
    newWidth = (CGFloat)(1.0 + RS_SELECTION_RINGS * borderWidth * 0.5f);
    // frame rect for rotation:
    CGRect r = [mapper rectFromLabel:self offset:0];
    
    CGFloat alpha = startingAlpha;
    for( i = 0; i < RS_SELECTION_RINGS; i++ ) {
        P = [NSBezierPath bezierPathWithRect:[mapper rectFromLabel:self 
                                                             offset:newWidth]];
        // take care of possible rotation:
        [P rotateInFrame:r byDegrees:[self rotation]];
        [P setLineWidth:borderWidth];
        
        [[selectionColor colorWithAlphaComponent:alpha] set];
        [P stroke];
        newWidth -= borderWidth;
        alpha += 1/(CGFloat)RS_SELECTION_RINGS;
    }
}

- (void)drawSelectionAtPoint:(CGPoint)p borderWidth:(CGFloat)borderWidth color:(OQColor *)selectionColor minSize:(CGSize)minSize subpart:(RSGraphElementSubpart)subpart;
{
    CGSize size = [self size];
    CGFloat smallDimension = RSMinSizeDimension(size);
    CGFloat minSmallDimension = RSMinSizeDimension(minSize);
    if (smallDimension < minSmallDimension) {
        CGFloat delta = minSmallDimension - smallDimension;
        size.width += delta;
        size.height += delta;
    }
    
    size.width += borderWidth*2;
    size.height += borderWidth*2;
    CGRect rect = CGRectMake(p.x - size.width/2, p.y - size.height/2, size.width, size.height);
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:rect];
    
    // take care of possible rotation:
    CGFloat rotation = [self rotation];
    if (rotation) {
        // We want to rotate within a 0-offset frame, even though the path is bigger than that frame
        CGRect zeroOffsetRect = CGRectMake(p.x, p.y, 0, 0);
        [path rotateInFrame:zeroOffsetRect byDegrees:rotation];
    }
    
    path.lineWidth = borderWidth;
    [selectionColor set];
    [path stroke];
}

- (CGRect)viewRectWithMapper:(RSDataMapper *)mapper;
{
    CGSize size = [self size];
    CGPoint point = [mapper convertToViewCoords:[self position]];
    CGRect rect = CGRectMake(point.x, point.y, size.width, size.height);
    
    if ([self rotation]) {
        // Make sure it's big enough
        CGFloat diff = fabs(size.height - size.width);
        rect = CGRectInset(rect, -diff, -diff);
    }
    
    return rect;
}

@end


#pragma mark -
@implementation RSLine (Rendering)

- (CGRect)viewRectWithMapper:(RSDataMapper *)mapper;
{
    return [[self vertices] viewRectWithMapper:mapper];
}

@end


#pragma mark -
@implementation RSFill (Rendering)

//- (CGRect)viewRectWithMapper:(RSDataMapper *)mapper;
//{
//    return [[self vertices] viewRectWithMapper:mapper];
//}

@end


#pragma mark -
@implementation RSAxis (Rendering)

- (CGRect)viewRectWithMapper:(RSDataMapper *)mapper;
{
    if (self.placement == RSBothEdgesPlacement) {
        return CGRectZero;  // Meaning "use the whole viewport"
    }
    
    CGPoint min = [mapper viewMins];
    CGPoint max = [mapper viewMaxes];
    CGPoint origin = [mapper viewOriginPoint];
    CGFloat width = [self width];
    
    if ([self orientation] == RS_ORIENTATION_HORIZONTAL) {
        CGRect r = CGRectMake(min.x, origin.y - width/2.0f, max.x - min.x, width);
        return r;
    }
    else {  // RS_ORIENTATION_VERTICAL
        CGRect r = CGRectMake(origin.x - width/2.0f, min.y, width, max.y - min.y);
        return r;
    }
}

@end


#pragma mark -
@implementation RSGroup (Rendering)

- (CGRect)viewRectWithMapper:(RSDataMapper *)mapper;
{
    NSArray *positionedObjects = [self elements];//[RSGraph elementsWithPrimaryPosition:self];
    CGRect unionRect = CGRectZero;
    
    for (RSGraphElement *GE in positionedObjects) {
        
        CGRect subRect = [GE viewRectWithMapper:mapper];
        
        if (CGRectEqualToRect(subRect, CGRectZero)) {
            return CGRectZero;  // this means "we don't know, so use the full screen"
        }
        
        if (CGRectEqualToRect(unionRect, CGRectZero)) {
            unionRect = subRect;
        }
        else if (!CGRectEqualToRect(subRect, CGRectZero)) {
            unionRect = CGRectUnion(unionRect, subRect);
        }
    }
    
    return unionRect;
}

@end

