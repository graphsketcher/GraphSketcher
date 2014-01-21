// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/OFPreference-RSExtensions.m 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/OFPreference-RSExtensions.h>

#import <OmniAppKit/OAFontDescriptor.h>

@implementation OFPreferenceWrapper (RSExtensions)

- (OAFontDescriptor *)fontDescriptorForKey:(NSString *)defaultName;
{
    NSDictionary *attributes = [[OFPreference preferenceForKey: defaultName] dictionaryValue];

    // Let the app decide what it wants (Verdana on the iPad, Lucida on Mac) instead of forcing OAFontDescriptor's choice (Helvetica)
    if ([attributes count] == 0)
        return nil;

    return [[[OAFontDescriptor alloc] initWithFamily:nil size:12] autorelease];
}

- (void)setFontDescriptor:(OAFontDescriptor *)fontDescriptor forKey:(NSString *)defaultName;
{
    [[OFPreference preferenceForKey: defaultName] setDictionaryValue:[fontDescriptor fontAttributes]];
}

- (CGSize)sizeForKey:(NSString *)defaultName;
{
    NSString *stringValue = [[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:defaultName];
    if (!stringValue)
        return CGSizeZero;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    return CGSizeFromString(stringValue);
#else
    return NSSizeFromString(stringValue);
#endif
}

@end
