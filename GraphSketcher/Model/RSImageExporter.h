// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSImageExporter.h 200244 2013-12-10 00:11:55Z correia $

// RSImageExporter is designed to more or less mimic Graffle's convenient image exporting classes.

#import <GraphSketcherModel/RSGraph.h>

@class RSDataMapper, RSGraphRenderer;

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
@class UIImage;
#endif

@interface RSImageExporter : NSObject
{
@private
    RSGraph *_graph;
    RSDataMapper *_mapper;
    RSGraphRenderer *_renderer;
    
    CGSize _exportSize;
    BOOL _shouldInvalidateGraphWhenDone;
}

+ (RSImageExporter *)imageExporterForURL:(NSURL *)url error:(NSError **)outError;
- (id)initWithGraph:(RSGraph *)graph;

@property (assign,nonatomic) CGSize exportSize;
- (void)setMaxDimension:(CGFloat)length;

- (void)drawGraph;

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (UIImage *)makeImage;
- (UIImage *)makeImageForPreview;
#endif

- (NSData *)pngRepresentation;
- (NSData *)pdfRepresentation;

@end
