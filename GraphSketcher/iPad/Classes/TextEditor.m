// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "TextEditor.h"

#import "AxisEndHandleView.h"
#import "GraphView.h"

#import <OmniAppKit/OAFontDescriptor.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSText.h>
#import <GraphSketcherModel/RSText.h>
#import <OmniQuartz/OQColor.h>
#import <OmniUI/OUITextView.h>
#import <OmniUI/OUITextLayout.h>
#import <OmniUI/OUIScalingTextStorage.h>

RCS_ID("$Header$");

@interface TextView : OUITextView
@end

@implementation TextView

#define TEXT_EDITOR_INSET (4) // space between the border we draw and the text
#define TEXT_EDITOR_HIT_PADDING (21) // extra space outside the text view's needed space that we allocate for it to be easier to touch

// Want this frame to be unscaled, so not overriding -drawScaledContent:
//- (void)drawRect:(CGRect)rect;
//{
//    CGRect bounds = self.bounds;
//    
//    [[UIColor colorWithWhite:0 alpha:0.25] set];
//    UIRectFrameUsingBlendMode(CGRectInset(bounds, TEXT_EDITOR_HIT_PADDING, TEXT_EDITOR_HIT_PADDING), kCGBlendModeNormal);
//    
//    [[UIColor colorWithWhite:1 alpha:0.25] set];
//    UIRectFrameUsingBlendMode(CGRectInset(bounds, 1 + TEXT_EDITOR_HIT_PADDING, 1 + TEXT_EDITOR_HIT_PADDING), kCGBlendModeNormal);
//    
//    [super drawRect:rect];
//}

// OBFinishPorting: Make sure we get the right background color
#if 0
- (UIColor *)loupeOverlayBackgroundColor;
{
    if ([self.superview isKindOfClass:[GraphView class]]) {
        // Use our GraphView's background color.
        GraphView *graphView = (GraphView *)self.superview;
        return [graphView.editor.graph.backgroundColor toColor];
    }
    
    if ([self.superview isKindOfClass:[AxisEndHandleView class]]) {
        return [UIColor colorWithHue:0.575 saturation:0.13 brightness:0.85 alpha:1];
    }
    
    return [super loupeOverlayBackgroundColor];
}
#endif

@end

@interface TextEditor (/*Private*/) <OUITextViewDelegate>
@end

@implementation TextEditor
{
    OUIScalingTextStorage *_scalingTextStorage;
    
    OAFontDescriptor *_fontDescriptor;
    OQColor *_color;
    UIKeyboardType _keyboardType;
    
    id <TextEditorTarget> _target;
    id _object;
    BOOL _hasChanged;
    BOOL _interpretsTabsAndNewlines;
    
    CGFloat _minimumHeight;
    CGPoint _origin;
    CGFloat _scale;
    CGSize _viewUsedSize;
}

static TextEditor *CurrentTextEditor;

+ (TextEditor *)currentTextEditor;
{
    return CurrentTextEditor;
}

+ (TextEditor *)makeEditor;
{
    OBPRECONDITION(CurrentTextEditor == nil);
    CurrentTextEditor = [[TextEditor alloc] init];
    return CurrentTextEditor;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_scalingTextStorage release];
    [_fontDescriptor release];
    [_color release];
    [_target release];
    [_object release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark TextEditor protocol

- (BOOL)supportsFractionalFontSizes;
{
    return YES;
}

@synthesize interpretsTabsAndNewlines = _interpretsTabsAndNewlines;
@synthesize fontDescriptor = _fontDescriptor;
@synthesize color = _color;
@synthesize keyboardType = _keyboardType;

- (void)confirmEdits;
{
    [self confirmEditsAndEndEditing:YES];
}

- (void)confirmEditsAndEndEditing:(BOOL)endEditing;
{
    OBPRECONDITION(self == CurrentTextEditor);
    
    if (!_target) {
        OBASSERT(_hasChanged == NO);
        OBASSERT(_object == nil);
        return;
    }

    TextView *textView = (TextView *)self.view;

    // Capture these in locals in case the call out starts editing again.
    id <TextEditorTarget> target = [_target autorelease];
    id object = [_object autorelease];
    NSAttributedString *text = [[[NSAttributedString alloc] initWithAttributedString:_scalingTextStorage.underlyingTextStorage] autorelease];
    
    // Mark ourselves as being done editing
    BOOL didChange = _hasChanged;
    _target = nil;
    _object = nil;
    _hasChanged = NO;

    if (endEditing) {
        [textView removeFromSuperview];
    }

    TextEditor *finishing = [[self retain] autorelease];
    [CurrentTextEditor autorelease];
    CurrentTextEditor = nil;
    
    // Finally, send the notification if there was an edit
    if (didChange)
        [target textEditor:finishing confirmedText:text inObject:object];
    else
        [target textEditor:finishing cancelledInObject:object];
}

// TODO: Finish editing on scale changes or reposition/scale the editor?
- (void)editString:(NSAttributedString *)attributedString atPoint:(CGPoint)origin ofView:(UIView *)view target:(id <TextEditorTarget>)target object:(id)object;
{
    OBPRECONDITION(target); // why are you asking to edit if you don't care about the results?

    if (_hasChanged) {
        [self confirmEdits];
    }
    OBASSERT(_hasChanged == NO);
    OBASSERT(_target == nil);
    OBASSERT(_object == nil);
    
    _origin = origin;
    if ([view isKindOfClass:[OUIScalingView class]]) {
        _scale = [(OUIScalingView *)view scale];
    } else {
        _scale = 1;
    }
    
    _hasChanged = NO;
    [_target autorelease];
    _target = [target retain];
    [_object autorelease];
    _object = [object retain];
        
    TextView *textView = (TextView *)self.view;
    NSLog(@"textView = %@", textView);
    
    UIFont *desiredFont = [_fontDescriptor font];
    
    _minimumHeight = desiredFont.lineHeight;
    
    textView.font = desiredFont;
    
    OBFinishPortingLater("Fix insets");
#if 0
    // Text inset is in text space, so it scales up. We want view space
    CGFloat textInset = (TEXT_EDITOR_INSET + TEXT_EDITOR_HIT_PADDING)/scale;
    textView.textInset = UIEdgeInsetsMake(textInset, textInset, textInset, textInset);
#endif

    UIColor *color = [_color toColor];
    if (!_color)
        color = [UIColor blackColor];
    textView.textColor = color;
    textView.keyboardType = _keyboardType;
    
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedString];
    _scalingTextStorage = [[OUIScalingTextStorage alloc] initWithUnderlyingTextStorage:textStorage scale:_scale];
    [textStorage release];
    
    [textView replaceTextStorage:_scalingTextStorage];
    
    [self _resize];
    
    [view addSubview:textView];
    [textView becomeFirstResponder];

    //NSLog(@"editing in textView %@", textView);
}

- (void)selectAll;
{
    // Selection thumbs don't work yet, but this will at least draw the range as selected
    TextView *textView = (TextView *)self.view;
    
    UITextRange *range = [textView textRangeFromPosition:textView.beginningOfDocument toPosition:textView.endOfDocument];
    textView.selectedTextRange = range;
}

- (BOOL)isTarget:(id <TextEditorTarget>)object;
{
    return _target == object;
}

- (BOOL)hasTouch:(UITouch *)touch;
{
    return [(TextView *)self.view hasTouch:touch];
}

- (BOOL)hasTouchByGestureRecognizer:(UIGestureRecognizer *)recognizer;
{
    return [(TextView *)self.view hasTouchByGestureRecognizer:recognizer];
}

- (void)_mainViewControllerDidBegingResizingForKeyboard:(NSNotification *)note;
{    
    UIView *textView = (UIView *)self.view;
    OBASSERT([textView superview]);
    
    // Text view is a scroll view; we want its containing scroll view since we won't allow our editing view to become scrollable.
    UIView *view = textView.superview;
    while (view && ![view isKindOfClass:[UIScrollView class]])
        view = view.superview;
    if (view) {
        UIScrollView *scrollView = (UIScrollView *)view;
        CGRect scrollBounds = [scrollView convertRect:textView.bounds fromView:textView];
        [scrollView scrollRectToVisible:scrollBounds animated:YES];
    }
}

#pragma mark - UIViewController

- (void)loadView;
{
    TextView *view = [[TextView alloc] init];

    // Set up an infinite text container -- we'll resize/position the text view to show the needed area need the origin (we never display right-aligned text).
    view.textContainer.widthTracksTextView = NO;
    view.textContainer.heightTracksTextView = NO;
    view.textContainer.size = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);

    view.autoresizingMask = UIViewAutoresizingNone;
    view.opaque = NO;
    view.clearsContextBeforeDrawing = YES;
    view.scrollEnabled = NO;
    
    view.backgroundColor = nil;
    //view.backgroundColor = [UIColor yellowColor];
    //view.layer.borderColor = [[UIColor redColor] CGColor];
    //view.layer.borderWidth = 1;

    view.dataDetectorTypes = UIDataDetectorTypeNone;
    view.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    
    view.delegate = self;
    
    self.view = view;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
{
    BOOL foundAction = NO;
    
    if (self.interpretsTabsAndNewlines) {
        if (OFISEQUAL(text, @"\t")) {
            foundAction = YES;
        } else if (OFISEQUAL(text, @"\n")) {
            foundAction = YES;
        }
    }
    
    if (foundAction) {
        if ([_target respondsToSelector:@selector(textEditor:interpretedText:inObject:)]) {
            [_target textEditor:self interpretedText:text inObject:_object];
        }
        
        return NO;
    }
    
    return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView;
{
    OBPRECONDITION(textView == self.view);
    OBPRECONDITION([textView isFirstResponder] == NO);
    
    //NSLog(@"ended editing");
    [self confirmEdits];
}

- (void)textViewDidChange:(UITextView *)textView;
{
    //NSLog(@"%s -> %@, %@", __FUNCTION__, NSStringFromCGRect([textView frame]), NSStringFromCGSize([textView contentSize]));
    //NSLog(@"  text: %@", textView.text);
    _hasChanged = YES;
    
    [_target textEditor:self textChanged:textView.attributedText inObject:_object];
    
    [self _resize];
    
    CGPoint updatedOrigin = [_target textEditor:self updateTextPosition:_origin forSize:_viewUsedSize inObject:_object];
    //NSLog(@"updatedOrigin = %@, _origin = %@", NSStringFromPoint(updatedOrigin), NSStringFromPoint(_origin));
    if (!CGPointEqualToPoint(updatedOrigin, _origin)) {
        _origin = updatedOrigin;
        [self _resize];
    }
}

#pragma mark - Private

- (void)_resize;
{
    //NSLog(@"resize");
    
    TextView *textView = (TextView *)self.view;

    // Contrary to what you might expect, with widthTracksTextView==NO, when we set the frame of the text view, the text container width still gets set.
    // So, make the text view huge before calculating the un-wrapping width.
    textView.textContainer.size = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    [textView ensureLayout];
    
    CGSize textSize = textView.textUsedSize;
    //NSLog(@"  container size = %@", NSStringFromCGSize(textView.textContainer.size));
    //NSLog(@"  text size = %@", NSStringFromCGSize(textSize));
    
    CGSize viewSize = CGSizeMake(textSize.width + 2*[OUITextLayout defaultLineFragmentPadding], textSize.height + 2*[OUITextView oui_defaultTopAndBottomPadding]);
    
    _viewUsedSize = viewSize;
    //NSLog(@"  _viewUsedSize = %@", NSStringFromSize(_viewUsedSize));
    //NSLog(@"  _origin = %@", NSStringFromCGPoint(_origin));
    
    CGRect textViewFrame;
    textViewFrame.size = _viewUsedSize;
    textViewFrame.origin = CGPointMake(_origin.x, _origin.y - _viewUsedSize.height);
    //NSLog(@"textViewFrame with estimated size and original position %@", NSStringFromRect(textViewFrame));
    
    textViewFrame.origin.x -= [OUITextLayout defaultLineFragmentPadding];
    textViewFrame.origin.y += [OUITextView oui_defaultTopAndBottomPadding];
        
    textViewFrame = CGRectIntegral(textViewFrame);
    //NSLog(@"  _minimumHeight %f", _minimumHeight);
    //NSLog(@"  integral textViewFrame %@", NSStringFromRect(textViewFrame));
    textView.frame = textViewFrame;
    //NSLog(@"  container size = %@", NSStringFromCGSize(textView.textContainer.size));
}

@end

