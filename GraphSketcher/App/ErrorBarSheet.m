// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "ErrorBarSheet.h"


@implementation ErrorBarSheet

- (id)init;
{
    return [super initWithWindowNibName:@"ErrorBarSheet"];
}

//- (void)windowDidLoad;
//{
//    NSLog(@"ErrorBarSheet windowDidLoad");
//}

- (void)awakeFromNib;
{
    // Initialize and attach the number formatter here, since we were having problems in certain regions when the formatter was defined in the xib.
    NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    [posOffsetField setFormatter:formatter];
    [negOffsetField setFormatter:formatter];
}

- (data_p)posOffset;
{
    OBASSERT(posOffsetField);
    return fabs([posOffsetField doubleValue]);
}

- (data_p)negOffset;
{
    OBASSERT(negOffsetField);
    return fabs([negOffsetField doubleValue]);
}

- (IBAction)helpButton:(id)sender;
{
    NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"errorbars" inBook:locBookName];
}

- (IBAction)cancelButton:(id)sender;
{
    [NSApp endSheet:[self window] returnCode:NSCancelButton];
}

- (IBAction)okButton:(id)sender;
{
    [NSApp endSheet:[self window] returnCode:NSOKButton];
}

@end
