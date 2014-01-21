// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/GraphViewController.m 200244 2013-12-10 00:11:55Z correia $

#import "GraphViewController.h"

#import <OmniUI/OUIDirectTapGestureRecognizer.h>
#import <OmniUIDocument/OUIDocumentAppController.h>
#import <OmniUIDocument/OUIDocumentNavigationItem.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraph.h>

#import "AppController.h"
#import "GraphView.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/GraphViewController.m 200244 2013-12-10 00:11:55Z correia $");

@interface GraphViewController (/*Private*/)
{
    OUIDocument *_nonretained_document;
    OUIDirectTapGestureRecognizer *_backgroundTappedRecognizer;
    
    GraphView *_graphView;
    RSGraphEditor *_editor;
    
    BOOL _rotatingToNewInterfaceOrientation;
    BOOL _receivedDocumentDidClose;
}

@property (nonatomic, strong) OUIDocumentNavigationItem *documentNavigationItem;

@property (nonatomic, getter=isKeyboardVisible) BOOL keyboardVisible;
@property (nonatomic) CGFloat bottomContentInset;

- (void)_handleBackgroundTapped:(UITapGestureRecognizer *)tapRecognizer;
@end

@implementation GraphViewController

- init;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- initWithEditor:(RSGraphEditor *)editor;
{
    if (!(self = [super initWithNibName:@"GraphViewController" bundle:nil]))
        return nil;

    // Through the accessor to set our view's editor too
    self.editor = editor;
    
    _rotatingToNewInterfaceOrientation = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    
    return self;
}

- (void)dealloc;
{
    OBPRECONDITION(_nonretained_document == nil); // should have been cleared by the document already
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_backgroundTappedRecognizer release];
    [_graphView release];
    [_editor release];
    [_documentNavigationItem release];

    [super dealloc];
}

@synthesize editor = _editor;
- (void)setEditor:(RSGraphEditor *)editor;
{
    [_editor autorelease];
    _editor = [editor retain];

    // In case we loaded our view already; but if _graphView is still nil, we'll pick it up in -viewDidLoad.
    _graphView.editor = editor;
    [self sizeInitialViewSizeFromCanvasSize];
}

@synthesize graphView = _graphView;
- (GraphView *)graphView;
{
    OBPRECONDITION(_graphView); // Make sure to call -view first. We could do that here, I guess, but it is easy to do the other way.
    return _graphView;
}

#pragma mark -
#pragma mark OUIScalingViewController subclass

- (CGSize)canvasSize;
{
    if (!_editor)
        return CGSizeZero; // Superclass just does nothing in this case.
    return _editor.graph.canvasSize;
}

#pragma mark -
#pragma mark OUIDocumentViewController protocol

@synthesize document = _nonretained_document;

- (void)documentDidClose;
{
    OBPRECONDITION(_receivedDocumentDidClose == NO);
    _receivedDocumentDidClose = YES;

    _graphView.navigationItem = nil;
    
    [_documentNavigationItem release];
    _documentNavigationItem = nil;
}

#pragma mark -
#pragma mark UIViewController subclass;

- (UINavigationItem *)navigationItem;
{
    OBPRECONDITION(self.document);
    
    if (_receivedDocumentDidClose) {
        OBASSERT(_documentNavigationItem == nil, "Don't leak by re-establishing this retain cycle after breaking it");
        return nil;
    }
    
    if (_documentNavigationItem == nil) {
        _documentNavigationItem = [[OUIDocumentNavigationItem alloc] initWithDocument:self.document];
    }
    
    return _documentNavigationItem;
}

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    OBASSERT(_graphView);
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    // In case we get unloaded and then reloaded.
    _graphView.editor = _editor;
    _graphView.wantsShadowEdges = YES;
    _graphView.navigationItem = self.navigationItem;

    [self sizeInitialViewSizeFromCanvasSize];
    
    // Allow the GraphView to respond to touches immediately.
    self.scrollView.delaysContentTouches = NO;

    // For some reason, viewDidLoad is getting called when we exit to the document browser, not just when we go into a graph view.  So the assertion fails.  For now, I'll at least plug the memory leak.
    OBASSERT(_backgroundTappedRecognizer == nil);
    if (!_backgroundTappedRecognizer) {
        _backgroundTappedRecognizer = [[OUIDirectTapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleBackgroundTapped:)];
    }
    [self.scrollView addGestureRecognizer:_backgroundTappedRecognizer];
}

- (void)viewWillAppear:(BOOL)animated;
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [_graphView updateNavigationItem];

    [self updateScrollViewInsets];

    // TODO: Enforce the minimum top content inset on appearance and rotation
    
    
    // Set up our initial toolbar items
}

- (void)viewWillDisappear:(BOOL)animated;
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)didReceiveMemoryWarning;
{
    [_graphView didReceiveMemoryWarning];
    
    [super didReceiveMemoryWarning];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration;
{
    _rotatingToNewInterfaceOrientation = YES;

    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];

    // TODO: Enforce the minimum top content inset on appearance and rotation
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    _rotatingToNewInterfaceOrientation = NO;
}

- (void)willMoveToParentViewController:(UIViewController *)parent;
{
    [super willMoveToParentViewController:parent];

    if (parent) {
        // Our view has been sized correctly for the current orientation at this point (when the xib is loaded, it is always in the archive orientation).
        [self sizeInitialViewSizeFromCanvasSize];
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent;
{
    [super didMoveToParentViewController:parent];
    
    if (parent) {
        [_graphView becomeFirstResponder];
    } else {
        // This gets called after the document has been closed and we've animated back to the document picker. Break retain cycles.
        self.view = nil;
    }
}

- (void)viewWillLayoutSubviews;
{
    [super viewWillLayoutSubviews];

    [self updateScrollViewInsets];
}

#pragma mark -
#pragma mark UIResponder subclass

- (NSUndoManager *)undoManager;
{
    return [[_editor undoer] undoManager];
}

#pragma mark -
#pragma mark UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView;
{
    return _graphView;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
{
    [super scrollViewDidScroll:scrollView];
    
    [_graphView scrollViewDidScroll:scrollView];
}

#pragma mark -
#pragma mark UIKeyboard Notifications

- (void)keyboardWillShow:(NSNotification *)notification;
{
    NSValue *keyboardFrameValue = [[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardFrame = [self.view convertRect:[keyboardFrameValue CGRectValue] fromView:nil];
    CGRect intersectionRect = CGRectZero;
    
    if (CGRectIntersectsRect(keyboardFrame, self.view.bounds)) {
        intersectionRect = CGRectIntersection(keyboardFrame, self.view.bounds);
    }
    
    self.keyboardVisible = YES;
    self.bottomContentInset = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(intersectionRect);
    
    NSTimeInterval duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    UIViewAnimationCurve curve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    NSUInteger options = (curve << 16);
    
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        [self updateScrollViewInsets];
    } completion:^(BOOL finished) {
        // No completion
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification;
{
    NSTimeInterval duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    UIViewAnimationCurve curve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    NSUInteger options = (curve << 16);
    
    self.keyboardVisible = NO;
    self.bottomContentInset = 0;
    
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        [self updateScrollViewInsets];
    } completion:^(BOOL finished) {
        // No completion
    }];
}

- (void)updateScrollViewInsets;
{
    OUIScalingScrollView *scrollView = self.scrollView;
    if (scrollView == nil) {
        return;
    }

    CGFloat topContentInset = self.topLayoutGuide.length >= 64 ? self.topLayoutGuide.length : 64;
    CGFloat bottomContentInset = [self isKeyboardVisible] ? self.bottomContentInset : self.bottomLayoutGuide.length;
    UIEdgeInsets contentInset = UIEdgeInsetsMake(topContentInset, 0, bottomContentInset, 0);
    UIEdgeInsets scrollIndicatorInsets = contentInset;

    scrollView.extraEdgeInsets = contentInset;
    [scrollView adjustContentInsetAnimated:NO];

    scrollView.scrollIndicatorInsets = scrollIndicatorInsets;
}

#pragma mark -
#pragma mark Private

- (void)_handleBackgroundTapped:(UITapGestureRecognizer *)tapRecognizer;
{
    // Tapping out of an editor should stop editing. We also want to make sure that our GraphView stays/becomes first responder.
    if ([_graphView isFirstResponder])
        return;
    
    if ([self.view.window endEditing:NO])
        [_graphView becomeFirstResponder];
}

- (void)_keyboardDidHide:(NSNotification *)note;
{
    // When the keyboard goes away, the GraphView shouldn't become firstResponder if a popover is still present.  Currently the inspector is the only popover with editable text fields. Tim and I couldn't readily come up with any less-hacky ways to do this.  <bug://bugs/60844>
    if ([_graphView.inspector isVisible])
        return;
    
    // When you change device orientation with the keyboard visible, the keyboard is first hidden in the old orientation, then shown in the new orientation.  We don't want to end editing if the keyboard is going to come right back.
    if (_rotatingToNewInterfaceOrientation)
        return;
    
    if (![_graphView isFirstResponder]) {
        [_graphView becomeFirstResponder];
    }
}

@end
