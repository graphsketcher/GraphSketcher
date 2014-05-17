// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.


#import "OFObject-XML.h"

#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/OFXMLString.h>
#import <OmniFoundation/NSData-OFEncoding.h>

NSString *stringFromBool(BOOL flag)
{
    if (flag)  return @"true";
    else  return @"false";
}
BOOL boolFromString(NSString *string)
{
    OBASSERT([string isEqualToString:@"true"] || [string isEqualToString:@"false"]);
    
    if ([string isEqualToString:@"true"])  return YES;
    else  return NO;
}


OFXMLElement *SkipToNextChildElement(OFXMLCursor *cursor)
{
    id child;
    while ((child = [cursor peekNextChild])) {
        if ([child isKindOfClass:[OFXMLElement class]])
            break;
        [cursor nextChild]; // skip it
    }
    return child;
}


@implementation NSObject (XML)

- (NSString *)readStringStoringWithKey:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName;
{
    OFXMLElement *element = SkipToNextChildElement(cursor);
    if ([[element name] isEqualToString:elementName]) {
        [cursor nextChild]; // consume the element
        
        NSString *str = [OFCharacterDataFromElement(element) copy];
        if (str) {
            if (!key) {
                return [str autorelease];
            } else {
                [self setValue:str forKey:key];
		
                // Not valid to return this value pointer, in general, since the caller might not retain the exact pointer we gave it.
                [str release];
                return [self valueForKey:key];
            }
        }
    }
    return nil;
}

- (NSString *)writeString:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;
{
    NSString *value = [self valueForKey:key];
    if (![NSString isEmptyString:value])
        [xmlDoc appendElement:elementName containingString:value];
    return value;
}

#if 0
- (NSData *)readData:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName importer:(XMLImporter *)importer;
{
    NSData *data = nil;
    NSString *str = [self readStringStoringWithKey:nil fromCursor:cursor elementName:elementName importer:importer];
    if (![NSString isEmptyString:str]) {
        data = [NSData dataWithBase64String:str];
        if ([data length] == 0)
            data = nil;
    }
    
    if (!key)
        return data;
    else {
        SET_VALUE(data, key);
	
        // Not valid to return this value pointer, in general, since the caller might not retain the exact pointer we gave it.
        return [self valueForKey:key];
    }
}
#endif

- (NSData *)writeData:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;
{
    NSData *value = [self valueForKey:key];
    
    if ([value length] == 0)
        value = nil;
    
    [xmlDoc appendElement:elementName containingString:[value base64String]];
    return value;
}

- (BOOL)readBool:(NSString *)key fromCursor:(OFXMLCursor *)cursor attributeName:(NSString *)attributeName;
{
    NSString *str = [cursor attributeNamed:attributeName];
    BOOL value = ([str isEqualToString:@"true"] || [str isEqualToString:@"1"]);
    if (!key)
        return value;
    [self setValue:str forKey:key];
    return [[self valueForKey:key] boolValue];
}

- (BOOL)readBool:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName;
{
    OFXMLElement *element = SkipToNextChildElement(cursor);
    if ([[element name] isEqualToString:elementName]) {
        [cursor nextChild]; // consume the element
        
        NSString *str = OFCharacterDataFromElement(element);
        // If we're in here expecting a boolean from an empty element, it's true by virtue of the element's presence.
        BOOL value = ([NSString isEmptyString:str] || [str isEqualToString:@"true"] || [str isEqualToString:@"1"]);
        if (!key)
            return value;
        [self setValue:[NSNumber numberWithBool:value] forKey:key];
        return [[self valueForKey:key] boolValue];
    }
    return NO;
}

- (BOOL)writeBool:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;
{
    // Skips writing the value if it is nil or NO.
    BOOL value = [[self valueForKey:key] boolValue];
    if (value)
        [xmlDoc appendElement:elementName containingString:@"true"];
    return value;
}


- (NSNumber *)readFloatNumber:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName;
{
    OFXMLElement *element = SkipToNextChildElement(cursor);
    if ([[element name] isEqualToString:elementName]) {
        [cursor nextChild]; // consume the element
        
        NSString *str = OFCharacterDataFromElement(element);
        if (![NSString isEmptyString:str]) {
            float scalar = [str floatValue];
            NSNumber *number = [[NSNumber alloc] initWithFloat:scalar];
            
            // Pass a nil key to not actually apply it to ourselves
            if (!key)
                return [number autorelease];
            
            [self setValue:number forKey:key];

            // Not valid to return this value pointer, in general, since the caller might not retain the exact pointer we gave it.
            [number release];
            return [self valueForKey:key];
        }
    }
    return nil;
}

- (NSNumber *)readIntegerNumber:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName;
{
    OFXMLElement *element = SkipToNextChildElement(cursor);
    if ([[element name] isEqualToString:elementName]) {
        [cursor nextChild]; // consume the element
        
        NSString *str = OFCharacterDataFromElement(element);
        if (![NSString isEmptyString:str]) {
            int scalar = [str intValue];
            NSNumber *number = [[NSNumber alloc] initWithInt:scalar];
            
            // Pass a nil key to not actually apply it to ourselves
            if (!key)
                return [number autorelease];
            
            [self setValue:number forKey:key];

            // Not valid to return this value pointer, in general, since the caller might not retain the exact pointer we gave it.
            [number release];
            return [self valueForKey:key];
        }
    }
    return nil;
}

- (NSNumber *)writeOptionalIntegerNumber:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;
{
    NSNumber *value = [self valueForKey:key];
    if (!value)
        return nil;
    int scalar = [value intValue];
    if (scalar != 0)
        [xmlDoc appendElement:elementName containingInteger:scalar];
    return value;
}

- (NSNumber *)writeRequiredIntegerNumber:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;
{
    NSNumber *value = [self valueForKey:key];
    OBASSERT(value);
    int scalar = [value intValue]; // write zero if absent
    [xmlDoc appendElement:elementName containingInteger:scalar];
    return value;
}

@end
 

