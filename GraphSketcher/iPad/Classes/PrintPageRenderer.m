// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "PrintPageRenderer.h"

#import "Document.h"
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSGraphRenderer.h>

@implementation PrintPageRenderer

- (id)initWithDocument:(Document *)document;
{
    if (!(self = [super init]))
        return nil;
    
    _document = [document retain];
    
    return self;
}

- (void)dealloc;
{
    [_document release];
    
    [super dealloc];
}


#pragma mark -
#pragma mark UIPrintPageRenderer subclass

- (NSInteger)numberOfPages;
{
    return 1;
}

- (void)drawContentForPageAtIndex:(NSInteger)index inRect:(CGRect)contentRect;
{
    RSGraph *graph = _document.editor.graph;
    RSGraphRenderer *renderer = _document.editor.renderer;
    
    // Draw the graph background and grid lines
    [renderer drawBackgroundWithColor:[graph backgroundColor]];
    
    // Draw all of the normal graph objects
    [renderer drawAllGraphElementsExcept:nil];
}

@end
