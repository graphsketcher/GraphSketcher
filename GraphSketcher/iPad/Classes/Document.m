// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/Document.m 200244 2013-12-10 00:11:55Z correia $

#import "Document.h"

#import <OmniDocumentStore/ODSFileItem.h>
#import <OmniFoundation/NSDate-OFExtensions.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraphElementSelector.h>
#import <GraphSketcherModel/RSImageExporter.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <OmniUIDocument/OUIDocumentPreview.h>
#import <OmniUI/UIView-OUIExtensions.h>

#import "GraphView.h"
#import "GraphViewController.h"
#import "OGSErrors.h"
#import "TextEditor.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/Document.m 200244 2013-12-10 00:11:55Z correia $");

@interface Document ()
- (BOOL)_readContentsFromURL:(NSURL *)url error:(NSError **)outError;
@end

@implementation Document

- initEmptyDocumentToBeSavedToURL:(NSURL *)url templateURL:(NSURL *)templateURL error:(NSError **)outError;
{
    self = [super initEmptyDocumentToBeSavedToURL:url templateURL:templateURL error:outError];
    if (self == nil)
        return nil;
    
    if (![self _readContentsFromURL:nil error:outError]) {
        [self release];
        return nil;
    }
    
    return self;
}

- (void)dealloc;
{
    [_editor invalidate];
    [_editor release];
    
    [super dealloc];
}

@synthesize editor = _editor;

+ (GraphView *)temporaryGraphViewForDocument:(OUIDocument *)document;
{
    // Make a new view controller so we can assume it is not scrolled down or has a different viewport.
    GraphViewController *vc = (GraphViewController *)[document makeViewController];
    
    [vc view]; // Trigger the creation of a view
    GraphView *graphView = [vc graphView];
    
    CGSize fullScreenSize = [vc fullScreenSize];
    
    CGRect frame;
    frame.origin = CGPointZero;
    frame.size = fullScreenSize;
    graphView.frame = frame;
    
    return  graphView;
}

#pragma mark -
#pragma mark OUIDocument subclass

- (UIViewController *)makeViewController;
{
    OBPRECONDITION(_editor);
    return [[[GraphViewController alloc] initWithEditor:_editor] autorelease];
}

- (UIViewController *)viewControllerToPresent;
{
    if (_viewControllerToPresent == nil) {
        _viewControllerToPresent = [[UINavigationController alloc] initWithRootViewController:self.documentViewController];
        _viewControllerToPresent.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    
    return _viewControllerToPresent;
}

- (void)updateViewControllerToPresent;
{
    OBPRECONDITION(self.documentViewController);
    OBPRECONDITION(self.viewControllerToPresent);
    OBPRECONDITION([self.viewControllerToPresent isKindOfClass:[UINavigationController class]]);
    
    UINavigationController *navigationController = (UINavigationController *)self.viewControllerToPresent;
    OBPRECONDITION(navigationController.viewControllers.count <= 1); // Right now we only support a single view controller. This may need to be fixed if/when this changes. 0 is also valid.
    
    [navigationController setViewControllers:@[self.documentViewController] animated:NO];
}

- (void)didClose;
{
    [_viewControllerToPresent release];
    _viewControllerToPresent = nil;
    
    [super didClose];
}

- (void)willFinishUndoGroup;
{
    [super willFinishUndoGroup];
    
    [_editor.undoer endRepetitiveUndo];
}

- (BOOL)shouldUndo;
{
    GraphViewController *vc = (GraphViewController *)self.documentViewController;
    
    if ([vc.graphView letToolUndo])
        return NO; // Tool handled the undo internally

    return [super shouldUndo];
}

- (BOOL)shouldRedo;
{
    GraphViewController *vc = (GraphViewController *)self.documentViewController;
    
    if ([vc.graphView letToolRedo])
        return NO; // Tool handled the undo internally
    
    return [super shouldRedo];
}

- (UIView *)viewToMakeFirstResponderWhenInspectorCloses;
{
    GraphViewController *vc = (GraphViewController *)self.documentViewController;
    return vc.graphView;
}

+ (NSString *)placeholderPreviewImageNameForFileURL:(NSURL *)fileURL area:(OUIDocumentPreviewArea)area;
{
    return @"DocumentPreviewPlaceholder";
}

static void _generatePreview(OUIDocument *document, NSURL *fileURL, NSDate *date, void (^completionHandler)(void))
{
    OBPRECONDITION(![NSThread isMainThread]);
    
    CGFloat imageSizeLength = [OUIDocumentPreview previewSizeForArea:OUIDocumentPreviewAreaLarge];
    CGSize imageSize = CGSizeMake(imageSizeLength, imageSizeLength);
    CGFloat imageScale = [OUIDocumentPreview previewImageScale];
    
    imageSize.width *= imageScale;
    imageSize.height *= imageScale;
    
    // TODO: It is a shame to re-read the document here. We could use -initWithGraph:document.editor.graph, but the exporter does upcalls to the graphView via the delegate path. More work needed to make this work (if we care that much).
    NSError *error = nil;
    RSImageExporter *exporter = [RSImageExporter imageExporterForURL:fileURL error:&error];
    if (!exporter) {
        NSLog(@"Unable to create exporter for %@: %@", fileURL, [error toPropertyList]);
        if (completionHandler)
            [[NSOperationQueue mainQueue] addOperationWithBlock:completionHandler];
        return;
    }
    
    [exporter setExportSize:imageSize];
    
    UIImage *image = [exporter makeImageForPreview];
    
    [OUIDocumentPreview afterAsynchronousPreviewOperation:^{
        [OUIDocumentPreview cachePreviewImages:^(OUIDocumentPreviewCacheImage cacheImage){
            cacheImage(fileURL, date, [image CGImage]);
        }];

        // We could just call it, but it is nicer to unblock the main thread again and let events/scrolling be processed in the document picker.
        if (completionHandler)
            [[NSOperationQueue mainQueue] addOperationWithBlock:completionHandler];
    }];
}

+ (void)writePreviewsForDocument:(OUIDocument *)document withCompletionHandler:(void (^)(void))completionHandler;
{
    NSURL *fileURL = document.fileURL;
    NSDate *date = document.fileItem.fileModificationDate;
    
    completionHandler = [[completionHandler copy] autorelease];
    
    // We ping-ping here a bit, reducing the amount of time the main thread is blocked improves scrolling performance in the document picker.
    OBASSERT([NSThread isMainThread]);
    [OUIDocumentPreview performAsynchronousPreviewPreparation:^{
        OBASSERT(![NSThread isMainThread]);
        _generatePreview(document, fileURL, date, completionHandler);
    }];
}

- (NSString *)alertTitleForIncomingEdit;
{
    return NSLocalizedString(@"Graph Updated", @"Title for alert informing user that the document has been reloaded with edits from another device");
}

#pragma mark - UIDocument subclass

- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError;
{
    return [self _readContentsFromURL:url error:outError];
}

- (id)contentsForType:(NSString *)typeName error:(NSError **)outError;
{
    [_editor prepareForSave];
    
    GraphViewController *vc = (GraphViewController *)self.documentViewController;
    GraphView *graphView = vc.graphView;
    
    CGRect frame = CGRectZero;
    if ([vc isViewLoaded])
        frame = [graphView frame];
    
    return [_editor.graph generateXMLOfType:RSGraphFileType frame:frame error:outError];
}

#pragma mark - RSUndoerOwner

- (void)undoerPerformedChange:(RSUndoer *)undoer;
{
    //NSLog(@"OBFinishPorting: Start a timed autosave?");
}

#pragma mark -
#pragma mark RSGraphEditorDelegate

- (void)graphEditorDidUpdate:(RSGraphEditor *)editor;
{
    //NSLog(@"OBFinishPorting: This is what the Mac GraphDocument does for %@", NSStringFromSelector(_cmd));
    GraphViewController *vc = (GraphViewController *)self.documentViewController;
    [vc.graphView graphEditorDidUpdate:editor];
}

- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
{
    GraphViewController *vc = (GraphViewController *)self.documentViewController;
    [vc.graphView graphEditorNeedsDisplay:editor];
}

- (void)graphEditorDeselect:(RSGraphEditor *)editor;
{
    GraphViewController *vc = (GraphViewController *)self.documentViewController;
    [vc.graphView clearSelection];
}

- (void)graphEditor:(RSGraphEditor *)editor addedElementDuringUndoOrRedo:(id)element;
{
    GraphViewController *vc = (GraphViewController *)self.documentViewController;
    vc.graphView.selectionController.selection = element;
    [vc.graphView updateSelection];
}

#pragma mark -
#pragma mark Private

- (BOOL)_readContentsFromURL:(NSURL *)url error:(NSError **)outError;
{
    RSUndoer *undoer = [[(RSUndoer *)[RSUndoer alloc] initWithOwner:self] autorelease];
    
    RSGraph *graph;
    if (url != nil) {
        // Load existing document or use a template.
        graph = [RSGraph graphFromURL:url type:RSGraphFileType undoer:undoer error:outError];
    } else {
        // New document
        graph = [[[RSGraph alloc] initWithIdentifier:nil undoer:undoer] autorelease];
        [graph setupDefault];
    }
    if (!graph)
        return NO;
    
    _editor = [[RSGraphEditor alloc] initWithGraph:graph undoer:undoer]; // RSGraphEditor takes ownership.
    _editor.delegate = self;
    
    [_editor.undoer endRepetitiveUndo];
    
    return YES;
}

@end
