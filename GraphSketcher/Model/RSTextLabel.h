// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSTextLabel.h 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSFontAttributes.h>

@class RSText;
@class OAFontDescriptor;

@interface RSTextLabel : RSGraphElement <RSFontAttributes>
{
@protected
    RSText *_text;
    RSText *_formattedText;
    
    RSDataPoint _pos;
    BOOL _partOfAxis;
    CGFloat _rotation;	// in degrees
    
    RSGraphElement *_owner;
    RSGroup *_group;
    BOOL _locked;
    BOOL _visible;
    
    // "reverse index" values (these are not saved to disk):
    data_p _tickValue;
    int _axisOrientation;
}

- (id)initWithGraph:(RSGraph *)graph;
- (id)initWithGraph:(RSGraph *)graph fontDescriptor:(OAFontDescriptor *)fontDescriptor;
// Designated initializer:
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier
   attributedString:(NSAttributedString *)attributedString
	   position:(RSDataPoint)pos
	   rotation:(CGFloat)angle;


- (BOOL)prepareUndoForAttributedString;
- (NSAttributedString *)attributedString;
- (void)setAttributedString:(NSAttributedString *)newString;
- (id)attributeForKey:(NSString *)name;
- (void)setAttribute:(id)obj forKey:(NSString *)name;

- (BOOL)isDeletedString;
- (CGSize)size;  // size of typographic bounds
- (void)resetSizeCache;
- (NSUInteger)length;

- (void)setPartOfAxis:(BOOL)val;
- (void)setVisible:(BOOL)val;

- (CGFloat)rotation;
- (void)setRotation:(CGFloat)angle;

- (void)shallowSetOwner:(RSGraphElement *)owner;


// Axis-related accessors
- (void)setTickValue:(data_p)tickValue axisOrientation:(int)orientation;
- (void)setAxisOrientation:(int)orientation;
- (data_p)tickValue;
- (int)axisOrientation;
- (BOOL)isAxisTickLabel;

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (void)useEffectiveScale:(CGFloat)effectiveScale;
#endif

- (void)drawAtPoint:(CGPoint)pt baselineRotatedByDegrees:(CGFloat)degrees;

+ (NSAttributedString *)formatExponentsInString:(NSAttributedString *)original exponentSymbol:(NSString *)exponentSymbol removeLeadingOne:(BOOL)removeLeadingOne;

@end
