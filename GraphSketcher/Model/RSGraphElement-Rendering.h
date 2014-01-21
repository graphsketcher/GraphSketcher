// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGraphElement-Rendering.h 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSAxis.h>

@class RSDataMapper, NSBezierPath;


@interface RSGraphElement (Rendering)
- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper;

- (CGSize)selectionSize;
- (CGSize)selectionSizeWithMinSize:(CGSize)minSize;
- (void)drawSelectedUsingMapper:(RSDataMapper *)mapper selectionColor:(OQColor *)selectionColor borderWidth:(CGFloat)borderWidth alpha:(CGFloat)startingAlpha fingerWidth:(CGFloat)fingerWidth subpart:(RSGraphElementSubpart)subpart;

// deprecated:
- (void)drawSelectionAtPoint:(CGPoint)p borderWidth:(CGFloat)borderWidth color:(OQColor *)selectionColor minSize:(CGSize)minSize;
- (void)drawSelectionAtPoint:(CGPoint)p borderWidth:(CGFloat)borderWidth color:(OQColor *)selectionColor minSize:(CGSize)minSize subpart:(RSGraphElementSubpart)subpart;

- (CGRect)viewRectWithMapper:(RSDataMapper *)mapper;
- (CGRect)selectionViewRectWithMapper:(RSDataMapper *)mapper;
@end


@interface RSVertex (Rendering)
- (CGRect)rectFromBarUsingMapper:(RSDataMapper *)mapper width:(CGFloat)w;
- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper newWidth:(CGFloat)width;
- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper newWidth:(CGFloat)width newShape:(NSInteger)shape;
- (NSBezierPath *)pathUsingMapper:(RSDataMapper *)mapper newWidth:(CGFloat)width newShape:(NSInteger)shape newPoint:(CGPoint)p;
- (void)drawUsingMapper:(RSDataMapper *)mapper;

- (void)drawAtPoint:(CGPoint)p size:(CGSize)size;
@end


@interface RSTextLabel (Rendering)
@end

