// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <UIKit/UIViewController.h>
#import <UIKit/UITextView.h>

@class OAFontDescriptor;
@class OQColor;
@protocol TextEditor;

@protocol TextEditorTarget <NSObject>
- (void)textEditor:(id <TextEditor>)editor textChanged:(NSAttributedString *)text inObject:(id)object;
- (CGPoint)textEditor:(id <TextEditor>)editor updateTextPosition:(CGPoint)currentPosition forSize:(CGSize)size inObject:(id)object;
- (void)textEditor:(id <TextEditor>)editor confirmedText:(NSAttributedString *)text inObject:(id)object;
- (void)textEditor:(id <TextEditor>)editor cancelledInObject:(id)object;
@optional
- (void)textEditor:(id <TextEditor>)editor interpretedText:(NSString *)actionCharacter inObject:(id)object;
@end

@protocol TextEditor <NSObject>
@property(readonly) BOOL supportsFractionalFontSizes;
@property(assign) BOOL interpretsTabsAndNewlines;
@property(copy) OAFontDescriptor *fontDescriptor;
@property(retain) OQColor *color;
@property(nonatomic) UIKeyboardType keyboardType;

- (void)editString:(NSAttributedString *)string atPoint:(CGPoint)origin ofView:(UIView *)view target:(id <TextEditorTarget>)target object:(id)object;
- (void)confirmEdits;
- (void)confirmEditsAndEndEditing:(BOOL)endEditing;

- (void)selectAll;

- (BOOL)isTarget:(id <TextEditorTarget>)object;
- (BOOL)hasTouch:(UITouch *)touch;
- (BOOL)hasTouchByGestureRecognizer:(UIGestureRecognizer *)recognier;

@end

#import <UIKit/UIViewController.h>

@interface TextEditor : UIViewController <TextEditor>
+ (TextEditor *)currentTextEditor;
+ (TextEditor *)makeEditor;
@end
