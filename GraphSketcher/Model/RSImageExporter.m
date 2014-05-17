// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSImageExporter.h"

#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSEquationLine.h>
#import <OmniQuartz/OQColor.h>

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#import <OmniQuartz/OQDrawing.h>
#else
#import <AppKit/NSImage.h>
#endif

#import "RSUndoer.h"

@implementation RSImageExporter

+ (NSUndoManager *)undoManager;
{
    static NSUndoManager *undoManager = nil;
    if (undoManager == nil) {
        undoManager = [[NSUndoManager alloc] init];
        [undoManager disableUndoRegistration];
    }
    return undoManager;
}

+ (void)undoerPerformedChange:(RSUndoer *)undoer;
{
}

+ (RSImageExporter *)imageExporterForURL:(NSURL *)url error:(NSError **)outError;
{
    OBPRECONDITION(url);

    RSUndoer *undoer = [[[RSUndoer alloc] initWithOwner:(id)self] autorelease];
    RSGraph *graph = [RSGraph graphFromURL:url type:RSGraphFileType undoer:undoer error:outError];
    if (!graph)
        return nil;
    
    return [[[RSImageExporter alloc] initWithGraph:graph invalidateWhenDone:YES] autorelease];
}

- (id)initWithGraph:(RSGraph *)graph;
{
    return [self initWithGraph:graph invalidateWhenDone:NO];
}

- (id)initWithGraph:(RSGraph *)graph invalidateWhenDone:(BOOL)shouldInvalidate;
{
    OBPRECONDITION(graph);
    
    if (!(self = [super init]))
        return nil;
    
    _graph = [graph retain];
    _shouldInvalidateGraphWhenDone = shouldInvalidate;
    
    _mapper = [[RSDataMapper alloc] initWithGraph:_graph];
    _renderer = [[RSGraphRenderer alloc] initWithMapper:_mapper];
    
    self.exportSize = _graph.canvasSize;
    
    return self;
}

- (void)dealloc;
{
    [_renderer release];
    [_mapper release];
    
    if(_shouldInvalidateGraphWhenDone)
        [_graph invalidate];
    [_graph release];
    
    [super dealloc];
}

@synthesize exportSize=_exportSize;

- (void)setMaxDimension:(CGFloat)length;
{
    CGFloat fraction = 0;
    CGSize canvasSize = _graph.canvasSize;
    if (canvasSize.width > canvasSize.height) {
        fraction = length/canvasSize.width;
    } else {
        fraction = length/canvasSize.height;
    }
    
    self.exportSize = CGSizeMake(canvasSize.width*fraction, canvasSize.height*fraction);
}

- (void)updateLayout;
{
    OBPRECONDITION(_mapper);
    OBPRECONDITION(_renderer);
    
    CGRect bounds = CGRectZero;
    bounds.size = _graph.canvasSize;
    [_mapper setBounds:bounds];
    
    [_mapper mappingParametersDidChange];
    [_renderer updateWhitespace];
    [_mapper mappingParametersDidChange];
    
    // update the axis labels:
    [_renderer positionAllAxisLabels];
    
    // Update equation lines
    for (RSLine *L in [_graph Lines]) {
        if ([L isKindOfClass:[RSEquationLine class]]) {
            [L setNeedsRecompute];
        }
    }
    
    // These shouldn't change as long as we don't change the canvas size
    //[self updateConstrainedElements];
    
    [_renderer invalidateCache];
    
    // update positions of attached labels:
    for (RSTextLabel *T in [_graph Labels]) {
        if ([T owner])
            [_renderer positionLabel:nil forOwner:[T owner]];
    }
}

- (void)drawGraph;
{
    [self updateLayout];
    
    // Draw the graph background and grid lines
    OQColor *backgroundColor = [[_graph backgroundColor] colorUsingColorSpace:OQColorSpaceRGB];
    [_renderer drawBackgroundWithColor:backgroundColor];
    
    // Draw all of the normal graph objects
    [_renderer drawAllGraphElementsExcept:nil];
}


// iOS methods
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE

- (UIImage *)makeImage;
{
    CGSize exportSize = self.exportSize;
    CGFloat scale = exportSize.width/_graph.canvasSize.width;
    
    UIImage *image;
    UIGraphicsBeginImageContextWithOptions(exportSize, NO, 1.0);
    {
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        
        OQFlipVerticallyInRect(ctx, CGRectMake(0, 0, exportSize.width, exportSize.height));
        CGContextScaleCTM(ctx, scale, scale);
        
        [self drawGraph];
        
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    return image;
}

- (UIImage *)makeImageForPreview;
{
    CGSize exportSize = self.exportSize;
    CGFloat scaleWidth = exportSize.width/_graph.canvasSize.width;
    CGFloat scaleHeight = exportSize.height/_graph.canvasSize.height;
    
    CGFloat scale;
    CGFloat xOffset;
    CGFloat yOffset;
    
    // scale so that we take up either the full width or the full height, without clipping
    // offset is to center the scaled graph within the preview image
    if(scaleWidth < scaleHeight) {
        scale = scaleWidth;
        xOffset = 0;
        yOffset = (exportSize.height - (_graph.canvasSize.height * scale)) / 2;
    }
    else {
        scale = scaleHeight;
        xOffset = (exportSize.width - (_graph.canvasSize.width * scale)) / 2;
        yOffset = 0;
    }
    
    UIImage *image;
    UIGraphicsBeginImageContextWithOptions(exportSize, YES, 1.0);
    {
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        
        [[[_graph backgroundColor] colorUsingColorSpace:OQColorSpaceRGB] set];
        CGContextFillRect(ctx, CGRectMake(0, 0, exportSize.width, exportSize.height));
        
        OQFlipVerticallyInRect(ctx, CGRectMake(0, 0, exportSize.width, exportSize.height));
        CGContextTranslateCTM(ctx, xOffset, yOffset);   // center the graph within the preview image
        CGContextScaleCTM(ctx, scale, scale);
        
        [self drawGraph];
        
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    return image;
}

- (NSData *)pngRepresentation;
{
    UIImage *image = [self makeImage];
    NSData *pngData = UIImagePNGRepresentation(image);
    return pngData;
}

- (NSData *)pdfRepresentation;
{
    CGRect bounds = CGRectZero;
    bounds.size = self.exportSize;
    
    NSMutableData *pdfData = [[NSMutableData alloc] init];
    UIGraphicsBeginPDFContextToData(pdfData, bounds, nil);
    UIGraphicsBeginPDFPageWithInfo(bounds, nil);
    
    OQFlipVerticallyInRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, self.exportSize.width, self.exportSize.height));    

    [self drawGraph];
    
    UIGraphicsEndPDFContext();
    
    return [pdfData autorelease];
}

// Mac OS methods
#else
- (CGImageRef)imageFromGraph;
{
    CGRect bounds = CGRectZero;
    bounds.size = self.exportSize;
    
    // Draw into an NSImage context (based on example code in Cocoa Drawing Guide)
    NSImage* image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
    [image lockFocus];
    
    [self drawGraph];
    
    [image unlockFocus];
    
    return [image CGImageForProposedRect:&bounds context:NULL hints:nil];
}

- (NSData *)pngRepresentation;
{
    CGRect bounds = CGRectZero;
    bounds.size = self.exportSize;
    
    CGImageRef cgimage = [self imageFromGraph];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgimage];
    NSData *imgData = [bitmapRep representationUsingType:NSPNGFileType properties:
		       [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:NSImageInterlaced]];
    [bitmapRep release];
    return imgData;
}

- (NSData *)pdfRepresentation;
{
    return nil;
}
#endif


@end
