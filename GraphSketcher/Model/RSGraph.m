// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSGraph.h>

#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/NSArray-RSExtensions.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSGrid.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSFitLine.h>
#import <GraphSketcherModel/OFPreference-RSExtensions.h>
#import <OmniQuartz/OQColor.h>

#import "OSStyleContext.h"

#import <OmniFoundation/OFXMLIdentifierRegistry.h>
#import <OmniFoundation/OFPreference.h>
#import <OmniFoundation/NSArray-OFExtensions.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>
#endif

/////////////////////////////////////////////////////
#pragma mark -
#pragma mark functions
/////////////////////////////////////////////////////
RSBorder RSMakeBorder(CGFloat top, CGFloat right, CGFloat bottom, CGFloat left)
{
    RSBorder b;
    b.top = top;
    b.right = right;
    b.bottom = bottom;
    b.left = left;
    
    return b;
}

RSBorder RSUnionBorder(RSBorder b1, RSBorder b2)
// Returns the smallest border that contains b1 and b2.
{
    RSBorder max;
    if (b1.top > b2.top)  max.top = b1.top;
    else  max.top = b2.top;
    if (b1.right > b2.right)  max.right = b1.right;
    else  max.right = b2.right;
    if (b1.bottom > b2.bottom)  max.bottom = b1.bottom;
    else  max.bottom = b2.bottom;
    if (b1.left > b2.left)  max.left = b1.left;
    else  max.left = b2.left;
    
    return max;
}

RSBorder RSSumBorder(RSBorder b1, RSBorder b2)
{
    RSBorder sum;
    sum.top = b1.top + b2.top;
    sum.right = b1.right + b2.right;
    sum.bottom = b1.bottom + b2.bottom;
    sum.left = b1.left + b2.left;
    
    return sum;
}

BOOL RSEqualBorders(RSBorder b1, RSBorder b2)
// returns YES iff b1 and b2 are identical
{
    if (b1.top == b2.top && b1.right == b2.right && b1.bottom == b2.bottom && b1.left == b2.left)
	return YES;
    return NO;
}

CGRect RSAddBorderToPoint(RSBorder b, CGPoint p)
{
    CGRect r;
    r.origin = CGPointMake(p.x - b.left, p.y - b.bottom);
    r.size = CGSizeMake(b.left + b.right, b.bottom + b.top);
    
    return r;
}

NSString *RSStringFromBorder(RSBorder b)
{
    return [NSString stringWithFormat:@"{%f, %f, %f, %f}", b.top, b.right, b.bottom, b.left];
}

RSBorder RSBorderFromString(NSString *s)
// String format is: "{top, right, bottom, left}"
{
    OBASSERT(s && ![s isEqual:@""]);

    double d;
    RSBorder b;
    NSScanner *scanner = [NSScanner scannerWithString:s];
    [scanner scanString:@"{" intoString:NULL];
    [scanner scanDouble:&d]; b.top = (CGFloat)d;
    [scanner scanString:@"," intoString:NULL];
    [scanner scanDouble:&d]; b.right = (CGFloat)d;
    [scanner scanString:@"," intoString:NULL];
    [scanner scanDouble:&d]; b.bottom = (CGFloat)d;
    [scanner scanString:@"," intoString:NULL];
    [scanner scanDouble:&d]; b.left = (CGFloat)d;
    [scanner scanString:@"}" intoString:NULL];
    
    OBASSERT([scanner isAtEnd]);
    return b;
}

CGPoint frameOriginFromFrameString(NSString *s) {
    NSScanner *scanner = [NSScanner localizedScannerWithString:s];
    double x, y;
    // get the first two values (probably origin.x and origin.y)
    [scanner scanDouble:&x];
    [scanner scanDouble:&y];
    
    if (x && y)
	return CGPointMake((CGFloat)x, (CGFloat)y);
    
    OBASSERT_NOT_REACHED("Invalid frameString - frame origin is null or too small.");
    return CGPointMake(0, 0);
}

static CGSize frameSizeFromFrameString(NSString *s) {
    // this seems like a hack, but oh well
    NSScanner *scanner = [NSScanner localizedScannerWithString:s];
    double width;
    double height;
    // bypass the first two values (probably origin.x and origin.y)
    [scanner scanDouble:nil];
    [scanner scanDouble:nil];
    // get the next two values (width and height)
    [scanner scanDouble:&width];
    [scanner scanDouble:&height];
    
    if( width >= 5 && height >= 5 )
	return CGSizeMake((CGFloat)width, (CGFloat)height);
    
    OBASSERT_NOT_REACHED("Invalid frameString - frame size is null or too small.");
    return CGSizeMake(0, 0);
}

CGSize canvasSizeFromFrameString(NSString *string)
{
    CGSize size = frameSizeFromFrameString(string);
    // subtract the window space
    size.height -= 42;
    return size;
}

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
NSString *messageForCanvasSize(CGSize size)
// Generates a string with the canvas size (to be displayed in the status bar)
{
    NSString *format = NSLocalizedStringFromTableInBundle(@"Canvas size:  %1$.0f x %2$.0f pixels", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar description of canvas size");
    NSString *message = [NSString stringWithFormat:format, size.width, size.height];
    CGSize inches;
    NSString *nonPixel;
    if( size.width > 280 ) {
	// compute inches
	inches.width = size.width / 72;
	inches.height = size.height / 72;
	
	if( [[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:@"AppleMeasurementUnits"] isEqualToString:@"Centimeters"] ) {
	    // convert to centimeters
	    inches.width *= 2.54f;
	    inches.height *= 2.54f;
            format = NSLocalizedStringFromTableInBundle(@" (%1$.1f by %2$.1f cm)", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar canvas size addendum in centimeters");
	}
	else {
            format = NSLocalizedStringFromTableInBundle(@" (%1$.1f by %2$.1f inches)", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar canvas size addendum in inches");
	}
        nonPixel = [NSString stringWithFormat:format, inches.width, inches.height];
	message = [message stringByAppendingString: nonPixel];
    }
    
    return message;
}
#endif


#pragma mark -
@implementation RSGraph


/////////////////////////////////////////////////////
#pragma mark -
#pragma mark Utility methods for inspecting graph elements
/////////////////////////////////////////////////////
+ (RSLine *)firstParentLineOf:(RSVertex *)V {
    return [[V parents] firstObjectWithClass:[RSLine class]];
}

+ (RSTextLabel *)labelOf:(RSGraphElement *)GE {
    RSLine *L;
    if ( (L = [RSGraph isLine:GE]) ) {
	return [L label];
    }
    else  return nil;
}

+ (RSGraphElement *)labelFromElement:(RSGraphElement *)obj;
// Returns the graph element closely associated with 'obj' that is most likely to respond to -font and -fontSize selectors.  This includes axes and groups.
{
    RSLine *L = [RSGraph isLine:obj];
    if (L)
	obj = [L label];
    else if ([obj isKindOfClass:[RSVertex class]] || [obj isKindOfClass:[RSLine class]] || [obj isKindOfClass:[RSFill class]]) {
	obj = [obj label];
    }
    
    return obj;
}

+ (RSGraphElement <RSFontAttributes> *)fontAtrributeElementForElement:(RSGraphElement *)obj;
// Returns the graph element closely associated with 'obj' that is most likely to respond to -font and -fontSize selectors.  This includes axes and groups.
{
    if ([obj conformsToProtocol:@protocol(RSFontAttributes)])
        return (RSGraphElement <RSFontAttributes> *)obj;
    
    // RSGraphElement *does* implement -label, but it might not in the future since it's just a stub implementation.
    // In the name of keeping the inspector short, don't show the font controls unless something with RSFontAttributes is actually selected.
//    if ([obj respondsToSelector:@selector(label)]) {
//        return [obj label];
//        
//    }
    return nil;
}

+ (RSLine *)isLine:(RSGraphElement *)GE;
{
    if( [GE isKindOfClass:[RSLine class]] ) {
	return (RSLine *)GE;
    }
    else if( [GE isKindOfClass:[RSGroup class]] ) {
	// first, look for a single line
	RSLine *line = nil;
	for (RSGraphElement *GE2 in [(RSGroup *)GE elements])
	{
	    if( [GE2 isKindOfClass:[RSLine class]] ) {
		if( !line )  line = (RSLine *)GE2;
		else  return nil;
	    }
	}
	if( !line )  return nil;
	
	// next, take a second pass checking that everything else is a child of the line
	for (RSGraphElement *GE2 in [(RSGroup *)GE elements])
	{
	    if( ([GE2 isKindOfClass:[RSVertex class]] && [line containsVertex:(RSVertex *)GE2])
	       || GE2 == line ) {
		// then so far so good
	    }
	    else  return nil;
	}
	// if got this far
	return line;
    }
    // if not a line or a group
    else  return nil;
}

+ (RSFill *)isFill:(RSGraphElement *)GE;
{
    if( [GE isKindOfClass:[RSFill class]] ) {
	return (RSFill *)GE;
    }
    else if( [GE isKindOfClass:[RSGroup class]] ) {
	// first, look for a single fill
	RSFill *fill = nil;
	for (RSGraphElement *GE2 in [(RSGroup *)GE elements])
	{
	    if( [GE2 isKindOfClass:[RSFill class]] ) {
		if( !fill )  fill = (RSFill *)GE2;
		else  return nil;
	    }
	}
	if( !fill )  return nil;
	
	// next, take a second pass checking that everything else is a child of the fill
	for (RSGraphElement *GE2 in [(RSGroup *)GE elements])
	{
	    if( ([GE2 isKindOfClass:[RSVertex class]] && [fill containsVertex:(RSVertex *)GE2])
	       || GE2 == fill ) {
		// then so far so good
	    }
	    else  return nil;
	}
	// if got this far
	return fill;
    }
    // if not a fill or a group
    else  return nil;
}

+ (RSVertex *)isVertex:(RSGraphElement *)GE;
// If a group, every element in the group must be in the same vertex cluster.
{
    if ([GE isKindOfClass:[RSVertex class]]) {
        return (RSVertex *)GE;
    }
    else if ([GE isKindOfClass:[RSGroup class]]) {
        RSGroup *group = (RSGroup *)GE;
        RSVertex *first = (RSVertex *)[group firstElement];
        if (![first isKindOfClass:[RSVertex class]]) {
            return nil;
        }
        NSArray *vertexCluster = [first vertexCluster];
        for (RSVertex *V in [(RSGroup *)GE elements]) {
            if (![V isKindOfClass:[RSVertex class]])
                return NO;
            if (![vertexCluster containsObjectIdenticalTo:V]) {
                return nil;
            }
        }
        return first;
    }
    
    return nil;
}

+ (RSLine *)commonParentLine:(NSArray *)A;
// If all vertices in A have at least one line parent in common, the first such line is returned.  Otherwise, returns nil.
{
    RSVertex *firstVertex = nil;
    
    for (RSGraphElement *GE in A) {
        if ([GE isKindOfClass:[RSVertex class]]) {
            firstVertex = (RSVertex *)GE;
            break;
        }
    }
    if (!firstVertex)
        return nil;
    
    for (RSLine *parent in [firstVertex parents]) {
        if (![parent isKindOfClass:[RSLine class]])
            continue;
        
        if ([parent containsVertices:A]) {
            return parent;
        }
    }
    
    // If got this far, did not find a parent line with all vertices in it.
    return nil;
}

+ (RSLine *)singleParentLine:(NSArray *)A;
// If the vertices in A have exactly one parent line (some vertices could have no parents), then the line is returned.
{
    RSLine *parentLine = nil;
    
    for (RSVertex *V in A) {
        if (![V isKindOfClass:[RSVertex class]])
            continue;
        
        NSArray *parents = [[V parents] objectsWithClass:[RSLine class]];
        if ([parents count] == 0) {
            continue;
        }
        else if ([parents count] == 1) {
            if (!parentLine) {
                parentLine = [parents objectAtIndex:0];
            }
            else {
                if (parentLine != [parents objectAtIndex:0]) {
                    return nil;
                }
            }
        }
        else {  // [parents count] > 1
            return nil;
        }
    }
    
    return parentLine;
}

+ (BOOL)hasStraightSegments:(RSGraphElement *)GE;
// Returns yes for all 2-point lines and complex lines that have straight segments
{
    if (![GE isKindOfClass:[RSLine class]]) {
        return NO;
    }
    if (![(RSLine *)GE isCurved]) {
        return YES;
    }
    if ([GE isKindOfClass:[RSConnectLine class]] && [(RSConnectLine *)GE connectMethod] == RSConnectStraight) {
        return YES;
    }
    return NO;
}

+ (BOOL)isText:(RSGraphElement *)GE
// returns true if ALL of the elements are text labels
{
    if( [GE isKindOfClass:[RSTextLabel class]] ) {
	return YES;
    }
    else if( [GE isKindOfClass:[RSGroup class]] ) {
	if ( [(RSGroup *)GE isEmpty] )  return NO;
	
	for (RSGraphElement *obj in [(RSGroup *)GE elements])
	{
	    if ( ![obj isKindOfClass:[RSTextLabel class]] ) return NO;
	}
	// if got this far, all objects in this group are text labels:
	return YES;
    }
    else {  // any other type of graph element
	return NO;
    }
}

+ (BOOL)hasVertices:(RSGraphElement *)GE {
    if( !GE )  return NO;
    else if( [GE isKindOfClass:[RSVertex class]] )  return YES;
    else if( [GE isKindOfClass:[RSGroup class]] ) {
	for (RSGraphElement *obj in [(RSGroup *)GE elements]) {
	    if( [RSGraph hasVertices:obj] )  return YES;
	}
	// if got this far
	return NO;
    }
    else  return NO;
}
+ (BOOL)hasMultipleVertices:(RSGraphElement *)GE {
    if( [GE isKindOfClass:[RSGroup class]] ) {
	return ( [(RSGroup *)GE numberOfElementsWithClass:[RSVertex class]] >= 2 );
    }
    else  return NO;
}
+ (BOOL)hasAtLeastThreeVertices:(RSGraphElement *)GE {
    if( [GE isKindOfClass:[RSGroup class]] ) {
	return ( [(RSGroup *)GE numberOfElementsWithClass:[RSVertex class]] >= 3 );
    }
    else if( [GE isKindOfClass:[RSFill class]] ) {
	return [(RSFill *)GE hasAtLeastThreeVertices];
    }
    else  return NO;
}

+ (BOOL)hasArrow:(RSGraphElement *)GE onEnd:(int)endSpecifier {
    RSLine *L;
    NSInteger shape = 0;
    
    if( [GE isKindOfClass:[RSVertex class]] ) {
	shape = [(RSVertex *)GE shape];
    }
    else if ((L = [RSGraph isLine:GE])) {
	shape = [[L startVertex] shape];
    }
    else if( [GE isKindOfClass:[RSGroup class]] ) {
	// if group, return YES only if all elements have arrow
	for (RSGraphElement *obj in [GE elements])
	{
	    if( ([obj shape] != endSpecifier) && ([obj shape] != RS_BOTH_ARROW) )  return NO;
	}
	// if got this far
	return YES;
    }
    
    return ((shape == endSpecifier) || (shape == RS_BOTH_ARROW));
}

+ (NSInteger)vertexHasShape:(RSVertex *)V;
// means "shape is not RS_NONE"
{
    return [V shape];
}

+ (BOOL)isPointAndFill:(RSGraphElement *)GE
// returns true if the GE is a group containing exactly one point and one fill
{
    if( [GE isKindOfClass:[RSGroup class]] ) {
	BOOL foundPoint = NO;
	BOOL foundFill = NO;
	
	for (RSGraphElement *obj in [(RSGroup *)GE elements])
	{
	    if ( [obj isKindOfClass:[RSVertex class]] ) {
		if ( foundPoint )  return NO;
		else  foundPoint = YES;
	    }
	    else if ( [obj isKindOfClass:[RSFill class]] ) {
		if ( foundFill )  return NO;
		else  foundFill = YES;
	    }
	}
	// if got this far, no more than one point or fill has been found
	if ( foundPoint && foundFill ) return YES;
	else return NO;
    }
    else {  // not an RSGroup
	return NO;
    }
}


// For use with exporting vertex data to other programs
+ (NSString *)tabularStringRepresentationOfPointsIn:(RSGraphElement *)GE {
    
    if( [GE isKindOfClass:[RSVertex class]] ) {
	return [(RSVertex *)GE tabularStringRepresentation];
    }
    else if( [GE isKindOfClass:[RSGroup class]] ) {
	NSArray *A = [(RSGroup *)GE elementsWithClass:[RSVertex class]];
	NSMutableString *s = [NSMutableString string];
	for (RSVertex *V in A) {
	    [s appendString:[V tabularStringRepresentation]];
	    [s appendString:@"\n"];
	}
	return s;
    }
    
    return nil;
}

- (RSDataPoint)dataMinsOfGraphElements:(NSArray *)array;
{
    if (![array count]) {
        OBASSERT_NOT_REACHED("There are no graph elements to find the mins of");
        return RSDataPointMake(0, 0);
    }
    
    BOOL logarithmicX = ([_xAxis axisType] == RSAxisTypeLogarithmic && [_xAxis min] > 0);
    BOOL logarithmicY = ([_yAxis axisType] == RSAxisTypeLogarithmic && [_yAxis min] > 0);
    
    RSDataPoint mins = RSDataPointMake(DBL_MAX, DBL_MAX);
    RSDataPoint positiveMins = RSDataPointMake(DBL_MAX, DBL_MAX);
    
    for (RSGraphElement *GE in array) {
        RSDataPoint p = [GE position];
        
        if (p.x < mins.x) {
            mins.x = p.x;
        }
        if (logarithmicX && p.x > 0 && p.x < positiveMins.x) {
            positiveMins.x = p.x;
        }
            
        if (p.y < mins.y) {
            mins.y = p.y;
        }
        if (logarithmicY && p.y > 0 && p.y < positiveMins.y) {
            positiveMins.y = p.y;
        }
    }
    
    // For logarithmic axes, just use positive values, unless there were only negative values
    if (logarithmicX && positiveMins.x < DBL_MAX) {
        mins.x = positiveMins.x;
    }
    if (logarithmicY && positiveMins.y < DBL_MAX) {
        mins.y = positiveMins.y;
    }
    
    return mins;
}

- (RSDataPoint)dataMaxesOfGraphElements:(NSArray *)array;
{
    if (![array count]) {
        OBASSERT_NOT_REACHED("There are no graph elements to find the maxes of");
        return RSDataPointMake(0, 0);
    }
    
    RSDataPoint maxes = RSDataPointMake(-DBL_MAX, -DBL_MAX);
    
    for (RSGraphElement *GE in array) {
        RSDataPoint p = [GE position];
        
        if (p.x > maxes.x) {
            maxes.x = p.x;
        }
        
        if (p.y > maxes.y) {
            maxes.y = p.y;
        }
    }
    
    return maxes;
}

// finds the average value of vertices in a group
+ (RSDataPoint)meanOfGroup:(RSGroup *)G {
    RSDataPoint avg, p;
    int counter;
    
    avg.x = avg.y = 0;
    counter = 0;
    for (RSVertex *V in [G elementsWithClass:[RSVertex class]])
    {
	p = (RSDataPoint)[V position];
	avg.x += p.x;
	avg.y += p.y;
	counter++;
    }
    
    if( counter == 0 ) { // no vertices found
	return RSDataPointMake(0,0);
    }
    
    avg.x = avg.x/((data_p)counter);
    avg.y = avg.y/((data_p)counter);
    
    return avg;
}

+ (RSDataPoint)centerOfGravity:(RSGroup *)G;
// Returns the center of gravity of all vertices in a group.
{
    RSVertex *V;
    RSDataPoint sum;
    int count = 0;
    
    if ( [G count] == 0 ) {
	sum.x = sum.y = 0;
	return sum;
    }
    
    sum.x = sum.y = 0;
    for (RSGraphElement *GE in [G elements])
    {
	if ( [GE isKindOfClass:[RSVertex class]] ) {
	    V = (RSVertex *)GE;
	    sum.x += [V position].x;
	    sum.y += [V position].y;
	    count++;
	}
    }
    sum.x /= count;
    sum.y /= count;
    return sum;
}

static int data_value_comparison(const void *aPtr, const void *bPtr) {
    data_p a = *(data_p *)aPtr;
    data_p b = *(data_p *)bPtr;
    
    if (a == b) {
        return 0;
    } else {
        if (a < b)
            return -1;
        else
            return 1;
    }
}

+ (RSSummaryStatistics)summaryStatisticsOfGroup:(RSGroup *)G inOrientation:(int)orientation;
// Returns the five-number summary of the data in the specified orientation, in the order: [min, firstQuartile, median, thirdQuartile, max].
{
    RSSummaryStatistics stats = {0};
    
    NSUInteger n = [G count];
    if (n < 3)
        return stats;
    
    // Create a C array with the values of interest
    data_p array[n];
    NSUInteger i = 0;
    for (RSGraphElement *element in [G elements]) {
        data_p value = dimensionOfDataPointInOrientation([element position], orientation);
        array[i] = value;
        i += 1;
    }
    
    // Sort the array in place
    qsort(array, n, sizeof(data_p), data_value_comparison);
    
//    NSMutableString *bob = [NSMutableString string];
//    for (i = 0; i < n; i+=1) {
//        [bob appendFormat:@"%f, ", array[i]];
//    }
//    NSLog(@"sorted: %@", bob);
    
    // The min and max are easy
    stats.min = array[0];
    stats.max = array[n - 1];
    
    // Calculate the median
    NSUInteger middle = n/2;
    if (n%2 == 0) {  // even number of elements
        stats.median = (array[middle - 1] + array[middle])/2.0;
    } else {
        stats.median = array[middle];
    }
    
    // Calculate the first quartile
    middle = n/4;
    if (n%4 == 0) {  // even number of elements
        stats.firstQuartile = (array[middle - 1] + array[middle])/2.0;
    } else {
        stats.firstQuartile = array[middle];
    }
    
    // Calculate the third quartile
    middle = n*3/4;
    if (n%4 == 0) {  // even number of elements
        stats.thirdQuartile = (array[middle - 1] + array[middle])/2.0;
    } else {
        stats.thirdQuartile = array[middle];
    }
    
    //NSLog(@"stats: %.3f, %.3f, %.3f, %.3f, %.3f", stats.min, stats.firstQuartile, stats.median, stats.thirdQuartile, stats.max);
    return stats;
}

// make graph element GE safe to copy and then return it
+ (RSGraphElement *)prepareForPasteboard:(RSGraphElement *)GE;
{
    // Add dependent objects to copied group
    RSGroup *G = [RSGroup groupWithGraph:[GE graph]];
    
    for (RSGraphElement *obj in [GE elements]) {
        [G addElement:obj];
        
        if ([obj isKindOfClass:[RSLine class]]) {
            [G addElement:[(RSLine *)obj vertices]];
        }
        
        else if ([obj isKindOfClass:[RSFill class]]) {
            [G addElement:[(RSFill *)obj vertices]];
        }
        
        else if ( [obj isKindOfClass:[RSTextLabel class]] ) {
            RSGraphElement *owner = [(RSTextLabel *)obj owner];
            if (owner && [owner isKindOfClass:[RSVertex class]]) {
                [G addElement:owner];
            }
        }
    }
    
    return [G shake];
}

// make graph element GE safe to paste and then return it
+ (RSGraphElement *)prepareToPaste:(RSGraphElement *)GE;
{
    RSGraph *graph = [GE graph];
    
    for (RSGraphElement *obj in [GE elements]) {
	
	RSGroup *G = [obj group];
	if (G) {
	    for (RSGraphElement *member in [[G elements] reverseObjectEnumerator]) {
		if (![GE containsElement:member]) {
		    [G removeElement:member];
		}
	    }
	}
	
	if ( [obj isKindOfClass:[RSTextLabel class]] ) {
	    // Remove reference to the owner if it's not in the pasted group
	    if ( [(RSTextLabel *)obj owner] ) {
		if( ![GE containsElement:[(RSTextLabel *)obj owner]] ) {
		    [(RSTextLabel *)obj shallowSetOwner:nil];
		}
	    }
	    [(RSTextLabel *)obj setRotation:0];  // Will be recalculated if necessary
	    [(RSTextLabel *)obj setPartOfAxis:NO];
	    [(RSTextLabel *)obj setVisible:YES];
	}
	
	else if ( [obj isKindOfClass:[RSVertex class]] ) {
	    // Remove any snapped-to references that aren't included in the pasted group, except axes
	    for (RSGraphElement *snappedTo in [[[(RSVertex *)obj snappedTo] elements] reverseObjectEnumerator]) {
		if ([snappedTo isKindOfClass:[RSAxis class]]) {
		    // Replace snappedTo with the equivalent axis on this graph
		    [(RSVertex *)obj addSnappedTo:[graph axisWithOrientation:[(RSAxis *)snappedTo orientation]] withParam:[NSNumber numberWithInt:0]];
		}
		if (![GE containsElement:snappedTo]) {
		    [(RSVertex *)obj removeSnappedTo:snappedTo];
		}
	    }
	    // Remove any parent references that aren't included in the pasted group
	    for (RSGraphElement *parent in [[(RSVertex *)obj parents] reverseObjectEnumerator]) {
		if (![GE containsElement:parent]) {
		    [(RSVertex *)obj removeParent:parent];
		}
	    }
	}
	
#ifdef OMNI_ASSERTIONS_ON
	else if ([obj isKindOfClass:[RSLine class]]) {
	    for (RSGraphElement *child in [[(RSLine *)obj vertices] elements]) {
		OBASSERT([GE containsElement:child]);
	    }
	}
	else if ([obj isKindOfClass:[RSFill class]]) {
	    for (RSGraphElement *child in [[(RSFill *)obj vertices] elements]) {
		OBASSERT([GE containsElement:child]);
	    }
	}
#endif
	
    }
    
    // return the graph element whether or not it was adjusted
    return [GE shake];
}

+ (RSGraphElement *)omitVerticesWithSomeParentsNotInGroup:(RSGraphElement *)GE;
// Returns a new group containing everything from GE except any vertices who have some parents that are included in the group and some that are not.
{
    if (![GE isKindOfClass:[RSGroup class]])
	return GE;
    
    RSGroup *group = [[GE copyWithZone:[GE zone]] autorelease];
    
    for (RSVertex *V in [(RSGroup *)GE elementsWithClass:[RSVertex class]]) {
	NSUInteger insiders = 0;
	NSUInteger outsiders = 0;
	for (RSGraphElement *parent in [V parents]) {
	    if ([group containsElement:parent])
		insiders++;
	    else
		outsiders++;
	}
	if (insiders > 0 && outsiders > 0) {
	    [group removeElement:V];
	}
    }
    
    return group;
}

+ (RSGraphElement *)elementsToDelete:(RSGraphElement *)GE;
// Also delete child vertices that won't be visible without their parent.
{
    if (!GE)
        return nil;
    
    NSMutableArray *toConsider = [NSMutableArray array];
    
    for (RSGraphElement *obj in [GE elements]) {
        if ([obj isKindOfClass:[RSLine class]]) {
            [toConsider addObjectsFromArray:[[(RSLine *)obj vertices] elements]];
        }
        else if ([obj isKindOfClass:[RSFill class]]) {
            [toConsider addObjectsFromArray:[[(RSFill *)obj vertices] elements]];
        }
    }
    if (![toConsider count])
        return GE;
    
    // Only delete the child vertices if they won't be visible
    RSGroup *toDelete = [RSGroup groupWithGraph:[GE graph]];
    for (RSVertex *V in toConsider) {
        if (![V shape]) {
            [toDelete addElement:V];
        }
    }
    if (![toDelete count])
        return GE;
    
    return [GE elementWithElement:toDelete];
}

+ (NSArray *)elementsWithPrimaryPosition:(RSGraphElement *)GE;
// Elements that have a non-calculated position value
{
    if (!GE)
        return nil;

    // turn single elements into a group
    if( ![GE isKindOfClass:[RSGroup class]] ) {
        RSGroup *group = [RSGroup groupWithGraph:[GE graph]];
        [group addElement:GE];
        
        return [RSGraph elementsWithPrimaryPosition:group];
    }

    NSMutableArray *array = [NSMutableArray array];

    for (RSGraphElement *obj in [(RSGroup *)GE elements] ) {
        if ([obj isKindOfClass:[RSVertex class]]) {
            [array addObject:obj];
        }
        else if ([obj isKindOfClass:[RSTextLabel class]]) {
            [array addObject:obj];
        }
        else if ([obj isKindOfClass:[RSAxis class]]) {
            [array addObject:obj];
        }
    }
             
    return array;
}

+ (RSGroup *)elementsToMove:(RSGraphElement *)GE;
{
    if (!GE)
        return nil;
    
    // make a new group
    RSGroup *movers = [RSGroup groupWithGraph:[GE graph]];
    
    // Special case if this is a single vertex.
    // Return the whole cluster, but only if nothing in it is locked. <bug://bugs/53616>
    if ([GE isKindOfClass:[RSVertex class]]) {
	NSArray *cluster = [(RSVertex *)GE vertexCluster];
	for (RSVertex *V in cluster) {
	    if ( [V locked] || ![V isMovable])
                return nil;
	    
	    [movers addElement:V];
	}
	return movers;
    }
    
    // turn single elements into a group
    if( ![GE isKindOfClass:[RSGroup class]] ) {
	[movers addElement:GE];
	
	return [RSGraph elementsToMove:movers];
    }
    
    for (RSGraphElement *obj in [(RSGroup *)GE elements]) {
	if ([obj isKindOfClass:[RSVertex class]]) {
	    
	    if ([(RSVertex *)obj isConstrained] || [obj locked] || ![obj isMovable])
		continue;
	    
            // Do not return vertex clusters containing any locked components. <bug://bugs/53616>
            BOOL isMovable = YES;
            for (RSVertex *V in [(RSVertex *)obj vertexSnappedTos]) {
                if ( [V locked] || ![V isMovable]) {
                    isMovable = NO;
                    break;
                }
            }
            if (!isMovable)
                continue;
            
            for (RSVertex *V in [(RSVertex *)obj vertexSnappedTos]) {
                [movers addElement:V];
            }
	}
	else if ([obj isKindOfClass:[RSLine class]]) {
	    [movers addElement:[RSGraph elementsToMove:[(RSLine *)obj vertices]]];
	    continue;
	}
	else if ([obj isKindOfClass:[RSFill class]]) {
	    [movers addElement:[RSGraph elementsToMove:[(RSFill *)obj vertices]]];
	    continue;
	}
        else if ([obj isKindOfClass:[RSTextLabel class]]) {
            if ([obj locked])
                continue;
            
            if ([[obj graph] isAxisLabel:obj])
                continue;
        }
        else if ([obj isKindOfClass:[RSAxis class]]) {
            continue;
        }
	
	// if made it this far...
	[movers addElement:obj];
    }
    
    return movers;
}




/////////////////////////////////////////////////////
#pragma mark -
#pragma mark Controller and identifier registry
/////////////////////////////////////////////////////

@synthesize undoer = _u;
- (NSUndoManager *)undoManager;
{
    return [_u undoManager];
}

@synthesize styleContext = _styleContext;
@synthesize idPasteMap = _idPasteMap;

- (NSString *)generateIdentifier;
{
    _idCounter += 1;
    return [NSString stringWithFormat:@"e%lu", _idCounter];
}
- (void)updateIdCounterFromIdentifier:(NSString *)identifier;
{
    NSScanner *scanner = [NSScanner scannerWithString:identifier];
    [scanner setCaseSensitive:YES];
    
    if (![scanner scanString:@"e" intoString:NULL])
	return;
    
    int intValue = 0;
    if (![scanner scanInt:&intValue])
	return;
    
    if (![scanner isAtEnd])
	return;
    
    // If we made it this far, we found a legitimate integer, so update the id counter.
    if ((NSUInteger)intValue > _idCounter) {
	_idCounter = intValue;
    }
}

- (void)registerNewIdentiferForObject:(id <OFXMLIdentifierRegistryObject>)object;
{
    [_idRegistry registerIdentifier:[self generateIdentifier] forObject:object];
}
- (void)registerIdentifier:(NSString *)identifier forObject:(id <OFXMLIdentifierRegistryObject>)object;
{
    OBPRECONDITION(identifier);
    
    [_idRegistry registerIdentifier:identifier forObject:object];
    [self updateIdCounterFromIdentifier:identifier];
}
- (NSString *)identiferForObject:(id <OFXMLIdentifierRegistryObject>)object;
{
    return [_idRegistry identifierForObject:object];
}
- (void)deregisterObjectWithIdentifier:(NSString *)identifier;
{
    [_idRegistry registerIdentifier:identifier forObject:nil];
}
- (id)objectForIdentifier:(NSString *)identifier;
{
    if (_idPasteMap) {
        NSString *newIdentifier = [_idPasteMap objectForKey:identifier];
        if (newIdentifier)
            identifier = newIdentifier;
    }
    
    id object = [_idRegistry objectForIdentifier:identifier];
    return object;
}
- (BOOL)containsObjectForIdentifier:(NSString *)identifier;
{
    return nil != [_idRegistry objectForIdentifier:identifier];
}
- (id)createObjectForIdentifier:(NSString *)identifier ofClass:(Class)class;
// Returns YES if the object had to be created
{
    id object = [_idRegistry objectForIdentifier:identifier];
    if (object) {
	OBASSERT([object isKindOfClass:class]);
	return object;
    }
    
    // If the object doesn't exist yet, create it and put it in the registry:
    object = [[[class alloc] initWithGraph:self identifier:identifier] autorelease];
    return object;
}




//////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate
///////////////////////////////////////////////////
@synthesize delegate = _delegate;



//////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////////////////
+ (void)initialize
{
    OBINITIALIZE;
    [self setVersion:6];
}


- (id)init;
{
    OBRejectInvalidCall(self, _cmd, @"Use initWithIdentifier: instead");
    return nil;
}

// Designated Initializer
- (id)initWithIdentifier:(NSString *)identifier undoer:(RSUndoer *)undoer;
{
    if (!(self = [super init]))
        return nil;
    
    _delegate = nil;
    
    _u = [undoer retain];
    
    _idRegistry = [[OFXMLIdentifierRegistry alloc] init];
    _idCounter = 0;
    
    _styleContext = [[OSStyleContext alloc] initWithUndoManager:[undoer undoManager] identifierRegistry:_idRegistry];
    _baseStyle = nil;
    
    Vertices = [[NSMutableArray alloc] init];
    Lines = [[NSMutableArray alloc] init];
    Labels = [[NSMutableArray alloc] init];
    Fills = [[NSMutableArray alloc] init];
    _groups = [[NSMutableArray alloc] init];
    
    _xAxis = nil;
    _yAxis = nil;
    
    // default bgcolor
    _bgColor = [[OQColor colorForPreferenceKey:@"DefaultBackgroundColor"] retain];
    
    _canvasSize = [[OFPreferenceWrapper sharedPreferenceWrapper] sizeForKey:@"LastCanvasSize"];
    _frameOrigin = frameOriginFromFrameString([[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:@"LastFrameString"]);
    
    _shadowStrength = 0;  // "off"
    
    //!_whitespace = RSMakeBorder(22, 42, 68, 74);  // Default whitespace border sizes, in pixels
    _whitespace = RSMakeBorder(2, 2, 2, 2);
    _edgePadding = RSMakeBorder(6, 6, 6, 6);
    _autoMaintainsWhitespace = YES;
    
    
    // DEPRECATED
    _IPs = [[NSMutableArray alloc] init];
    
    
    // Experimental
    _displayHistogram = NO;
    _windowAlpha = 1;
    
    return self;
}

- (void)invalidate;
{
    _delegate = nil;
    
    [_groups makeObjectsPerformSelector:@selector(invalidate)];
    [Vertices makeObjectsPerformSelector:@selector(invalidate)];
    [Lines makeObjectsPerformSelector:@selector(invalidate)];
    [Labels makeObjectsPerformSelector:@selector(invalidate)];
    [Fills makeObjectsPerformSelector:@selector(invalidate)];
    [_xAxis invalidate];
    [_yAxis invalidate];
    
    [_groups release];
    _groups = nil;
    
    [Vertices release];
    Vertices = nil;
    
    [Lines release];
    Lines = nil;
    
    [Labels release];
    Labels = nil;
    
    [Fills release];
    Fills = nil;
    
    [_xAxis release];
    _xAxis = nil;
    
    [_yAxis release];
    _yAxis = nil;
    
    [_baseStyle release];
    _baseStyle = nil;
    
    [_styleContext invalidate];
    [_styleContext release];
    _styleContext = nil;
    
    [_u release];
    _u = nil;
    
    [_idRegistry clearRegistrations];
    [_idRegistry release];
    _idRegistry = nil;
}

- (void)dealloc
{
    DEBUG_RS(@"An RSGraph is being deallocated.");
    
    [self invalidate];
    
    [_bgColor release];
    [_IPs release];
    
    [super dealloc];
}

- (void)setupDefault;
{
    _xAxis = [[RSAxis alloc] initWithGraph:self orientation:RS_ORIENTATION_HORIZONTAL];
    [self addLabel:[_xAxis title]];
    _yAxis = [[RSAxis alloc] initWithGraph:self orientation:RS_ORIENTATION_VERTICAL];
    [self addLabel:[_yAxis title]];
}



////////////////////////////////////////
#pragma mark -
#pragma mark KVO
////////////////////////////////////////
+ (NSSet *)keyPathsForValuesAffectingDisplayGrid;
// "documentExists" is the key that depends on other key paths
{
    return [NSSet setWithObjects:@"xAxis.displayGrid", @"yAxis.displayGrid", nil];
}




////////////////////////////////////////
#pragma mark -
#pragma mark Adding/removing elements from graph (including undo)
////////////////////////////////////////
- (void)addVertex:(RSVertex *)V {
    // should only add if not already in graph
    if( [Vertices containsObjectIdenticalTo:V] )
	return;
    
    [Vertices addObject:V];
    OBASSERT([Vertices containsObjectIdenticalTo:V]);
    
    if ( [V label] && ![Labels containsObjectIdenticalTo:[V label]] )
	[self addLabel:[V label]];
    
    // Set up undo:
    [_u registerUndoWithRemoveElement:V];
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Add Point", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    // if V already has a group assigned, start tracking that group
    if ([V group]) {
	[self recordGroup:[V group]];
    }
    
    // if V has a vertex cluster, reinstate the cluster
    [V addToVertexCluster];
    
    [_delegate modelChangeRequires:RSUpdateConstraints];
    
    Log2(@"Vertex added to array; size: %d", [Vertices count]);
}
- (void)removeVertex:(RSVertex *)V {
    if (![Vertices containsObjectIdenticalTo:V])
	return;
    
    // detach label if it exists
    RSTextLabel *TL = [V label];
    if (TL) {
	[TL setOwner:nil];
    }
    
    // remove vertex from parent lines, and delete the lines if necessary
    for (RSLine *L in [[V parents] objectsWithClass:[RSLine class]])
    {
        RSVertex *otherVertex = [L otherVertex:V];  // Need to get this before anything is removed
        
	//[self removeVertex:V fromLine:L];
        if ([L dropVertex:V]) {
            if ( [L isTooSmall] ) {
                if ([L label]) {
                    [self removeElement:[L label]];
                }
                [self removeLine:L];
                // Remove vertex at the other end of the line if it won't be missed
                if ([otherVertex parentCount] == 0 && [otherVertex shape] == RS_NONE) {
                    [self removeVertex:otherVertex];
                }
            }
        }
    }
    // remove vertex from any fills it's a part of:
    for (RSFill *F in [[V parents] objectsWithClass:[RSFill class]])
    {
	[self removeVertex:V fromFill:F];
	if ( [F isTwoVertices] || [F isVertex] || [F isEmpty] )
	    [self removeFill:F];
    }
    // remove from any group it's a part of
    [self setGroup:nil forElement:V];
    
    // remove from any vertex cluster it's a part of
    [V removeFromVertexCluster];
    
    // set up Undo
    [_u registerUndoWithAddElement:V];
    
    // Now, remove the vertex:
    [Vertices removeObjectIdenticalTo:V];
    
    // this comes at the end so that the [removeLine:] settings are overridden:
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Remove Point", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    [_delegate modelChangeRequires:RSUpdateConstraints];
    
    Log2(@"Vertex removed from array; size: %d", [Vertices count]);
}

- (void)addLine:(RSLine *)line
    // Adds line and any new vertices to the arrays.
{
    OBASSERT(![Lines containsObjectIdenticalTo:line]);
    OBASSERT([line class] != [RSLine class]);  // Make sure we aren't adding any old-style lines to the graph
//    if ([Lines containsObjectIdenticalTo:line])
//        return;
    
    [Lines addObject:line];
    
    // Register the line as a parent of each of its' child vertices, and add those vertices to the graph if necessary
    for (RSVertex *V in [line children])
    {
	//[V addParent:line];
	if (![Vertices containsObjectIdenticalTo:V])
	    [self addVertex:V];
    }
    
    if ( [line label] && ![Labels containsObjectIdenticalTo:[line label]] )
	[self addLabel:[line label]];
    
    [_u registerUndoWithRemoveElement:line];
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Add Line", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    if ([line group]) {
	[self recordGroup:[line group]];
    }
    
    [_delegate modelChangeRequires:RSUpdateConstraints];
    
    Log2(@"Line added to array; size: %d", [Lines count]);
}
- (void)removeLine:(RSLine *)line
{
    OBASSERT([Lines containsObjectIdenticalTo:line]);
    
    RSTextLabel *TL = [line label];
    if (TL) {
	[TL setOwner:nil];
    }
    
    NSArray *vertexArray;
    
    if ([line isKindOfClass:[RSFitLine class]]) {
	// for best-fit lines, take the start/end vertices off the graph (but leave the "data").
	[self removeVertex:[line startVertex]];
	[self removeVertex:[line endVertex]];
	
	vertexArray = [[[(RSFitLine *)line data] elements] copy];
    }
    else {
	vertexArray = [[line children] copy];
    }
    
    // Maintain parent and child pointers of remaining vertices
    for ( RSVertex *V in vertexArray)
    {
        [line dropVertex:V];
	//[self removeVertex:V fromLine:line];
    }
    [vertexArray release];
    
    
    [self unsnapVerticesFromLine:line];
    
    // remove from any group it's a part of
    [self setGroup:nil forElement:line];
    
    // Set up undo:
    [_u registerUndoWithAddElement:line];
    
    [Lines removeObjectIdenticalTo:line];
    
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Remove Line", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    [_delegate modelChangeRequires:RSUpdateConstraints];
    
    Log2(@"Line removed from array; size: %d", [Lines count]);
}
- (void)addFill:(RSFill *)fill;
{
    OBASSERT(![Fills containsObjectIdenticalTo:fill]);
    
    [Fills addObject:fill]; // note: fill gets sent a retain
    
    for (RSVertex *V in [[fill vertices] elements])
    {
	//[V addParent:fill];
	// make sure the graph knows about the vertex:
	if ( ![Vertices containsObjectIdenticalTo:V] )
	    [self addVertex:V];
    }
    
    RSTextLabel *TL = [fill label];
    if ( TL && ![Labels containsObjectIdenticalTo:TL] )
	[self addLabel:TL];
    
    // Set up undo:
    [_u registerUndoWithRemoveElement:fill];
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Create Fill", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    if ([fill group]) {
	[self recordGroup:[fill group]];
    }
    
    [_delegate modelChangeRequires:RSUpdateConstraints];
    
    Log2(@"Fill added to array; size: %d", [Fills count]);
}
- (void)removeFill:(RSFill *)fill;
{
    if (![Fills containsObjectIdenticalTo:fill]) {
        return;
    }
    
    RSTextLabel *TL = [fill label];
    if ( TL ) {
	[TL setOwner:nil];
    }
    
    // remove the fill's vertices from the fill
    NSArray *vertexArray = [[[fill vertices] elements] copy];
    for ( RSVertex *V in vertexArray)
    {
	[self removeVertex:V fromFill:fill];
	
	// also, remove vertices that have no other parents and a size of 0 (a hack to ensure that we don't remove vertices that were intended as data)
	if( [V parentCount] == 0 && [V width] == 0 ) {
	    [self removeVertex:V];
	}
    }
    [vertexArray release];
    
    // remove from any group it's a part of
    [self setGroup:nil forElement:fill];
    
    // Set up undo:
    [_u registerUndoWithAddElement:fill];
    
    [Fills removeObjectIdenticalTo:fill];
    
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Remove Fill", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    [_delegate modelChangeRequires:RSUpdateConstraints];
    
    Log2(@"Fill removed from array; size: %d", [Fills count]);
}

- (void)addLabel:(RSTextLabel *)label {
    if ([Labels containsObjectIdenticalTo:label])
	return;
    
    if ( ![label isPartOfAxis] ) {
	[Labels addObject:label];
	
	// Set up undo:
	[_u registerUndoWithRemoveElement:label];
	[_u setActionName:NSLocalizedStringFromTableInBundle(@"Add Label", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
	
	if ([label group]) {
	    [self recordGroup:[label group]];
	}
	
	Log2(@"Label added to array; size: %d", [Labels count]);
    }
    else if ( [self isAxisTitle:label] ) {
	[Labels addObject:label]; //! this might be changed
	
	[_delegate modelChangeRequires:RSUpdateWhitespace];
    }
    else {
	// presumably it's an axis tick label
	OBASSERT_NOT_REACHED("I don't think addLabel should ever get called if it's an axis tick label");
	// Set up undo:
	//[_u registerUndoWithRemoveElement:label];
	[_u setActionName:NSLocalizedStringFromTableInBundle(@"Set Custom Axis Label", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
	
	[[self axisWithOrientation:[label axisOrientation]] setUserLabel:label 
								 forTick:[label tickValue]];
	
	[_delegate modelChangeRequires:RSUpdateWhitespace];
    }
}
- (void)removeLabel:(RSTextLabel *)label {
    //NSLog(@"Graph removing label");
    
    if ( ![label isPartOfAxis] ) { // only remove if it does not belong to an axis
	OBASSERT([Labels containsObjectIdenticalTo:label]);
	
	// Set up Undo:
	[_u registerUndoWithAddElement:label];
	
	if ( [label owner] ) {
	    [label setOwner:nil];
	}
	
	// remove from any group it's a part of
	[self setGroup:nil forElement:label];
	
	[Labels removeObjectIdenticalTo:label];
	[_u setActionName:NSLocalizedStringFromTableInBundle(@"Remove Label", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
	Log2(@"Label removed from array; size: %d", [Labels count]);
    }
    else if ( [self isAxisTitle:label] ) {
	// set it to be not visible
        RSAxis *axis = [self axisOfElement:label];
        [axis setDisplayTitle:NO];
    }
    else if ( [self isAxisEndLabel:label] ) {
	//! This should really behave the same way as any axis tick label, 
	//  but min/max labels behavior is weird so it's not so simple.
	
	// "pretend" to delete by setting the string to empty
	[label setText:RS_DELETED_STRING];
	[_u setActionName:NSLocalizedStringFromTableInBundle(@"Hide Axis End Label", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
	
	[_delegate modelChangeRequires:RSUpdateWhitespace];
    }
    else {
	// it's presumably an axis tick label
	
	// if the tick label was customized, revert it to its tick value
	if( [[self axisWithOrientation:[label axisOrientation]] userLabelIsCustomForTick:[label tickValue]] ) {
	    
	    // revert the label to its tick value:
	    Log2(@"removing ticklabel with axisOrientation: %d", [label axisOrientation]);
	    [[self axisWithOrientation:[label axisOrientation]] setUserLabel:nil 
								     forTick:[label tickValue]];
	}
	// if the tick label wasn't customized, "pretend" to delete: set the string to empty
	else {
	    [label setText:RS_DELETED_STRING];
	    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Hide Axis Label", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
	}
	
	[_delegate modelChangeRequires:RSUpdateWhitespace];
    }
}

// This method does not actually delete the axis, but hides it and its numeric labels
- (void)removeAxis:(RSAxis *)axis {
    
    [axis setDisplayAxis:NO];
    [axis setDisplayTicks:NO];
    [axis setDisplayTickLabels:NO];
    
    [_u setActionName:[NSString stringWithFormat:@"Hide %@", [axis prettyName]]];
    
    [_delegate modelChangeRequires:RSUpdateWhitespace];
}

- (void)addElement:(RSGraphElement *)e {
    Log2(@"Graph adding some element");
    if ( [e isKindOfClass:[RSLine class]] ) {
	[self addLine:(RSLine *)e];
    }
    else if ( [e isKindOfClass:[RSVertex class]] ) {
	[self addVertex:(RSVertex *)e];
    }
    else if ( [e isKindOfClass:[RSTextLabel class]] ) {
	[self addLabel:(RSTextLabel *)e];
    }
    else if ( [e isKindOfClass:[RSFill class]] ) {
	[self addFill:(RSFill *)e];
    }
    else if ( [e isKindOfClass:[RSGroup class]] ) {
	for (RSGraphElement *obj in [e elements])
	{
	    [self addElement:obj];
	}
    }
}
- (void)removeElement:(RSGraphElement *)e {
    Log3(@"Graph removing some element");
    if ( [e isKindOfClass:[RSLine class]] ) {
	[self removeLine:(RSLine *)e];
    }
    else if ( [e isKindOfClass:[RSVertex class]] ) {
	[self removeVertex:(RSVertex *)e];
    }
    else if ( [e isKindOfClass:[RSTextLabel class]] ) {
	[self removeLabel:(RSTextLabel *)e];
    }
    else if ( [e isKindOfClass:[RSFill class]] ) {
	[self removeFill:(RSFill *)e];
    }
    else if ( [e isKindOfClass:[RSGroup class]] ) {
	for (RSGraphElement *obj in [e elements])
	{
	    [self removeElement:obj];
	}
    }
    else if ( [e isKindOfClass:[RSAxis class]] ) {
	[self removeAxis:(RSAxis *)e];
    }
}

//////////////////////////////////////////////////
#pragma mark -
#pragma mark Special action methods for graph elements
//////////////////////////////////////////////////

- (RSConnectLine *)connect:(RSGraphElement *)group {
    // if it's not a group, ignore
    if ( ![group isKindOfClass:[RSGroup class]] ) return nil;
    
    RSConnectLine *CL = [RSConnectLine connectLineWithGraph:self vertices:(RSGroup *)group];
    // Users will be confused if there is no line
    if( [CL connectMethod] == RSConnectNone ) {
	[CL setConnectMethod:RSConnectCurved];
    }
    [self addElement:CL];
    return CL;
}
- (void)connectCircular:(RSGroup *)group {
    // if it's not a group, ignore
    if ( ![group isKindOfClass:[RSGroup class]] ) return;
    
    // make it circular:
    [self polygonize:group];
    
    RSConnectLine *CL = [RSConnectLine connectLineWithGraph:self vertices:(RSGroup *)group];
    // Users will be confused if there is no line
    if( [CL connectMethod] == RSConnectNone ) {
	[CL setConnectMethod:RSConnectCurved];
    }
    [self addElement:CL];
}



- (RSGraphElement *)createLineWithVertices:(RSGroup *)G connectMethod:(RSConnectType)connectMethod sortSelector:(SEL)sortSelector;
// A nil sortSelector means "do not sort"
// Returns the new elements to select
{
    if ([RSFitLine supportsConnectMethod:connectMethod]) {
	// Add an RSFitLine
	RSFitLine *newLine = [self addBestFitLineFromGroup:G];
        OQColor *sharedVertexColor = [[newLine data] color];
        if (sharedVertexColor) {
            [newLine setColor:sharedVertexColor];
            RSTextLabel *equationLabel = [newLine label];
            if (equationLabel)
                [equationLabel setColor:sharedVertexColor];
        }
	return [newLine groupWithData];
    }
    else if ([RSConnectLine supportsConnectMethod:connectMethod]) {
	// Add a connectLine
        if (sortSelector) {
            [G sortElementsUsingSelector:sortSelector];
        }
	RSConnectLine *newLine = [[RSConnectLine alloc] initWithGraph:self vertices:G];
	[newLine setConnectMethod:connectMethod];
        OQColor *sharedVertexColor = [[newLine vertices] color];
        if (sharedVertexColor) {
            [newLine setColor:sharedVertexColor];
        }
	[self addElement:newLine];
	[newLine release];
	return [newLine groupWithVertices];
    }
    else {
	return G;
	//[_s setSelection:[[_s selection] elementWithElement:G]];
    }
}
- (RSGraphElement *)convertLine:(RSLine *)L toConnectMethod:(RSConnectType)connectMethod selection:(RSGraphElement *)selection;
// Returns the updated selection
{
    if (![L supportsConnectMethod:connectMethod]) {
	// Remove the existing line and select its vertices
	RSGroup *G = nil;
	if ([L isKindOfClass:[RSConnectLine class]])
	    G = [[[L vertices] copy] autorelease];
	else if ([L isKindOfClass:[RSFitLine class]]) {
	    G = [[[(RSFitLine *)L data] copy] autorelease];
	}
	
	if ([L isKindOfClass:[RSFitLine class]]) {
	    selection = [selection elementWithoutElement:[L groupWithVertices]];
	}
	else
	    selection = [selection elementWithoutElement:L];
	
	RSTextLabel *TL = [L label];
	if (TL) {
	    [self removeLabel:TL];
	}
	[self removeLine:L];
	
	RSGraphElement *newElements = [self createLineWithVertices:G connectMethod:connectMethod sortSelector:@selector(xSort:)];
	selection = [selection elementWithElement:newElements];
    }
    else {
	// The existing line already supports the new connect method, so simply change its style.
	[L setConnectMethod:connectMethod];
    }
    
    return selection;
}
- (RSGraphElement *)changeLineTypeOf:(RSGraphElement *)obj toConnectMethod:(RSConnectType)connectMethod;
{
    return [self changeLineTypeOf:obj toConnectMethod:connectMethod sort:YES];
}
- (RSGraphElement *)changeLineTypeOf:(RSGraphElement *)obj toConnectMethod:(RSConnectType)connectMethod sort:(BOOL)shouldSort;
// Returns the updated 'obj' to select
{
    RSLine *L;
    if ( (L = [RSGraph isLine:obj]) ) {
	obj = [self convertLine:L toConnectMethod:connectMethod selection:obj];
	
	if (connectMethod == RSConnectCurved || connectMethod == RSConnectStraight) {
	    // set default:
	    //[[OFPreferenceWrapper sharedPreferenceWrapper] setObject:nameFromConnectMethod(connectMethod) forKey: @"DefaultConnectMethod"];
	}
        
        return obj;
    }
    
    // A group (that's not an existing line group)
    else if ( [obj isKindOfClass:[RSGroup class]] ) {
	if ( [RSGraph isText:obj] ) {
	    // do nothing
            return obj;
	}

        // Find all the lines in the selection
        RSGroup *existingLines = [(RSGroup *)obj groupWithClass:[RSLine class]];
        
        // If lines are already in the selection, simply change their connect style
        if ( [existingLines count] ) {
            
            // If there are also vertices in the selection which are not already part of a line, and only one line is selected, then add the vertices to the selected line.
            NSArray *lines = [[obj elements] objectsWithClass:[RSLine class]];
            if ([lines count] == 1) {
                L = (RSLine *)[lines objectAtIndex:0];
                NSArray *vertices = [[obj elements] objectsWithClass:[RSVertex class]];
                for (RSVertex *V in vertices) {
                    if (![V lastParentLine]) {
                        [L insertVertex:V atIndex:[L vertexCount]];
                    }
                }
            }
            
            // Change the connect style of the lines.  This works best when done after any vertices have been added (above), so that best-fit lines are initialized with the correct range.
            for (L in [existingLines elements]) {
                obj = [self convertLine:L toConnectMethod:connectMethod selection:obj];
            }
            
            return obj;
        }
        
        // If there are no vertices selected, we're done
        if ( ![RSGraph hasMultipleVertices:obj] ) {
            return obj;
        }
        
        //
        // If we got this far, we're going to be adding new lines to the graph.
        
        // We may have to sort the component vertices:
        SEL sortSelector = nil;
        if (shouldSort) {
            sortSelector = @selector(xSort:);
        }
        
        // See if the selection consists of a set of vertex groups (if so, we want to make a separate line for each group).
        NSArray *vertices = [[(RSGroup *)obj elements] objectsWithClass:[RSVertex class]];
        NSMutableArray *groups = [NSMutableArray array];
        BOOL makeJustOneLine = NO;
        // Get the set of groups in the selection
        for (RSVertex *V in vertices) {
            RSGroup *newGroup = [V group];
            if (!newGroup) {
                makeJustOneLine = YES;
                break;
            }
            
            if ( newGroup && ![groups containsObjectIdenticalTo:newGroup] ) {
                [groups addObject:newGroup];
            }
        }
        // See if the members of the groups are all in the selection
        if (!makeJustOneLine) {
            for (RSGroup *G in groups) {
                for (RSVertex *V in [[G elements] objectsWithClass:[RSVertex class]]) {
                    if (![obj containsElement:V]) {
                        makeJustOneLine = YES;
                        break;
                    }
                }
                
                if (makeJustOneLine)
                    break;
            }
        }
        
        // If we should just make one line with all vertices in the selection, reset the groups array for that
        if (makeJustOneLine) {
            RSGroup *G = (RSGroup *)obj;
            groups = [NSMutableArray arrayWithObject:G];
        }
        
        // Finally, make a line with each group in the set of groups found.
        for (RSGroup *rawGroup in groups) {
            RSGroup *G = [rawGroup groupWithClass:[RSVertex class]];
            RSGraphElement *newElements = [self createLineWithVertices:G connectMethod:connectMethod sortSelector:sortSelector];
            obj = [obj elementWithElement:newElements];
        }
        
    }
    else {
	NSLog(@"ERROR: changeSegmentType doesn't support this context: %@", [obj class]);
    }
    
    return obj;
}

- (void)polygonize:(RSGroup *)group
// Changes the order of vertices so that it forms a polygon with no crossed lines
// It is unknown what will happen if the group contains objects besides vertices
{
    RSDataPoint center, p;
    RSVertex *V;
    data_p angle;
    
    center = [RSGraph centerOfGravity:group];
    
    // use degrees from horizontal right as the sort value
    for (RSGraphElement *G in [group elementsWithClass:[RSVertex class]])
    {
	if ( [G isKindOfClass:[RSVertex class]] ) {
	    V = (RSVertex *)G;
	    
	    p = [V position];
	    angle = atan((p.y - center.y)/(p.x - center.x));
	    // order correctly: (exact numbers don't matter, as long as order is right)
	    if ( p.x < center.x )  angle += 5;  // 2nd and 3rd quadrants
	    else if ( p.y < center.y )  angle += 10;  // 4th quadrant
	    // sort:
	    [V setSortValue:angle];
	    //NSLog(@"%f", angle);
	}
    }
    [group sortElementsUsingSelector:@selector(valueSort:)];
    
}

- (RSFitLine *)addBestFitLineFromGroup:(RSGroup *)G;
{
    if ( ![RSGraph hasMultipleVertices:G] )
	return nil;
    
    RSFitLine *FL = [[RSFitLine alloc] initWithGraph:self identifier:nil data:G];
    [self addLine:FL];
    [FL release];
    
    // add a label with equation
    RSTextLabel *TL = [[RSTextLabel alloc] initWithGraph:self];
    [TL setOwner:FL];
    [self addLabel:TL];
    [TL release];
    
    [FL setSlide:0.75f];
    [TL setFontSize:12];
    [FL updateLabel];
    
    // change the undo name appropriately:
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Create Best-Fit Line", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    return FL;
}


//- (BOOL)addVertex:(RSVertex *)V toLine:(RSLine *)L atIndex:(NSUInteger)index;
//// This method assumes the vertex is already in the graph.
//{
////    if ([[L vertices] containsElement:V])
////	return NO;
//    
//    if ([L isKindOfClass:[RSConnectLine class]]) {
//        // set up undo:
//        [_u registerUndoWithObject:L
//                            action:@"removeVertexFromLine"
//                             state:[NSArray arrayWithObjects:V, [NSNumber numberWithInteger:index], nil]
//                              name:@"Add Point to Line"];
//        
//        return [(RSConnectLine *)L addVertices:V atIndex:index];
//    }
//    else if ([L isKindOfClass:[RSFitLine class]]) {
//        return [(RSFitLine *)L insertVertex:V atIndex:index];
//    }
//    
//    return NO;  // if got this far, nothing happened.
//}
//- (BOOL)removeVertex:(RSVertex *)V fromLine:(RSLine *)L;
//{
//    // This is just for legacy unarchiving (normally, parent tracking is done in the lines/fills):
//    if ([L class] == [RSLine class]) {
//	[V removeParent:L];
//	return NO;
//    }
//    
//    if ([L isKindOfClass:[RSConnectLine class]]) {
//	NSUInteger index = [[[L vertices] elements] indexOfObjectIdenticalTo:V];
//	if (index == NSNotFound) {
//	    OBASSERT_NOT_REACHED("Vertex could not be removed from the line because the vertex was not found");
//	    return NO;
//	}
//	
//        [_u registerUndoWithObject:L
//                            action:@"addVertexToLine"
//                             state:[NSArray arrayWithObjects:V, [NSNumber numberWithInteger:index], nil]
//                              name:@"Remove Point from Line"];
//        
//        [(RSConnectLine *)L dropVertex:V];
//        return YES;
//    }
//    else if ([L isKindOfClass:[RSFitLine class]]) {
//        return [(RSFitLine *)L dropVertex:V];
//        // Undo is in the model
//    }
//    
//    return NO;
//}

- (BOOL)addVertex:(RSVertex *)V toFill:(RSFill *)F atIndex:(NSUInteger)index;
{
    if ([[F vertices] containsElement:V])
	return NO;
    
    [_u registerUndoWithObject:F
			action:@"removeVertexFromFill"
			 state:[NSArray arrayWithObjects:V, [NSNumber numberWithInteger:index], nil]
			  name:NSLocalizedStringFromTableInBundle(@"Add Point to Fill", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    // add the vertex
    BOOL returnVal = [F addVertices:V atIndex:index];
    
    return returnVal;
}
- (void)removeVertex:(RSVertex *)V fromFill:(RSFill *)F;
{
    NSUInteger index = [[[F vertices] elements] indexOfObjectIdenticalTo:V];
    if (index == NSNotFound) {
	//OBASSERT_NOT_REACHED("Vertex could not be removed from the line because the vertex was not found");
	return;
    }
    
    [_u registerUndoWithObject:F
			action:@"addVertexToFill"
			 state:[NSArray arrayWithObjects:V, [NSNumber numberWithInteger:index], nil]
			  name:NSLocalizedStringFromTableInBundle(@"Remove Point from Fill", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    [F removeVertex:V];
}




- (void)swapAxes;
{
    NSUndoManager *undoManager = [self undoManager];
    
    // swap the x- and y-axis objects
    RSAxis *temp = _xAxis;
    
    [self willChangeValueForKey:@"xAxis"];
    _xAxis = _yAxis;
    [_xAxis setOrientation:RS_ORIENTATION_HORIZONTAL];
    [self didChangeValueForKey:@"xAxis"];
    
    [self willChangeValueForKey:@"yAxis"];
    _yAxis = temp;
    [_yAxis setOrientation:RS_ORIENTATION_VERTICAL];
    [self didChangeValueForKey:@"yAxis"];
    
    // swap all x- and y-positions and swap vertical bars with horizontal
    for (RSVertex *V in [self Vertices])
    {
        RSDataPoint old = [V position];
        [V setPosition:RSDataPointMake(old.y, old.x)];
        
        // setShape: handles its own undo
        if (![undoManager isUndoing] && ![undoManager isRedoing]) {
            if( [V shape] == RS_BAR_VERTICAL )  [V setShape:RS_BAR_HORIZONTAL];
            else if ( [V shape] == RS_BAR_HORIZONTAL )  [V setShape:RS_BAR_VERTICAL];
        }
    }
    
    // swap the x/y-positions and axisOrientation of all labels
    for (RSTextLabel *TL in [self Labels]) {
	// position
	RSDataPoint old = [TL position];
	[TL setPosition:RSDataPointMake(old.y, old.x)];
	// axisOrientation
	if( [TL axisOrientation] == RS_ORIENTATION_VERTICAL ) {
	    [TL setAxisOrientation:RS_ORIENTATION_HORIZONTAL];
	}
	else if( [TL axisOrientation] == RS_ORIENTATION_HORIZONTAL ) {
	    [TL setAxisOrientation:RS_ORIENTATION_VERTICAL];
	}
    }
    
    // reset the axisOrientation of all axis tick labels
    // new horizontal axis:
    for (RSTextLabel *TL in [[_xAxis userLabelsDictionary] objectEnumerator]) {
	[TL setAxisOrientation:RS_ORIENTATION_HORIZONTAL];
    }
    // new vertical axis:
    for (RSTextLabel *TL in [[_yAxis userLabelsDictionary] objectEnumerator]){
	[TL setAxisOrientation:RS_ORIENTATION_VERTICAL];
    }
    
    // reset the length of best-fit lines
    for (RSLine *L in [self userLineElements]) {
	if ([L isKindOfClass:[RSFitLine class]]) {
	    [L recomputeNow];
	    [(RSFitLine *)L resetEndpoints];
	}
    }
    
    // set up undo
    [[undoManager prepareWithInvocationTarget:self] swapAxes];
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Swap Axes", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    [_delegate modelChangeRequires:RSUpdateWhitespace];
}

- (RSTextLabel *)makeLabelForOwner:(RSGraphElement *)GE;
{
    RSTextLabel *label = [GE label];
    if( !label ) {
	label = [[RSTextLabel alloc] initWithGraph:self];
	[label setOwner:GE];
	[self addLabel:label];
        [label release];
    }
    return label;
}

- (void)setGroup:(RSGroup *)newGroup forElement:(RSGraphElement *)GE;
// To tell the graph to make a new group with a given set of elements, do something like:
// [_graph setGroup:[RSGroup groupWithGraph:_graph] forElement:myGraphElements];
{
    OBPRECONDITION(GE);
    
    RSGroup *oldGroup = [GE group];
    
    if (oldGroup && [GE isKindOfClass:[RSGroup class]]) {
	for (RSGraphElement *element in [GE elements]) {
	    [self setGroup:newGroup forElement:element];
	}
	return;
    }
    
    if (oldGroup == newGroup)
	return;
    
    [[[self undoManager] prepareWithInvocationTarget:self] setGroup:oldGroup forElement:GE];
    
    if (oldGroup) {
	[oldGroup removeElement:GE];
	OBASSERT([_groups containsObjectIdenticalTo:oldGroup]);
	if (![oldGroup count]) {
	    [_groups removeObjectIdenticalTo:oldGroup];
	}
    }
    if (newGroup) {
	if (![newGroup count]) {
	    OBASSERT(![_groups containsObjectIdenticalTo:newGroup]);
	    [_groups addObject:newGroup];
	}
	[newGroup addElement:GE];
    }
    [GE setGroup:newGroup];
}

- (void)recordGroup:(RSGroup *)G;
{
    if (![_groups containsObject:G]) {
	[_groups addObject:G];
    }
}

- (void)unsnapVerticesFromLine:(RSLine *)L;
{
    // o(n) in the number of vertices on the graph.  necessary since lines currently don't keep track of "vertices snapped to me."
    for (RSVertex *V in Vertices) {
	[V removeSnappedTo:L];
    }
    
#ifdef DEBUG
    for (RSVertex *V in Vertices) {
        for (RSGraphElement *GE in [[V snappedTo] elements]) {
            OBASSERT(GE != L);
            OBASSERT([self containsElement:GE]);
        }
    }
#endif
}

- (void)splitUpVertex:(RSVertex *)V;
{
    if ([V parentCount] < 2)
	return;
    
    BOOL first = YES;
    for (RSGraphElement *parent in [[[V parents] copy] autorelease]) {
	if (![parent isKindOfClass:[RSLine class]] && ![parent isKindOfClass:[RSFill class]])
	    continue;
	
	OBASSERT([(RSLine *)parent containsVertex:V]);
	
	if (first) {  // Skip the first parent
	    first = NO;
	    continue;
	}
	
	RSVertex *newVertex = [[V parentlessCopy] autorelease];
	[self addVertex:newVertex];
	
	[(RSLine *)parent replaceVertex:V with:newVertex];
    }
}

- (void)detachElements:(RSGraphElement *)GE;
{
    if ([GE isKindOfClass:[RSVertex class]]) {
	[(RSVertex *)GE clearExtendedSnapTos];
	// And if necessary...
	[self splitUpVertex:(RSVertex *)GE];
    }
    else if ([GE isKindOfClass:[RSTextLabel class]]) {
	if (![GE owner])
	    return;
	
	[(RSTextLabel *)GE setOwner:nil];
    }
    else if ([GE isKindOfClass:[RSLine class]]) {
	[self detachElements:[[[(RSLine *)GE vertices] copy] autorelease]];  // Prevent mutated-while-enumerating error (splitUpVertex: can mutate the vertices array)
    }
    else if ([GE isKindOfClass:[RSFill class]]) {
	[self detachElements:[[[(RSFill *)GE vertices] copy] autorelease]];
    }
    else if ([GE isKindOfClass:[RSGroup class]]) {
	for (RSGraphElement *obj in [GE elements]) {
	    [self detachElements:obj];
	}
    }
}

- (BOOL)recomputeNow;
{
    BOOL result = NO;
    // Currently, best-fit lines are the only objects that actually respond to this
    for (RSLine *L in Lines) {
	if ([L recomputeNow])
	    result = YES;
    }
    
    return result;
}

- (RSConnectLine *)_createErrorBarFromVertices:(NSArray *)vertices color:(OQColor *)color topTick:(BOOL)topTick bottomTick:(BOOL)bottomTick;
// The "top" and "bottom" vertices are assumed to be the first and last elements in the array.
{
    OBASSERT(vertices && [vertices count] >= 2);
    OBASSERT(color);
    
    CGFloat width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultErrorBarWidth"];
    RSConnectLine *newLine = nil;
    
    // Don't need to make a line if a line already connects all of the vertices in the group
    RSLine *existingLine = [RSGraph commonParentLine:vertices];
    if (existingLine && [existingLine isKindOfClass:[RSConnectLine class]]) {
        newLine = (RSConnectLine *)existingLine;
    }
    // But normally, make a new line
    else {
        // Make the line
        RSGroup *group = [[RSGroup alloc] initWithGraph:self byCopyingArray:vertices];
        newLine = [[RSConnectLine alloc] initWithGraph:self vertices:group];
        [group release];
        [self addElement:newLine];
        
        // Set line styles
        [newLine setConnectMethod:RSConnectStraight];
        [newLine setColor:color];
        [newLine setWidth:width];
        [newLine setDash:0];
        [newLine autorelease];
    }
    
    // Set end-vertex styles
    if (topTick) {
        RSVertex *top = [vertices objectAtIndex:0];
        [top setColor:color];
        [top setShape:RS_TICKMARK];
        [top setWidth:width];
    }
    
    if (bottomTick) {
        RSVertex *bottom = [vertices lastObject];
        [bottom setColor:color];
        [bottom setShape:RS_TICKMARK];
        [bottom setWidth:width];
    }
    
    return newLine;
}

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (NSArray *)_sortedErrorBarBucket:(NSArray *)bucket;
{
    if (bucket.count < 2) {
        return bucket;
    }
    
    NSArray *sortedBucket = [bucket sortedArrayUsingSelector:@selector(yAndColorSort:)];
    
    // Special case for <bug://bugs/57966>
    if ([(RSVertex *)[sortedBucket objectAtIndex:0] position].y == [(RSVertex *)[sortedBucket objectAtIndex:1] position].y && [[[[sortedBucket objectAtIndex:0] color] colorUsingColorSpace:OQColorSpaceRGB] brightnessComponent] == 0) {
        // Swap the first and second object
        sortedBucket = [[NSArray arrayWithObjects:[sortedBucket objectAtIndex:1], [sortedBucket objectAtIndex:0], nil] arrayByAddingObjectsFromArray:[sortedBucket objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(2, [sortedBucket count] - 2)]]];
    }
    
    return sortedBucket;
}
#endif

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (RSGroup *)createErrorBarsWithSelection:(RSGraphElement *)selection;
// Returns the error bar lines that were created, if any
{
    if (![selection isKindOfClass:[RSGroup class]]) {
        // For now anyway, cannot make an error bar from just one object
        return nil;
    }
    
    // First, find all the vertical groups
    NSMutableDictionary *verticalGroups = [NSMutableDictionary dictionary];
    
    for (RSVertex *V in [(RSGroup *)selection elementsWithClass:[RSVertex class]]) {
        NSString *key = [[NSNumber numberWithDouble:[V position].x] stringValue];
        NSMutableArray *group = [verticalGroups valueForKey:key];
        if (!group) {
            group = [NSMutableArray arrayWithObject:V];
            [verticalGroups setValue:group forKey:key];
        }
        else {
            [group addObject:V];
        }
    }
    
    NSArray *sortedKeys = [[verticalGroups allKeys] sortedArrayUsingSelector:@selector(compare:)];
        
#ifdef DEBUG_RS
    NSMutableString *bucketMessage = [NSMutableString stringWithString:@"Buckets:"];
    for (NSString *key in sortedKeys) {
        //NSArray *group = [verticalGroups valueForKey:key];
        [bucketMessage appendFormat:@" %@", key];
    }
    NSLog(@"%@",bucketMessage);
#endif

    //
    // Make the error bars
    //
    RSGroup *errorLines = [RSGroup groupWithGraph:self];
    
    for (NSString *key in sortedKeys) {
        // Get the bucket of vertices at the given x-value key
        NSArray *bucket = [verticalGroups valueForKey:key];
        if ([bucket count] < 2)
            continue;
        
        NSArray *sortedBucket = [self _sortedErrorBarBucket:(NSArray *)bucket];
        OQColor *color = [[sortedBucket objectAtIndex:1] color];
        RSLine *L = [self _createErrorBarFromVertices:sortedBucket color:color topTick:YES bottomTick:YES];
        if (!L || ![L isKindOfClass:[RSLine class]]) {
            OBASSERT_NOT_REACHED("No line was created");
            continue;
        }
        [errorLines addElement:L];
    }
    
    if (![errorLines count]) {
        return nil;
    }
    
    // Group together the set of error lines (for easier manipulation of styles/etc)
    if ([errorLines count] > 1) {
        [self setGroup:[RSGroup groupWithGraph:self] forElement:errorLines];
    }
    
    [_delegate modelChangeRequires:RSUpdateDraw];
    
    // Add the endpoints of the error bars to the return group
    for (RSLine *L in [[[errorLines elements] copy] autorelease]) {
        [errorLines addElement:[L vertices]];
    }
    
    return errorLines;
}
#endif

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (RSGroup *)createConstantErrorBarsWithSelection:(RSGraphElement *)selection posOffset:(data_p)posOffset negOffset:(data_p)negOffset;
{
    OBASSERT(selection);
    
    // Ensure that all values are positive (though the interface should enforce this)
    if (posOffset < 0)
        posOffset *= -1;
    if (negOffset < 0)
        negOffset *= -1;
    
    // If no offsets were specified, we can't make error bars
    if (posOffset == 0 && negOffset == 0)  
        return nil;
    
    // Make sure selection is a group
    if (![selection isKindOfClass:[RSGroup class]]) {
        RSGroup *groupedSelection = [RSGroup groupWithGraph:self];
        [groupedSelection addElement:selection];
        selection = groupedSelection;
    }
    
    NSArray *middles = [(RSGroup *)selection elementsWithClass:[RSVertex class]];
    NSMutableArray *tops = nil;
    NSMutableArray *bottoms = nil;
    RSGroup *newComponents = [RSGroup groupWithGraph:self];
    
    // Create the tops
    if (posOffset != 0) {
        tops = [NSMutableArray arrayWithCapacity:[middles count]];
        for (RSVertex *V in middles) {
            RSVertex *newV = [V parentlessCopy];
            RSDataPoint p = [newV position];
            p.y += posOffset;
            [newV setPosition:p];
            
            [tops addObject:newV];
            [newV release];
            
            [newComponents addElement:newV];
        }
    }
    
    // Create the bottoms
    if (negOffset != 0) {
        bottoms = [NSMutableArray arrayWithCapacity:[middles count]];
        for (RSVertex *V in middles) {
            RSVertex *newV = [V parentlessCopy];
            RSDataPoint p = [newV position];
            p.y -= negOffset;
            [newV setPosition:p];
            
            [bottoms addObject:newV];
            [newV release];
            
            [newComponents addElement:newV];
        }
    }
    
    OBASSERT(tops || bottoms);
    
    // Make the lines
    for (NSUInteger i = 0; i<[middles count]; i++) {
        NSMutableArray *vertices = [NSMutableArray arrayWithCapacity:3];
        if (tops)
            [vertices addObject:[tops objectAtIndex:i]];
        [vertices addObject:[middles objectAtIndex:i]];
        if (bottoms)
            [vertices addObject:[bottoms objectAtIndex:i]];
        
        RSLine *L = [self _createErrorBarFromVertices:vertices color:[[middles objectAtIndex:i] color] topTick:(tops != nil) bottomTick:(bottoms != nil)];
        if (!L || ![L isKindOfClass:[RSLine class]]) {
            OBASSERT_NOT_REACHED("No line was created");
            continue;
        }
        [newComponents addElement:L];
    }
    
    if (![newComponents count]) {
        return nil;
    }
    
    // Group together the set of new lines and end-ticks (for easier manipulation of styles/etc)
    [self setGroup:[RSGroup groupWithGraph:self] forElement:newComponents];
    
    [_delegate modelChangeRequires:RSUpdateDraw];
    
    return newComponents;
}
#endif

- (NSArray *)importedDataPrototypes;
{
    NSMutableArray *prototypes = [NSMutableArray array];
    NSMutableSet *groupings = [NSMutableSet set];
    
    for (RSVertex *V in Vertices) {
        RSGroup *group = V.group;
        if ([groupings containsObject:group])
            continue;
        else if (group)
            [groupings addObject:group];
        
        RSLine *line = [V lastParentLine];
        if ([groupings containsObject:line])
            continue;
        else if (line)
            [groupings addObject:line];
        
        // If got this far, use the vertex as a data series prototype
        [prototypes addObject:V];
    }
    
    return prototypes;
}


////////////////////////////////////
#pragma mark -
#pragma mark Accessor methods for graph properties
////////////////////////////////////

- (OQColor *)backgroundColor;
{
    return _bgColor;
}
- (void)setBackgroundColor:(OQColor *)color;
{
    if ([color isEqual:_bgColor])
        return;
    
    NSUndoManager *undoManager = [self undoManager];
    if ([_u firstUndoWithObject:self key:@"setBackgroundColor"]) {
	[(typeof(self))[undoManager prepareWithInvocationTarget:self] setBackgroundColor:_bgColor];
    }
    if (![undoManager isUndoing]) {
	[_u setActionName:NSLocalizedStringFromTableInBundle(@"Change Background Color", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    [_bgColor autorelease];
    _bgColor = [color retain];
    
    [_delegate modelChangeRequires:RSUpdateDraw];
}

- (BOOL)isPartOfAxis {
    return YES;
}
- (BOOL)isMovable {
    return NO;
}



- (BOOL)displayAxes {
    if( [_xAxis displayAxis] || [_yAxis displayAxis] )  return YES;
    else return NO;
}
- (void)setDisplayAxes:(BOOL)flag {
    [_xAxis setDisplayAxis:flag];
    [_yAxis setDisplayAxis:flag];
}
- (BOOL)displayAxisLabels {
    if( [_xAxis displayTickLabels] || [_yAxis displayTickLabels] )  return YES;
    else return NO;
}
- (BOOL)shouldDisplayLabel:(RSGraphElement *)TL {
    return ([_xAxis shouldDisplayLabel:TL] && [_yAxis shouldDisplayLabel:TL]);
}
- (BOOL)displayAxisTicks {
    if( [_xAxis displayTicks] || [_yAxis displayTicks] )  return YES;
    else return NO;
}
- (void)setDisplayAxisTicks:(BOOL)flag {
    [_xAxis setDisplayTicks:flag];
    [_yAxis setDisplayTicks:flag];
}
- (BOOL)displayAxisTitles {
    if( [_xAxis displayTitle] || [_yAxis displayTitle] )  return YES;
    else return NO;
}
- (void)setDisplayAxisTitles:(BOOL)flag {
    [_xAxis setDisplayTitle:flag];
    [_yAxis setDisplayTitle:flag];
}
- (BOOL)noAxisComponentsAreDisplayed {
    if(    ![self displayAxes]
       && ![self displayAxisLabels]
       && ![self displayAxisTicks]
       && ![self displayAxisTitles] )  return YES;
    
    else  return NO;
}
- (BOOL)noGridComponentsAreDisplayed;
{
    return [_xAxis noGridComponentsAreDisplayed] && [_yAxis noGridComponentsAreDisplayed];
}

- (CGFloat)shadowStrength {
    return _shadowStrength;
}
- (void)setShadowStrength:(CGFloat)value;
{
    if (_shadowStrength == value)
        return;
    
    if ([_u firstUndoWithObject:self key:@"setShadow"]) {
	[[[self undoManager] prepareWithInvocationTarget:self] setShadowStrength:_shadowStrength];
    }
    
    _shadowStrength = value;
    
    [_delegate modelChangeRequires:RSUpdateDraw];
}



@synthesize whitespace = _whitespace;
- (void)setWhitespace:(RSBorder)border;
{
    if (RSEqualBorders(border, [self whitespace]))
	return;
    
    if ([_u firstUndoWithObject:self key:@"setWhitespace"]) {
	[[[self undoManager] prepareWithInvocationTarget:self] setWhitespace:_whitespace];
    }
    
    _whitespace = border;
    
    [_delegate modelChangeRequires:RSUpdateWhitespace];
}

@synthesize autoMaintainsWhitespace = _autoMaintainsWhitespace;
- (void)setAutoMaintainsWhitespace:(BOOL)flag;
{
    if (flag == _autoMaintainsWhitespace)
	return;
    
    [[[self undoManager] prepareWithInvocationTarget:self] setWhitespace:_whitespace];
    [[[self undoManager] prepareWithInvocationTarget:self] setAutoMaintainsWhitespace:_autoMaintainsWhitespace];
    
    _autoMaintainsWhitespace = flag;
    
    [_delegate modelChangeRequires:RSUpdateWhitespace];
}

@synthesize edgePadding = _edgePadding;

@synthesize frameOrigin = _frameOrigin;

- (CGSize)canvasSize {
    return _canvasSize;
}
- (void)setCanvasSize:(CGSize)size {
    if (CGSizeEqualToSize(size, _canvasSize))
	return;
    
    if ([_u firstUndoWithObject:self key:@"setCanvasSize"]) {
	[[[self undoManager] prepareWithInvocationTarget:self] setCanvasSize:_canvasSize];
    }
    
    _canvasSize = size;
    
    [_delegate modelChangeRequires:RSUpdateWhitespace];
}
- (CGSize)minCanvasSize;
// The minimum canvas size depends on the size of the whitespace
{
    RSBorder whitespace = [self whitespace];
    CGSize size;
    size.width = RSMinGraphSize.width + whitespace.left + whitespace.right;
    size.height = RSMinGraphSize.height + whitespace.top + whitespace.bottom;
    
    return size;
}
- (CGSize)sizeOfGraphRect;
{
    CGSize size = [self canvasSize];
    RSBorder whitespace = [self whitespace];
    size.width -= whitespace.left + whitespace.right;
    size.height -= whitespace.top + whitespace.bottom;
    
    return size;
}
- (CGSize)potentialWhitespaceExpansionSize;
{
    CGSize graphSize = [self sizeOfGraphRect];
    CGSize expandSize;
    expandSize.height = graphSize.height - RSMinGraphSize.height;
    expandSize.width = graphSize.width - RSMinGraphSize.width;
    
    return expandSize;
}

////////////////////////////////////
#pragma mark -
#pragma mark Graph element accessor methods
////////////////////////////////////
- (NSArray *)Lines {
    return Lines;
}
- (NSMutableArray *)Vertices {
    return Vertices;
}
- (NSArray *)Labels {
    return Labels;
}
- (NSArray *)userLabels;
{
    NSMutableArray *A = [NSMutableArray arrayWithCapacity:[Labels count]];
    for (RSTextLabel *TL in Labels) {
        if( ![TL isPartOfAxis] )
            [A addObject:TL];
    }
    return A;
}
- (NSArray *)allLabels;
{
    NSMutableArray *A = [NSMutableArray arrayWithArray:Labels];
    [A addObjectsFromArray:[[_xAxis userLabelsDictionary] allValues]];
    [A addObjectsFromArray:[[_yAxis userLabelsDictionary] allValues]];
    return A;
}
// Returns a new array that holds the strings in each label
// This is used by the Graph Sketcher Metadata Importer
- (NSMutableArray *)labelsAsStrings {
    NSMutableArray *A;
    RSTextLabel *TL;
    
    A = [NSMutableArray array];
    for (TL in Labels) {
	[A addObject:[TL text]];
    }
    return A;
}
- (NSArray *)Fills {
    return Fills;
}
- (NSArray *)groups;
{
    return _groups;
}

- (RSGroup *)userElements {
    NSMutableArray *A = [NSMutableArray array];
    
    [A addObjectsFromArray:[self userLineElements]];
    [A addObjectsFromArray:Vertices];
    [A addObjectsFromArray:Fills];
    for (RSTextLabel *TL in Labels) {
	if( ![TL isPartOfAxis] )  [A addObject:TL];
    }
    
    if (![A count])
	return nil;
    
    RSGroup *G = [[[RSGroup alloc] initWithGraph:self identifier:nil elements:A] autorelease];
    return G;
}

- (RSGroup *)userVertexElements;
{
    if (![Vertices count])
	return nil;
    
    RSGroup *G = [[[RSGroup alloc] initWithGraph:self byCopyingArray:Vertices] autorelease];
    return G;
}
- (NSArray *)userLineElements;
{
    // Don't display or hit-test best-fit lines in log space
    if ([self hasLogarithmicAxis] && [Lines count]) {
        NSMutableArray *array = [NSMutableArray array];
        for (RSGraphElement *GE in Lines) {
            if ([GE isKindOfClass:[RSFitLine class]])
                continue;
            
            [array addObject:GE];
        }
        return array;
    }
    
    return [[Lines copy] autorelease];
}
- (RSGraphElement *)userFillElements;
{
    RSGroup *G = [[[RSGroup alloc] initWithGraph:self byCopyingArray:Fills] autorelease];
    return [G shake];
}
- (RSGraphElement *)allLabelElements;
{
    RSGroup *G = [[[RSGroup alloc] initWithGraph:self byCopyingArray:[self allLabels]] autorelease];
    return G;
}

- (RSGroup *)fitLineElements {
    RSGraphElement *obj;
    NSMutableArray *A = [[[NSMutableArray alloc] init] autorelease];
    
    for (obj in Lines) {
	if ( [obj isKindOfClass:[RSFitLine class]] ) [A addObject:obj];
    }
    return [[[RSGroup alloc] initWithGraph:self identifier:nil elements:A] autorelease];
}

- (RSGroup *)dataVertices;
{
    NSMutableArray *data = [NSMutableArray array];
    
    for (RSVertex *V in Vertices) {
        if ([V shape]) {
            [data addObject:V];
        }
    }
    
    RSGroup *G = [[[RSGroup alloc] initWithGraph:self byCopyingArray:data] autorelease];
    return G;
}

- (RSGraphElement *)elementsConnectedTo:(RSGraphElement *)root;
{
    // The RSGroup will keep getting objects added to it:
    RSGroup *G = [[[RSGroup alloc] initWithGraph:self] autorelease];
    // The queue will add and remove objects until it is emptied:
    NSMutableArray *Q = [NSMutableArray arrayWithArray:[root elements]];
    
    RSGraphElement *obj;	// object currently being checked
    NSArray *A;  // current connected elements array
    
    while ( [Q count] > 0 ) {
	obj = [Q objectAtIndex:0];
	[Q removeObjectAtIndex:0];
	
	if ( [G addElement:obj] ) {  // if current element has not been seen
	    if( [obj isKindOfClass:[RSTextLabel class]] 
	       && [self isAxisTickLabel:(RSTextLabel *)obj] ) {
		A = [[[self axisOfElement:obj] visibleUserLabels] elements];
	    }
	    else {
		A = [obj connectedElements];
	    }
	    [Q addObjectsFromArray:A];
	}
    }
    
    return [G shake];
}

- (RSGraphElement *)graphElementFromArray:(NSArray *)elements;
{
    if (![elements count])
        return nil;
    
    if ([elements count] == 1)
        return [elements objectAtIndex:0];
    
    RSGroup *G = [[[RSGroup alloc] initWithGraph:self byCopyingArray:elements] autorelease];
    return [G shake];
}


- (BOOL)is:(RSGraphElement *)one above:(RSGraphElement *)two {
    NSUInteger i1, i2;
    
    if ( [one isKindOfClass:[RSLine class]] ) {
	if ( [two isKindOfClass:[RSLine class]] ) {
	    i1 = [Lines indexOfObjectIdenticalTo:one];
	    i2 = [Lines indexOfObjectIdenticalTo:two];
	    if ( i1 > i2 )  return YES;
	    else  return NO;
	}
	else if ( [two isKindOfClass:[RSFill class]] ) {
	    return YES;	// lines are always above fills
	}
	else {
	    NSLog(@"Unsupported class in RSGraph is:above:");
	    return NO;
	}
    }
    else if ( [one isKindOfClass:[RSFill class]] ) {
	if ( [two isKindOfClass:[RSLine class]] ) {
	    return NO;	// lines are always above fills
	}
	else if ( [two isKindOfClass:[RSFill class]] ) {
	    i1 = [Fills indexOfObjectIdenticalTo:one];
	    i2 = [Fills indexOfObjectIdenticalTo:two];
	    if ( i1 > i2 )  return YES;
	    else  return NO;
	}
	else {
	    NSLog(@"Unsupported class in RSGraph is:above:");
	    return NO;
	}
    }
    else {
	NSLog(@"Unsupported class in RSGraph is:above:");
	return NO;
    }
}


- (RSLine *)lineConnectingVertex:(RSVertex *)V1 andVertex:(RSVertex *)V2
// Returns the first line found connecting V1 and V2, or nil if there is none
{
    for (RSLine *L in [[V1 parents] objectsWithClass:[RSLine class]])
    {
	//Log2(@"considering line: %@", [L stringRepresentation]);//[V1 stringRepresentation], [V2 stringRepresentation]);
	if( [V2 isParent:L] ) {
	    //Log2(@"found connecting line: %@", [L stringRepresentation]);//[V1 stringRepresentation], [V2 stringRepresentation]);
	    return L;
	}
    }
    // if got this far...
    return nil;
}


///////////////////////////////////////////////
#pragma mark -
#pragma mark Axis accessor methods
//////////////////////////////////////////////
- (RSAxis *)xAxis{
    return _xAxis;
}
- (RSAxis *)yAxis{
    return _yAxis;
}
- (RSAxis *)axisWithOrientation:(int)orientation {
    if( orientation == RS_ORIENTATION_HORIZONTAL )  return _xAxis;
    else if( orientation == RS_ORIENTATION_VERTICAL )  return _yAxis;
    else  return nil; // no axis found
}
- (RSAxis *)axisWithAxisEnd:(RSAxisEnd)axisEnd {
    if (axisEnd == RSAxisXMin || axisEnd == RSAxisXMax)
        return _xAxis;
    else if (axisEnd == RSAxisYMin || axisEnd == RSAxisYMax)
        return _yAxis;
    else
        return nil;
}
- (RSAxis *)otherAxis:(RSAxis *)A {
    if( [A orientation] == RS_ORIENTATION_HORIZONTAL )  return _yAxis;
    if( [A orientation] == RS_ORIENTATION_VERTICAL )  return _xAxis;
    else  return nil; // no axis found
}

- (RSAxis *)axisOfElement:(RSGraphElement *)GE {
    // returns the axis related to GE, or nil if no axis is associated with GE
    
    if ( GE == _xAxis )  return _xAxis;
    if ( GE == _yAxis )  return _yAxis;
    else if ( [GE isKindOfClass:[RSTextLabel class]] ) {
	if( [GE axisOrientation] == RS_ORIENTATION_HORIZONTAL )
	    return _xAxis;
	else if( [GE axisOrientation] == RS_ORIENTATION_VERTICAL )
	    return _yAxis;
	if ( GE == [_xAxis title] )
	    return _xAxis;
	else if ( GE == [_yAxis title] )
	    return _yAxis;
    }
    // all-encompassing else
    return nil;
}

static void _replaceAxis(RSGraph *self, RSAxis **axis, RSAxis *newAxis)
{
    if (*axis == newAxis)
        return;
    
    if (*axis) {
	[self removeLabel:[*axis title]];
        [*axis release];
        *axis = nil;
    }
    
    if (newAxis) {
        *axis = [newAxis retain];
        [self addLabel:[newAxis title]];
    }
}

- (void)setAxis:(RSAxis *)newAxis forOrientation:(int)orientation;
{
    if (orientation == RS_ORIENTATION_HORIZONTAL)
        _replaceAxis(self, &_xAxis, newAxis);
    else if (orientation == RS_ORIENTATION_VERTICAL)
        _replaceAxis(self, &_yAxis, newAxis);
    else
	OBASSERT_NOT_REACHED("Unsupported orientation");
}
- (data_p)xMin {
    return [_xAxis min];
}
- (data_p)xMax {
    return [_xAxis max];
}
- (data_p)yMin {
    return [_yAxis min];
}
- (data_p)yMax {
    return [_yAxis max];
}
- (void)setXMin:(data_p)value {
    [self setMin:value forAxis:_xAxis];
}
- (void)setXMax:(data_p)value {
    [self setMax:value forAxis:_xAxis];
}
- (void)setYMin:(data_p)value {
    [self setMin:value forAxis:_yAxis];
}
- (void)setYMax:(data_p)value {
    [self setMax:value forAxis:_yAxis];
}
- (void)setMin:(data_p)value forAxis:(RSAxis *)axis userModified:(BOOL)userModified;
{
    if (userModified) {
        [axis setUserModifiedRange:YES];
    }
    
    if ( value >= [axis max] ) {
        [axis setMax:([axis max] + value - [axis min])];
        [axis setMin:value];
        //[_u setActionName:[NSString stringWithFormat:@"Set %@ Range", [axis prettyName]]];
    } else {
        [axis setMin:value];
        //[_u setActionName:[NSString stringWithFormat:@"Set %@ Min", [axis prettyName]]];
    }
}
- (void)setMin:(data_p)value forAxis:(RSAxis *)axis;
{
    [self setMin:value forAxis:axis userModified:YES];
}
- (void)setMax:(data_p)value forAxis:(RSAxis *)axis userModified:(BOOL)userModified;
{
    if (userModified) {
        [axis setUserModifiedRange:YES];
    }
    
    if ( value <= [axis min] ) {
        [axis setMin:([axis min] + value - [axis max])];
        [axis setMax:value];
        //[_u setActionName:[NSString stringWithFormat:@"Set %@ Range", [axis prettyName]]];
    }
    else {
        [axis setMax:value];
        //[_u setActionName:[NSString stringWithFormat:@"Set %@ Max", [axis prettyName]]];
    }
}
- (void)setMax:(data_p)value forAxis:(RSAxis *)axis;
{
    [self setMax:value forAxis:axis userModified:YES];
}

- (void)setAxisRangesXMin:(data_p)xmin xMax:(data_p)xmax yMin:(data_p)ymin yMax:(data_p)ymax;
{
    [self setMin:xmin forAxis:_xAxis userModified:NO];
    [self setMax:xmax forAxis:_xAxis userModified:NO];
    [self setMin:ymin forAxis:_yAxis userModified:NO];
    [self setMax:ymax forAxis:_yAxis userModified:NO];
    
    [_u setActionName:NSLocalizedStringFromTableInBundle(@"Set Axis Range", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
}
- (BOOL)prepareUndoForAxisRanges;
{
    if ([[self undoer] firstUndoWithObject:self key:@"setAxisRanges"]) {
        
        [[_xAxis minLabel] prepareUndoForAttributedString];
        [[_xAxis maxLabel] prepareUndoForAttributedString];
        [[_yAxis minLabel] prepareUndoForAttributedString];
        [[_yAxis maxLabel] prepareUndoForAttributedString];
        
        [[[self undoManager] prepareWithInvocationTarget:self] setAxisRangesXMin:[self xMin] xMax:[self xMax] yMin:[self yMin] yMax:[self yMax]];
        
        [_u setActionName:NSLocalizedStringFromTableInBundle(@"Set Axis Range", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
        
        return YES;
    }
    return NO;
}

- (BOOL)hasLogarithmicAxis;
{
    return ([_xAxis axisType] == RSAxisTypeLogarithmic || [_yAxis axisType] == RSAxisTypeLogarithmic);
}

- (RSAxisPlacement)axisPlacement;
{
    return [_xAxis placement];
}
- (void)setAxisPlacement:(RSAxisPlacement)placement;
{
    [_xAxis setPlacement:placement];
    [_yAxis setPlacement:placement];
}


- (BOOL)isAxisTitle:(RSTextLabel *)TL {
    if ( TL == [[self xAxis] title] 
	|| TL == [[self yAxis] title] ) {
	return YES;
    }
    else  return NO;
}
- (BOOL)isAxisTickLabel:(RSGraphElement *)TL {
    if (![TL isKindOfClass:[RSTextLabel class]])
        return NO;
    
    // all tick labels are part of the axis:
    if( ![TL isPartOfAxis] )  return NO;
    
    // if part of axis, make sure it's a tick label:
    if( [TL axisOrientation] == RS_ORIENTATION_HORIZONTAL
       || [TL axisOrientation] == RS_ORIENTATION_VERTICAL
       || TL == [_xAxis minLabel] || TL == [_xAxis maxLabel]
       || TL == [_yAxis minLabel] || TL == [_yAxis maxLabel]) {
	return YES;
    }
    else return NO;
}
- (BOOL)isAxisEndLabel:(RSGraphElement *)TL {
    if( TL == [_xAxis minLabel] || TL == [_xAxis maxLabel]
       || TL == [_yAxis minLabel] || TL == [_yAxis maxLabel] ) {
	return YES;
    }
    else  return NO;
}
- (BOOL)isDragResizer:(RSGraphElement *)GE forAxis:(RSAxis *)A {  // used in [RSGraphView mouseDragged]
    if( GE == A )  return YES;
    if( ![GE isPartOfAxis] || ![GE isKindOfClass:[RSTextLabel class]] )  return NO;
    if( [A orientation] == [GE axisOrientation] || GE == [A minLabel] || GE == [A maxLabel] ) {
	return YES;
    }
    else  return NO;
}
- (BOOL)isAxisLabel:(RSGraphElement *)TL;
{
    if ([TL isKindOfClass:[RSTextLabel class]] && [self axisOfElement:TL])  return YES;
    else  return NO;
}

- (data_p)tickValueOfAxisEnd:(RSAxisEnd)axisEnd;
{
    switch (axisEnd) {
        case RSAxisXMin:
            return [self xMin];
            break;
        case RSAxisXMax:
            return [self xMax];
            break;
        case RSAxisYMin:
            return [self yMin];
            break;
        case RSAxisYMax:
            return [self yMax];
            break;
        default:
            break;
    }
    
    return 0;
}

- (void)hideEndLabelsForAxis:(RSAxis *)A;
{
    if( !A )  return;
    
    // "pretend" to delete by setting the strings to empty
    [[A minLabel] setText:RS_DELETED_STRING];
    [[A maxLabel] setText:RS_DELETED_STRING];
    
    //[self setUserString:RS_DELETED_STRING forTick:_min];
    //[self setUserString:RS_DELETED_STRING forTick:_max];
}

- (void)displayTicksIfNecessaryOnAxis:(RSAxis *)axis;
{
    if (![axis displayTicks] && ![axis displayTickLabels] && ![[self otherAxis:axis] displayGrid])
	[axis setDisplayTicks:YES];
}


////////////////////////////////////////
#pragma mark -
#pragma mark Grid accessor methods
////////////////////////////////////////

- (RSGrid *)xGrid {
    return [_xAxis grid];
}
- (RSGrid *)yGrid {
    return [_yAxis grid];
}
- (BOOL)displayGrid {
    if( [_xAxis displayGrid] || [_yAxis displayGrid] ) {
	return YES;
    }
    else  return NO;
}
- (BOOL)displayBothGrids {
    if( [_xAxis displayGrid] && [_yAxis displayGrid] ) {
	return YES;
    }
    else  return NO;
}
- (BOOL)bothGridsAreEvenlySpaced;
{
    return ([_xAxis axisType] == RSAxisTypeLinear && [_yAxis axisType] == RSAxisTypeLinear);
}
- (void)setDisplayGrid:(BOOL)flag {
    [_xAxis setDisplayGrid:flag];
    [_yAxis setDisplayGrid:flag];
}
- (void)displayGridIfNotAlready {
    // only do something if both grids are off
    if ( ![self displayGrid] ) {
	[self setDisplayGrid:YES];
    }
}
- (CGFloat)gridWidth {
    // TODO: make this better
    return [[_xAxis grid] width];
}
- (void)setGridWidth:(CGFloat)width;
{
    if ([_u firstUndoWithObject:self key:@"setGridWidth"]) {
	[[[self undoManager] prepareWithInvocationTarget:self] setGridWidth:[[_xAxis grid] width]];
        [_u setActionName:NSLocalizedStringFromTableInBundle(@"Change Grid Width", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    [[_xAxis grid] setWidth:width];
    [[_yAxis grid] setWidth:width];
    
    [_delegate modelChangeRequires:RSUpdateDraw];
}
- (OQColor *)gridColor {
    return [[_xAxis grid] color];
}
- (void)setGridColor:(OQColor *)newColor;
{
    if ([_u firstUndoWithObject:self key:@"setGridColor"]) {
	[(typeof(self))[[self undoManager] prepareWithInvocationTarget:self] setGridColor:[self gridColor]];
        [[self undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Grid Color", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    [[_xAxis grid] setColor:newColor];
    [[_yAxis grid] setColor:newColor];
    
    [_delegate modelChangeRequires:RSUpdateDraw];
}


////////////////////////////////////////
#pragma mark -
#pragma mark Number formatting
////////////////////////////////////////

- (NSString *)stringForDataValue:(data_p)val inDimension:(int)orientation;
{
    return [[self axisWithOrientation:orientation] formattedDataValue:val];
}

- (NSString *)infoStringForPoint:(RSDataPoint)p;
{
    return [NSString stringWithFormat:@"(%@, %@)",
            [self stringForDataValue:p.x inDimension:RS_ORIENTATION_HORIZONTAL],
            [self stringForDataValue:p.y inDimension:RS_ORIENTATION_VERTICAL]];
}



////////////////////////////////////////
#pragma mark -
#pragma mark For debugging and legacy unarchiving
////////////////////////////////////////

- (BOOL)containsElement:(RSGraphElement *)GE;
{
    OBASSERT([GE isKindOfClass:[RSGraphElement class]]);
    
    if ([GE isKindOfClass:[RSVertex class]]) {
	if ([Vertices containsObjectIdenticalTo:GE])  return YES;
    }
    if ([GE isKindOfClass:[RSLine class]]) {
	if ([Lines containsObjectIdenticalTo:GE])  return YES;
    }
    if ([GE isKindOfClass:[RSFill class]]) {
	if ([Fills containsObjectIdenticalTo:GE])  return YES;
    }
    if ([GE isKindOfClass:[RSTextLabel class]]) {
	if ([Labels containsObjectIdenticalTo:GE])  return YES;
    }
    if ([GE isKindOfClass:[RSGroup class]]) {
	if ([_groups containsObjectIdenticalTo:GE])  return YES;
    }
    if ([GE isKindOfClass:[RSAxis class]]) {
	if (GE == _xAxis || GE == _yAxis)  return YES;
    }
    
    return NO;
}


////////////////////////////////////////
#pragma mark -
#pragma mark Experimental features
////////////////////////////////////////
- (BOOL)displayHistogram {
    return _displayHistogram;
}
- (void)setDisplayHistogram:(BOOL)flag {
    _displayHistogram = flag;
}


////////////////////////////////////////
#pragma mark -
#pragma mark Other app properties
////////////////////////////////////////

@synthesize windowAlpha = _windowAlpha;

@synthesize tufteEasterEgg = _tufteEasterEgg;


@end

/*
 @implementation NSApplication (GraphCategory)
 
 - (NSArray *)graphs {
 NSArray *docs = [self orderedDocuments];
 NSMutableArray *graphs = [NSMutableArray array];
 NSEnumerator *E = [docs objectEnumerator];
 id doc;
 while( doc=[E nextObject] ) {
 [graphs addObject:[doc graph]];
 }
 return graphs;
 }
 
 @end
 */
