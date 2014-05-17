// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "AppController.h"

#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/UTType.h>
#import <OmniDocumentStore/ODSFileItem.h>
#import <OmniDocumentStore/ODSFilter.h>
#import <OmniDocumentStore/ODSStore.h>
#import <OmniFileExchange/OFXServerAccount.h>
#import <OmniFileExchange/OFXServerAccountType.h>
#import <OmniFoundation/OFPreference.h>
#import <GraphSketcherModel/RSImageExporter.h>
#import <OmniUIDocument/OUIDocumentPicker.h>
#import <OmniUIDocument/OUIDocumentPickerFilter.h>

#import "Document.h"
#import "GraphView.h"
#import "GraphViewController.h"
#import "OSStyleAttributeRegistry.h"

RCS_ID("$Header$");

@implementation AppController

+ (void)initialize;
{
    [OSStyleAttributeRegistry class];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
{
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)applicationWillEnterForeground:(UIApplication *)application;
{
    OBASSERT([[super class] instancesRespondToSelector:@selector(applicationWillEnterForeground:)]);
    [super applicationWillEnterForeground:application];
}

#define GRAPH_VIEW ((GraphViewController *)self.document.documentViewController).graphView

#pragma mark - OUIAppController subclass

- (Class)documentClassForURL:(NSURL *)url;
{
    return [Document class];
}

- (UIView *)pickerAnimationViewForTarget:(OUIDocument *)document;
{
    return ((GraphViewController *)document.documentViewController).graphView;
}

- (void)showInspectorFromBarButtonItem:(UIBarButtonItem *)item;
{
    // We don't update the text editor editor live, so this is easiest for now.
    [self.window endEditing:YES/*force*/];
    
    // Close any undo group this may have created
    [[self document] finishUndoGroup];
    
    GraphView *graphView = GRAPH_VIEW;
    [graphView showInspectorFromBarButtonItem:item];
}

#pragma mark -
#pragma mark ODSStoreDelegate

- (NSString *)documentStoreBaseNameForNewFiles:(ODSStore *)store;
{
    return NSLocalizedString(@"My Graph", @"Base name for newly created graphs. This will have an number appended to it to make it unique, if needed.");
}

- (NSString *)documentStoreDocumentTypeForNewFiles:(ODSStore *)store;
{
    return RSGraphFileType;
}

#pragma mark -
#pragma mark OUIDocumentPickerDelegate

- (NSArray *)availableExportTypesForFileItem:(ODSFileItem *)fileItem serverAccount:(OFXServerAccount *)serverAccount exportOptionsType:(OUIExportOptionsType)exportOptionsType;
{
    // NSNull here represents "the type you already are"... you still need to remove it from the list otherwise, so that you end up with that type only once.
    NSMutableArray *allExportTypes = [NSMutableArray array];
    if (!(exportOptionsType == OUIExportOptionsExport && [serverAccount.type.identifier isEqual:OFXiTunesLocalDocumentsServerAccountTypeIdentifier]))
        [allExportTypes addObject:[NSNull null]];
    
    [allExportTypes addObjectsFromArray:[NSArray arrayWithObjects:(NSString *)kUTTypePDF, (NSString *)kUTTypePNG, nil]];
    
    return allExportTypes;
}

static OUIDocumentPickerFilter * RSDocumentPickerFilter(AppController *self)
{
    OUIDocumentPickerFilter *filter = [[[OUIDocumentPickerFilter alloc] init] autorelease];

    filter.identifier = ODSDocumentPickerFilterDocumentIdentifier;
    filter.title = NSLocalizedStringFromTableInBundle(@"Graphs", nil, OMNI_BUNDLE, @"document picker filter title");
    filter.imageName = @"DocumentIconGraph-128.png";
    filter.predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        ODSFileItem *fileItem = (ODSFileItem *)evaluatedObject;
        return [self canViewFileTypeWithIdentifier:fileItem.fileType];
    }];

    return filter;
}

- (NSArray *)documentPickerAvailableFilters:(OUIDocumentPicker *)picker;
{
    static NSArray *filters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *result = [NSMutableArray array];
        [result addObject:RSDocumentPickerFilter(self)];
        filters = [result copy];
    });
    
    return filters;
}

- (NSData *)documentPicker:(OUIDocumentPicker *)picker PDFDataForFileItem:(ODSFileItem *)fileItem error:(NSError **)outError;
{
    Document *document = [[Document alloc] initWithExistingFileItem:fileItem error:outError];
    if (!document)
        return nil;
    if (![document readFromURL:[fileItem fileURL] error:outError]) {
        [document release];
        return nil;
    }
    
    RSImageExporter *imageExporter = [[RSImageExporter alloc] initWithGraph:[[document editor] graph]];
    NSData *pdfData = [imageExporter pdfRepresentation];
    
    [imageExporter release];
    [document release];
    
    return pdfData;
}

- (NSData *)documentPicker:(OUIDocumentPicker *)picker PNGDataForFileItem:(ODSFileItem *)fileItem error:(NSError **)outError;
{
    Document *document = [[Document alloc] initWithExistingFileItem:fileItem error:outError];
    if (!document)
        return nil;
    if (![document readFromURL:[fileItem fileURL] error:outError]) {
        [document release];
        return nil;
    }
    
    RSImageExporter *imageExporter = [[RSImageExporter alloc] initWithGraph:[[document editor] graph]];
    NSData *pngData = [imageExporter pngRepresentation];
    
    [imageExporter release];
    [document release];
    
    return pngData;
}

- (UIImage *)documentPicker:(OUIDocumentPicker *)picker cameraRollImageForFileItem:(ODSFileItem *)fileItem;
{
    NSError *error = nil;
    Document *document = [[Document alloc] initWithExistingFileItem:fileItem error:&error];
    if (!document) {
        OUI_PRESENT_ERROR(error);
        return nil;
    }
    if (![document readFromURL:[fileItem fileURL] error:&error]) {
        OUI_PRESENT_ERROR(error);
        [document release];
        return nil;
    }
    
    RSImageExporter *imageExporter = [[RSImageExporter alloc] initWithGraph:[[document editor] graph]];
    UIImage *image = [imageExporter makeImage];
    [imageExporter release];
    [document release];
    
    return image;
}

//- (NSString *)documentPicker:(OUIDocumentPicker *)picker printButtonTitleForFileItem:(OFSDocumentStoreFileItem *)fileItem;
//{
//    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
//    
//    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown)
//        return NSLocalizedStringFromTableInBundle(@"Print (portrait)", nil, OMNI_BUNDLE, @"Menu option in the document picker view");
//    return NSLocalizedStringFromTableInBundle(@"Print (landscape)", nil, OMNI_BUNDLE, @"Menu option in the document picker view");
//}

- (void)documentPicker:(OUIDocumentPicker *)picker printFileItem:(ODSFileItem *)fileItem fromButton:(UIBarButtonItem *)aButton;
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    UIPrintInteractionController *controller = [UIPrintInteractionController sharedPrintController];
    if(!controller){
        NSLog(@"Couldn't get shared UIPrintInteractionController!");
        [pool release];
        return;
    }
    void (^completionHandler)(UIPrintInteractionController *, BOOL, NSError *) =
    ^(UIPrintInteractionController *printController, BOOL completed, NSError *error) {
        if(!completed && error){
            NSLog(@"FAILED! due to error in domain %@ with error code %lu",
                  error.domain, error.code);
        }
    };
    
    UIPrintInfo *printInfo = [UIPrintInfo printInfo];
    printInfo.outputType = UIPrintInfoOutputGeneral;
    printInfo.jobName = fileItem.name;
    printInfo.duplex = UIPrintInfoDuplexLongEdge;
    
    // Choose a page orientation based on the orientation of the iPad
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    printInfo.orientation = (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) ? UIPrintInfoOrientationPortrait : UIPrintInfoOrientationLandscape;
    
    controller.printInfo = printInfo;
    controller.showsPageRange = NO;
    
//    Document *document = [[[Document alloc] initWithExistingDocumentProxy:proxy error:nil] autorelease];
//    NSLog(@"document: %@", document);
//    PrintPageRenderer *renderer = [[[PrintPageRenderer alloc] initWithDocument:document] autorelease];
//    controller.printPageRenderer = renderer;
    
    NSError *error = nil;
    Document *document = [[Document alloc] initWithExistingFileItem:fileItem error:&error];
    if (!document) {
        [AppController presentError:error];
        return;
    }
    if (![document readFromURL:[fileItem fileURL] error:&error]) {
        [AppController presentError:error];
        [document release];
        return;
    }
    
    RSImageExporter *imageExporter = [[RSImageExporter alloc] initWithGraph:[[document editor] graph]];
    NSData *pdfData = [imageExporter pdfRepresentation];
    
    [imageExporter release];
    [document release];

    controller.printingItem = pdfData;
    
    [controller presentFromBarButtonItem:aButton animated:YES completionHandler:completionHandler];
    [pool release];    
}

- (UIImage *)documentPicker:(OUIDocumentPicker *)picker iconForUTI:(CFStringRef)fileUTI;
{
    if (UTTypeConformsTo(fileUTI, (CFStringRef)RSGraphFileType))
        return [UIImage imageNamed:@"DocumentIconGraph-32.png"];
    
    return nil;
}

- (UIImage *)documentPicker:(OUIDocumentPicker *)picker exportIconForUTI:(CFStringRef)fileUTI;
// used in the export options sheet
{
    if (UTTypeConformsTo(fileUTI, (CFStringRef)RSGraphFileType)) 
        return [UIImage imageNamed:@"DocumentIconGraph-128.png"];
    
    if (UTTypeConformsTo(fileUTI, (CFStringRef)kUTTypePDF)) 
        return [UIImage imageNamed:@"DocumentIconPDF.png"];
    
    if (UTTypeConformsTo(fileUTI, (CFStringRef)kUTTypePNG)) 
        return [UIImage imageNamed:@"DocumentIconPNG.png"];
    
    return nil;
}

- (NSString *)documentPicker:(OUIDocumentPicker *)picker labelForUTI:(CFStringRef)fileUTI;
// used in the export options sheet
{
    if (UTTypeConformsTo(fileUTI, (CFStringRef)RSGraphFileType)) 
        return NSLocalizedString(@"Graph", @"Label for .ograph file type in export panel");
    
    return nil;
}

- (NSString *)documentPickerMainToolbarSelectionFormatForFileItems:(NSSet *)fileItems;
{
    NSUInteger itemCount = [fileItems count];
    
    if (itemCount == 0)
        return NSLocalizedString(@"Select a Graph", @"Main toolbar title for a no selected graphs.");
    else if (itemCount == 1)
        return NSLocalizedString(@"1 Graph Selected", @"Main toolbar title for a single selected graph.");
    
    return NSLocalizedString(@"%ld Graphs Selected", @"Main toolbar title for a multiple selected graphs.");
}

- (NSString *)documentPickerAlertTitleFormatForDuplicatingFileItems:(NSSet *)fileItems;
{
    return NSLocalizedString(@"Duplicate %ld Graphs", @"title for alert option confirming duplication of multiple outlines");
}

#pragma mark - NSObject (OUIAppMenuTarget)

- (NSString *)feedbackMenuTitle;
{
    return nil;
}

#pragma mark -
#pragma mark Private

- (void)_drawMode:(id)sender;
{
    [GRAPH_VIEW setToolMode:RSToolModeDraw];
}

- (void)_fillMode:(id)sender;
{
    [GRAPH_VIEW setToolMode:RSToolModeFill];
}

- (void)_handMode:(id)sender;
{
    [GRAPH_VIEW setToolMode:RSToolModeHand];
}

@end
