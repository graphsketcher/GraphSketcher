// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

@class OAFontDescriptor;
@protocol RSFontAttributes
@property(nonatomic,retain) OAFontDescriptor *fontDescriptor;
@property(nonatomic,assign) CGFloat fontSize;
- (id)attributeForKey:(NSString *)name;
- (void)setAttribute:(id)obj forKey:(NSString *)name;
@end

