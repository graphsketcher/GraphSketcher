// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSDataImporter.m 200244M 2013-12-11 07:37:03Z (local) $

#import "RSDataImporter.h"

#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <OmniFoundation/OFPreference.h>
#import <OmniQuartz/OQColor.h>

NSString * const RSDataImporterWarningTitle = @"RSDataImporterWarningTitle";
NSString * const RSDataImporterWarningDescription = @"RSDataImporterWarningDescription";


#if 1 && defined(DEBUG_robin)
static NSString *nameFromColumnType(NSInteger type) {
    switch (type) {
	case RS_UNKNOWN_COL:
	    return @"unknown";
	case RS_FLOAT_COL:
	    return @"number";
	case RS_DATE_COL:
	    return @"date";
	case RS_LABEL_COL:
	    return @"text";
	default:
	    return @"unknown";
    }
}
#endif

// Ensure that the value in the user preference is reasonable.
static NSUInteger maximumDataSetSize() {
    NSInteger maxDataSetSize = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"MaximumDataSetSize"];
    
    // Make sure there's *some* limit even if prefs are messed up
    if (maxDataSetSize < 10)
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        maxDataSetSize = 500;
#else
        maxDataSetSize = 5000;
#endif
    
    return (NSUInteger)maxDataSetSize;
}



@implementation RSDataImporter

static RSDataImporter *sharedDataImporter;
+ (RSDataImporter *)sharedDataImporter;
{
    if (!sharedDataImporter) {
        sharedDataImporter = [[RSDataImporter alloc] init];
    }
    return sharedDataImporter;
}

@synthesize delegate;
@synthesize warning = _warning;


////////////////////
#pragma mark -
#pragma mark Error messages
//////////////////


+ (NSDictionary *)noDataDetectedMessage;
{
    NSString *title = NSLocalizedStringFromTableInBundle(@"GraphSketcher couldn't find any numerical data in the content you pasted.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"No data detected message sheet");
    NSString *description = NSLocalizedStringFromTableInBundle(@"If you want to paste text into your graph, first create a text label and then paste the text inside it.\n\nIf you are trying to import data, try pasting it into a spreadsheet program or a text editor first. Then copy and paste the data you want into GraphSketcher.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"No data detected message sheet");
    
    return [NSDictionary dictionaryWithObjectsAndKeys:title, RSDataImporterWarningTitle,
            description, RSDataImporterWarningDescription, nil];
}

+ (NSDictionary *)tooMuchDataDetectedMessage;
{
    NSString *title = NSLocalizedStringFromTableInBundle(@"That's a lot of data you've got there.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"Too much data detected message sheet");
    
    NSString *description = NSLocalizedStringFromTableInBundle(@"GraphSketcher performs very slowly with more than %1$d data points.  So if you really want to import this much data, you must copy and paste in batches of no more than %1$d points.  Alternatively, you could try importing only a random subset of your data.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"Too much data detected message sheet");
    description = [NSString stringWithFormat:description, maximumDataSetSize(), maximumDataSetSize()];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:title, RSDataImporterWarningTitle,
            description, RSDataImporterWarningDescription, nil];
}

+ (NSDictionary *)suspectRowDataMessage;
{
    NSString *title = NSLocalizedStringFromTableInBundle(@"It looks like your data is in rows.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"Suspect data in rows message sheet");
    NSString *description = NSLocalizedStringFromTableInBundle(@"GraphSketcher is not designed to import data series in rows.  If the result you see on the graph is not what you expect, re-orient your data file so that the data series are in columns.  Then copy and paste the columns back into GraphSketcher.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"Suspect data in rows message sheet");
    
    return [NSDictionary dictionaryWithObjectsAndKeys:title, RSDataImporterWarningTitle,
            description, RSDataImporterWarningDescription, nil];
}

+ (NSDictionary *)dataSkippedMessageWithNumberImported:(NSUInteger)nmofVertices numberSkipped:(NSUInteger)skipped;
{
    if (skipped == 0)
        return nil;
    
    NSString *skippedFormat;
    if( skipped == 1 )
        skippedFormat = NSLocalizedStringFromTableInBundle(@"%1$d data points were imported and %2$d was skipped.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"Data skipped message sheet - 1 data point");
    else
        skippedFormat = NSLocalizedStringFromTableInBundle(@"%1$d data points were imported and %2$d were skipped.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"Data skipped message sheet - plural data points");
    
    NSString *skippedMessage = [NSString stringWithFormat:skippedFormat, nmofVertices, skipped];
    
    NSString *description = NSLocalizedStringFromTableInBundle(@"GraphSketcher was not able to interpret some of the data you pasted. This could be because some values in the original data were blank.\n\nYou should double-check that the data was imported correctly. If you are having trouble importing data, try pasting it into a spreadsheet program or a text editor first. Then copy and paste the data you want into GraphSketcher.", @"GraphSketcherModel-DataImporter", OMNI_BUNDLE, @"Data skipped message sheet");
    
    return [NSDictionary dictionaryWithObjectsAndKeys:skippedMessage, RSDataImporterWarningTitle,
            description, RSDataImporterWarningDescription, nil];
}



////////////////////
#pragma mark -
#pragma mark Value separator determination
//////////////////

static NSString *_cachedThousandsSeparator = nil;

+ (void)clearLocaleCache;
{
    [_cachedThousandsSeparator release];
    _cachedThousandsSeparator = nil;
}

+ (NSString *)thousandsSeparator;
// Returns comma or period -- whichever one is *not* the decimal separator.  This varies by country and is set in System Prefs.
{
    if (_cachedThousandsSeparator) {
        return _cachedThousandsSeparator;
    }
    
    // Account for localization differences
    NSNumberFormatter *localizedFormatter = [[NSNumberFormatter alloc] init];
    [localizedFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSString *decimalSeparator = [localizedFormatter decimalSeparator];
    [localizedFormatter release];
    
    if ( [decimalSeparator isEqualToString:@","] )
        _cachedThousandsSeparator = [[NSString alloc] initWithString:@"."];
    else
        _cachedThousandsSeparator = [[NSString alloc] initWithString:@","];
    return _cachedThousandsSeparator;
}

+ (NSArray *)valueSeparators;
{
    NSArray *defaultSeparators = [[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:@"DataFieldSeparators"];
    
    return [defaultSeparators arrayByAddingObject:[RSDataImporter thousandsSeparator]];
}



////////////////////////
#pragma mark -
#pragma mark Cells
///////////

// CSV reference:
// http://tools.ietf.org/html/rfc4180

+ (NSString *)trimWhitespaceAndRemoveQuotes:(NSString *)cell;
{
    NSString *newCell = [cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSUInteger length = [newCell length];
    
    if (length >= 2 && [newCell hasPrefix:@"\""] && [newCell hasSuffix:@"\""]) {
	if (length == 2)
	    return @"";
	    
	return [newCell substringWithRange:NSMakeRange(1, length - 2)];
    }
    
    return newCell;
}

// empty data slots do not contribute to voting for column types
+ (BOOL)isABlank:(NSString *)string {
    if( [string isEqualToString:@""] )  return YES;
    else  return NO;
}

static NSCharacterSet *numberAdornmentCharacterSet = nil;
+ (NSString *)unadornedString:(NSString *)string;
// Removes common adornments that confuse the localized float scanner.
// Chart of unicode currency symbols: http://unicode.org/charts/PDF/U20A0.pdf
//
// Also handles negative numbers indicated by "-45" or "(45)".
// Also removes thousands-separators ("," or "." depending on locale).
{
    if (!numberAdornmentCharacterSet) {
	NSString *currencyChars = @"$¢£¤¥ƒ৲৳૱௹􏰂¤ℳ元円圆圓﷼₠₡₢₣₤₥₦₧₨₩₪₫€₭₮₯􏰀􏰁₲₳₴₵ȻGRs";
	NSString *otherChars = @"%~ ";
	NSString *adornments = [[NSString stringWithString:currencyChars] stringByAppendingString:otherChars];
	numberAdornmentCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:adornments] retain];
    }
    
    // do an initial trim, to handle values like " ~(45.3)¢"
    string = [string stringByTrimmingCharactersInSet:numberAdornmentCharacterSet];
    
    // handle negative values like "-$9,659"
    BOOL makeNegative = NO;
    if ([string length] > 1 && [string characterAtIndex:0] == '-') {
        makeNegative = YES;
        string = [string substringFromIndex:1];
    }
    // handle negative values like "($9,659)"
    else if ([string length] > 2 && [string characterAtIndex:0] == '(' && [string characterAtIndex:[string length] - 1] == ')' ) {
        makeNegative = YES;
        string = [string substringWithRange:NSMakeRange(1, [string length] - 2)];
    }
    
    // trim the inner string
    NSString *newString = [string stringByTrimmingCharactersInSet:numberAdornmentCharacterSet];
    
    if (makeNegative) {
        newString = [NSString stringWithFormat:@"-%@", newString];
    }
    
    // remove thousands separators so as not to confuse the NSScanner
    newString = [[newString componentsSeparatedByString:[RSDataImporter thousandsSeparator]] componentsJoinedByString:@""];
    newString = [[newString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString:@""];  // some locales use a space as a thousands separator (e.g. French/France)
    
    return newString;
}

+ (BOOL)isAFloat:(NSString *)string
// returns YES if string should be treated as a floating point number
{
    return [RSDataImporter getDoubleValue:NULL forString:string];
}

+ (BOOL)getDoubleValue:(double *)doubleVal forString:(NSString *)string;
// Converts a string to a float using the localized defaults (i.e. "." vs ",")
// Converts (45) to -45
{
    NSString *unadorned = [RSDataImporter unadornedString:string];
    NSScanner *scanner = [NSScanner localizedScannerWithString:unadorned];
    
    BOOL scannedValue = [scanner scanDouble:doubleVal];
    
    BOOL isAtEnd = [scanner isAtEnd];
    
    if( scannedValue && isAtEnd ) {
	return YES;
    }
    return NO;
}

+ (BOOL)cell:(NSString *)cell matchesType:(int)type {
    if( type == RS_FLOAT_COL && [RSDataImporter isAFloat:cell] )  return YES;
    else if( type == RS_DATE_COL && [RSDataImporter isADate:cell] )  return YES;
    else if ( type == RS_LABEL_COL )  return YES;
    else  return NO;
}

+ (double)doubleValueOfCell:(NSString *)cell withType:(int)type {
    if( type == RS_FLOAT_COL ) {
	double value = 0;
	[RSDataImporter getDoubleValue:&value forString:cell];
	return value;
    }
//    else if( type == RS_DATE_COL ) {
//	return [[RSDataImporter dateValueOfString:cell] timeIntervalSinceReferenceDate];
//    }
    else {
	NSLog(@"Error: cell type %d cannot be converted to a float", type);
	return 0;
    }
}

+ (BOOL)isNumberType:(NSInteger)type {
    if( type == RS_FLOAT_COL || type == RS_DATE_COL )  return YES;
    else  return NO;
}


+ (BOOL)isADate:(NSString *)string {
    return NO;  //! Dates are not supported yet
    
//    if( [RSDataImporter dateValueOfString:string] != nil )  return YES;
//    else  return NO;
}
//+ (NSDate *)dateValueOfString:(NSString *)string {
//    return [NSDate dateWithNaturalLanguageString:string locale: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
//}
/*
+ (NSDate *)dateValueOfString:(NSString *)string {
	NSDateFormatter *formatter = [RSNumber sharedDateFormatter];
	[formatter setTwoDigitStartDate:[NSDate date]];
	[formatter setDateStyle:NSDateFormatterNoStyle];
	NSDate *date;
	NSString *error;
	
	return [NSDate dateWithNaturalLanguageString:string];
	
	if( [formatter getObjectValue:&date forString:string errorDescription:&error] ) {
		return date;
	}
	else {
		NSLog(@"Date parse error: %@", error);
		return nil;
	}
	//return [formatter dateFromString:string];
}
*/




////////////////////////
#pragma mark Rows
///////////

+ (BOOL)isEmptyRow:(NSArray *)row;
{
    for (NSString *cell in row) {
        //NSString *trimmedCell = [cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![cell isEqualToString:@""]) {
            return NO;
        }
    }

    return YES;
}

+ (BOOL)rowIsAllLabels:(NSArray *)row {
    NSString *cell;
    for (cell in row) {
	if( [RSDataImporter isAFloat:cell] )  return NO;
    }
    // if got this far...
    return YES;
}


////////////////////////
#pragma mark Tables
///////////

+ (BOOL)tableIsAllLabels:(NSArray *)table;
{
    for (NSArray *row in table) {
	if (![RSDataImporter rowIsAllLabels:row])
	    return NO;
    }
    return YES;
}

// this should only be called once per import, if possible
+ (NSUInteger)numberOfColumnsInTable:(NSArray *)table {
    NSArray *row;
    NSUInteger cols = 0;
    for (row in table) {
	if ([row count] > cols ) {
	    cols = [row count];
	}
    }
    return cols;
}

static NSUInteger columnTypeForCell(NSString *cell) {
    if( [RSDataImporter isABlank:cell] ) {
        return RS_UNKNOWN_COL;
    }
    else if( [RSDataImporter isAFloat:cell] ) {  // if it's a float
        return RS_FLOAT_COL;
    }
    else if( [RSDataImporter isADate:cell] ) {  // if it's a date
        return RS_DATE_COL;
    }
    else {  // default to a label
        return RS_LABEL_COL;
    }
}

// returns an array of column types
+ (void)detectColumnTypes:(NSArray *)table intoArray:(NSInteger *)types {
    // get the number of columns
    NSUInteger nmofCols = [RSDataImporter numberOfColumnsInTable:table];
    NSUInteger nmofTypes = RS_NM_OF_COL_TYPES;  // unknown, label, float, date
    
    // set up the result array and the voting matrix
    NSUInteger votes[nmofCols][nmofTypes];
    NSUInteger j, k;
    for( j=0; j<nmofCols; j++ ) {
	types[j] = RS_FLOAT_COL;
	for( k=0; k<nmofTypes; k++ ) {
	    votes[j][k] = 0;
	}
    }
    
    // determine the start and end indices of rows to check
    NSUInteger checkStart, checkEnd;
    if( [table count] == 1 )  checkStart = 0;
    else  checkStart = 1;  // skip a potential header
    checkEnd = [table count];
    if( checkEnd > 30 )
	checkEnd = 30;  // check up to 30 rows, not including header
    
    NSUInteger rowsAnalyzed = 0;
    NSUInteger i;
    for( i=checkStart; i<checkEnd; i++ ) {
	NSArray *row = [table objectAtIndex:i];
	for( j=0; j<nmofCols; j++ ) {
	    if (j >= [row count]) {
		continue;
	    }
	    NSString *cell = [row objectAtIndex:j];
            NSUInteger colType = columnTypeForCell(cell);
            if (colType != RS_UNKNOWN_COL) {  // do not vote if the cell is empty
                votes[j][colType] += 1;
            }
	}
        rowsAnalyzed += 1;
    }
    
    // Find out whether some columns have no votes (i.e. were blank)
    BOOL checkMoreRows = NO;
    if ([table count] > checkEnd) {
        for (j=0; j<nmofCols; j++) {
            NSUInteger totalVotes = 0;
            for (k=0; k<nmofTypes; k++) {
                totalVotes += votes[j][k];
            }
            if (totalVotes == 0) {
                checkMoreRows = YES;
                break;
            }
        }
    }
    
    // If some columns had no votes, check up to 20 more rows, this time starting from the end of the table
    if (checkMoreRows) {
        checkStart = [table count] - 20;
        if (checkStart < checkEnd) {
            checkStart = checkEnd;
        }
        checkEnd = [table count];
        for( i=checkStart; i<checkEnd; i++ ) {
            NSArray *row = [table objectAtIndex:i];
            for( j=0; j<nmofCols; j++ ) {
                if (j >= [row count]) {
                    continue;
                }
                NSString *cell = [row objectAtIndex:j];
                NSUInteger colType = columnTypeForCell(cell);
                if (colType != RS_UNKNOWN_COL) {  // do not vote if the cell is empty
                    votes[j][colType] += 1;
                }
            }
            rowsAnalyzed += 1;
        }
    }
    
    DEBUG_DATA_IMPORT(@"Analyzed cell type for %ld rows", (long)rowsAnalyzed);
    
    // find out who won
    for( j=0; j<nmofCols; j++ ) {
	NSUInteger winner = RS_UNKNOWN_COL;
	NSUInteger mostvotes = 0;
	for( k=0; k<nmofTypes; k++ ) {
	    if( votes[j][k] > mostvotes ) {
		winner = k;
		mostvotes = votes[j][k];
	    }
	}
	// if type is still "unknown" then take a best guess
	if( winner == RS_UNKNOWN_COL )  winner = RS_LABEL_COL;
	
	// declare a winning type for column j
	types[j] = winner;
    }
    
    // that's all
    
#if 1 && defined(DEBUG_robin)
    NSMutableString *cat = [NSMutableString stringWithFormat:@"Col types: "];
    BOOL first = YES;
    for (i=0; i<nmofCols; i++) {
	if (!first)
	    [cat appendString:@", "];
	[cat appendFormat:@"%@", nameFromColumnType(types[i])];
	first = NO;
    }
    DEBUG_DATA_IMPORT(@"%@", cat);
#endif
}


////////////////////////////////
// parse an input string into rows
//
// return an array of rows - each row an array
// return nil if string was not parse-able
- (NSArray *)tableFromString:(NSString *)rawString;
{
    
    if ( !rawString || [rawString isEqualToString:@""] ) {
        self.warning = [RSDataImporter noDataDetectedMessage];
	return nil;
    }
    
    //DEBUG_DATA_IMPORT(@"rawString: '%@'", rawString);
    
    // Reset caches just in case the user has changed the locale (testers are likely to do this, and customers might do it occasionally if they want to import data formatted differently from their standard locale).
    [RSDataImporter clearLocaleCache];
    
    
    /* Adapted from:
     Split a string into an array of lines; unicode-aware
     Original Source: <http://cocoa.karelia.com/Foundation_Categories/NSString/Split_Into_LInes.m>
     (See copyright notice at <http://cocoa.karelia.com>)
     */
    NSMutableArray *lines = [NSMutableArray array];
    NSRange range = NSMakeRange(0,0);
    NSString *possible;
    NSUInteger start, end;
    NSUInteger contentsEnd = 0;
    NSUInteger nmofRows = 0;
    NSUInteger rawLength = [rawString length];
    while (contentsEnd < rawLength)
    {
	[rawString getLineStart:&start end:&end contentsEnd:&contentsEnd forRange:range];
	possible = [rawString substringWithRange:NSMakeRange(start,contentsEnd-start)];
	//if ( [self containsAFloat:possible] )  
	if( [[possible stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] > 0 )
	    //if( contentsEnd - start > 0 ) 
	{
	    [lines addObject:possible];
	    nmofRows++;
	}
	range.location = end;
	range.length = 0;
        
        NSUInteger maxDataSetSize = maximumDataSetSize() + 2; // Fudge factor for headers/footers
	
	if ( nmofRows > maxDataSetSize ) {
	    self.warning = [RSDataImporter tooMuchDataDetectedMessage];
	    return nil;
	}
    }
    
    if ( [lines count] == 0 ) {
	self.warning = [RSDataImporter noDataDetectedMessage];
	
	return nil;
    }
    // else, continue
    DEBUG_DATA_IMPORT(@"%ld rows of data found.", nmofRows);
    
    //
    // find appropriate value separator
    //
    
    // For each known value separator, calculate how many components we get in the first 10 lines if we split using that separator.
    NSUInteger checkRows = nmofRows;
    if (checkRows > 10) {
	checkRows = 10;
    }
    
    NSArray *valueSeparators = [RSDataImporter valueSeparators];
    NSMutableDictionary *separatorTotals = [NSMutableDictionary dictionaryWithCapacity:[valueSeparators count]];
    for (NSString *candidate in valueSeparators) {
        NSUInteger total = 0;
        for ( NSUInteger j = 0; j < checkRows; j++ ) {
	    NSUInteger count = [[[lines objectAtIndex:j] componentsSeparatedByString:candidate] count];
	    total += count;
	}
        [separatorTotals setValue:[NSNumber numberWithInteger:total] forKey:candidate];
    }
    
    NSString *valueSeparator = @"";  // by default, use the empty string, which means "just use line breaks"
    
    for (NSString *candidate in valueSeparators) {
        NSUInteger total = [[separatorTotals valueForKey:candidate] unsignedIntegerValue];
        if (total > checkRows) {
            valueSeparator = candidate;
            break;
        }
    }
    
    // Space char (' ') delimiters are currently disabled.  If we allow space delimiters, we'll have to only separate on spaces that fall between numeric values as defined by +[isAFloat].  This is because we should handle data like:
    // my first data pair 3 12.6
    // my second data pair 4 15.5
    
    OBASSERT(valueSeparator != nil);
    DEBUG_DATA_IMPORT(@"Chose value separator: '%@'", valueSeparator);
    
    
    //
    // parse all the lines using the value separator
    // (the object "table" will be an array of arrays)
    //
    NSMutableArray *table = [NSMutableArray arrayWithCapacity:[lines count]];
    
    NSMutableCharacterSet *whiteSpaceSet = [[[NSCharacterSet whitespaceCharacterSet] mutableCopy] autorelease];
    [whiteSpaceSet removeCharactersInString:valueSeparator];
    
    for (NSString *line in lines){
        // reduce memory footprint in case there are a lot of elements to be processed
        NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
        
        // If no value separator was found, use the whole line, possibly minus quotes
        if ([valueSeparator isEqualToString:@""]) {
            NSString *cell = [RSDataImporter trimWhitespaceAndRemoveQuotes:line];
            NSMutableArray *row = [NSMutableArray arrayWithObject:cell];
            [table addObject:row];
            
            [subPool release];
            continue;
        }
        
        
        NSMutableArray *row = [[NSMutableArray alloc] init];  // Needs to survive past the autorelease subPool being released
        
        // Set up the string scanner
        NSScanner *scanner = [NSScanner localizedScannerWithString:line];
        [scanner setCharactersToBeSkipped:whiteSpaceSet];
        
        NSString *cell;
        BOOL endedCell;
        BOOL rowHasMoreCells = YES;
        
        while (rowHasMoreCells) {
            cell = [NSString string];
            
            // If the value is quoted, scan until we find the end quote
            BOOL startedQuote = [scanner scanString:@"\"" intoString:NULL];
            if (startedQuote) {
                BOOL endedQuote = [scanner scanUpToString:@"\"" intoString:&cell];
                if (!endedQuote) {
                    OBASSERT_NOT_REACHED("Unbalanced quotes.  Probably this imported data is corrupted somehow.");
                    // TODO: Should probably trigger a warning message to the user
                }
                endedCell = [scanner scanUpToString:valueSeparator intoString:NULL];
            }
            
            // If the value is not quoted, scan until we find a separator (or the end of the line).
            else {
                endedCell = [scanner scanUpToString:valueSeparator intoString:&cell];
                
                // also, trim whitespace if not quoted
                cell = [cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
            
            // Scan past the value separator
            rowHasMoreCells = [scanner scanString:valueSeparator intoString:NULL];
            
            // Add the cell, unless it's empty AND we're at the end of the row
            if (endedCell || rowHasMoreCells) {
                [row addObject:cell];
            }
        }
        
        
        // Deal with trailing commas:
        if ([row count]) {
            NSString *stringByRemovingWhitespace = [[[row lastObject] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
            if ([stringByRemovingWhitespace isEqualToString:@""]) {
                [row removeLastObject];
            }
        }
        
        [subPool release];
        
        if ([RSDataImporter isEmptyRow:row]) {
            DEBUG_DATA_IMPORT(@"Skipping empty row");
        }
        else {
            [table addObject:row];
        }
        [row release];
    }

    DEBUG_DATA_IMPORT(@"Finished creating data table.");
    

#if 0 && defined(DEBUG_robin)
    // Print the imported table to the console
    for (NSArray *line in table) {
	NSMutableString *cat = [[NSMutableString alloc] init];
	BOOL first = YES;
	for (NSString *s in line) {
	    if (!first)
		[cat appendString:@", "];
	    [cat appendFormat:@"'%@'", s];
	    first = NO;
	}
	DEBUG_DATA_IMPORT(@"i | %@", cat);
	[cat release];
    }
#endif
    
    
    
    //
    // for debugging dates, print out date values
    /*
    if( RS_LOGGING_LEVEL >= 1 ) {
	    E = [lines objectEnumerator];
	    NSArray *row;
	    NSDate *date;
	    while( row = [E nextObject] ) {
		    s = [row objectAtIndex:0];
		    date = [RSDataImport dateValueOfString:s];
		    NSLog(@"\"%@\" --> %@", s, date);
	    }
    }
     */
    
    return table;
}

- (NSArray *)transposeTable:(NSArray *)table numberOfColumns:(NSUInteger)nmofCols;
{
    NSMutableArray *newTable = [NSMutableArray array];
    // Create a row for each incoming column
    for (NSUInteger i=0; i < nmofCols; i += 1) {
        [newTable addObject:[NSMutableArray array]];
    }
    
    // Number of incoming rows
    NSUInteger nmofRows = [table count];
    
    for (NSUInteger r=0; r < nmofRows; r += 1) {
        NSArray *line = [table objectAtIndex:r];
        
        for (NSUInteger c=0; c < nmofCols; c += 1) {
            // Don't raise an exception if the incoming row doesn't have the expected number of columns
            if (c >= [line count])
                break;
            NSString *cell = [line objectAtIndex:c];
            
            // Put the cell in its transposed position in the new table
            NSMutableArray *newLine = [newTable objectAtIndex:c];
            [newLine addObject:cell];
        }
    }
    
    return newTable;
}


////////////////////
#pragma mark -
#pragma mark Graph methods
//////////////////



+ (RSVertex *)createVertexWithX:(data_p)xval y:(data_p)yval label:(NSString *)text forGraph:(RSGraph *)graph;
{
    RSVertex *V;
    RSTextLabel *L;
    
    V = [[[RSVertex alloc] initWithGraph:graph] autorelease];
    [V setPosition:RSDataPointMake(xval, yval)];
    if( text && ![text isEqualToString:@""] ) {
	L = [[[RSTextLabel alloc] initWithGraph:graph] autorelease];
	[L setOwner:V];
	[V setText:text];
    }
    //[V setShape:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultVertexShape"]];
    
    return V;
}



- (NSMutableArray *)verticesFromTable:(NSArray *)table startRow:(NSUInteger)startRow xColumn:(NSUInteger)xCol yColumn:(NSUInteger)yCol usePointLabels:(NSInteger)pointLabelsColumn forGraph:(RSGraph *)graph;
{
    DEBUG_DATA_IMPORT(@"Processing 2D column set (%ld, %ld)", xCol, yCol);
    OBPRECONDITION(xCol < yCol);
    OBPRECONDITION(startRow < [table count]);
    
    NSUInteger skipped = 0;
    NSMutableArray *vertices = [NSMutableArray arrayWithCapacity:[table count] - startRow];
    
    NSUInteger index = 0;
    for (NSArray *row in table) {
	// skip possible header rows
	if (index < startRow) {
	    index += 1;
	    continue;
	}
	
	// check that our columns actually exist in this row
	if ([row count] < yCol + 1) {
	    DEBUG_DATA_IMPORT(@"Skipping a row due to a lack of columns");
	    skipped += 1;
	    continue;
	}

	NSString *xCell = [row objectAtIndex:xCol];
	NSString *yCell = [row objectAtIndex:yCol];
	
	// reduce memory footprint in case there are a lot of elements to be processed
	NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
	
	data_p x, y;
	if ( ![RSDataImporter getDoubleValue:&x forString:xCell] || ![RSDataImporter getDoubleValue:&y forString:yCell] ) {
	    DEBUG_DATA_IMPORT(@"Skipping a row because one or more of the cells is not a number");
	    skipped += 1;
	    continue;
	}
	
	NSString *label = nil;
	if (pointLabelsColumn >= 0 && (NSInteger)[row count] > pointLabelsColumn) {
	    label = [row objectAtIndex:pointLabelsColumn];
	}
	
	[vertices addObject:[RSDataImporter createVertexWithX:x y:y label:label forGraph:graph]];
	
	[subPool release];
    }
    
    _skippedRows += skipped;
    
    DEBUG_DATA_IMPORT(@"Finished processing 2D column set (%ld, %ld)", xCol, yCol);
    return vertices;
}

- (NSMutableArray *)verticesFromTable:(NSArray *)table startRow:(NSUInteger)startRow singleColumn:(NSUInteger)col forGraph:(RSGraph *)graph;
{
    DEBUG_DATA_IMPORT(@"Processing single column %ld", col);
    
    NSUInteger skipped = 0;
    NSMutableArray *vertices = [NSMutableArray arrayWithCapacity:[table count]];
    NSUInteger counter = 0;
    
    NSUInteger index = 0;
    for (NSArray *row in table) {
	// skip possible header rows
	if (index < startRow) {
	    index += 1;
	    continue;
	}
	
	// check that the column exists in this row
	if ([row count] < col + 1) {
	    DEBUG_DATA_IMPORT(@"Skipping a row due to lack of columns");
	    skipped += 1;
	    continue;
	}
	
	NSString *cell = [row objectAtIndex:col];
	// get the value and check that it is actually a number
	data_p y;
	if (![RSDataImporter getDoubleValue:&y forString:cell]) {
	    DEBUG_DATA_IMPORT(@"Skipping a row because the cell is not a number");
	    skipped += 1;
	    continue;
	}
	
	counter += 1;
	RSVertex *V = [RSDataImporter createVertexWithX: (data_p)counter
						      y: y
						  label: nil
					       forGraph: graph ];
	[vertices addObject:V];
    }
    
    _skippedRows += skipped;
    return vertices;
}


static RSAxis *_shouldHideEndLabels = nil;

+ (void)labelXAxisFromTable:(NSArray *)table startRow:(NSUInteger)startRow labelColumn:(NSUInteger)col forGraph:(RSGraph *)graph;
{
    DEBUG_DATA_IMPORT(@"Processing column of labels %ld", col);
    
    RSAxis *axis = [graph xAxis];
    NSUInteger counter = 0;
    
    NSUInteger index = 0;
    for (NSArray *row in table) {
	// skip header rows
	if (index < startRow) {
	    index += 1;
	    continue;
	}
	
	if (col >= [row count])
	    continue;
	
	NSString *cell = [row objectAtIndex:col];
	
	counter += 1;
	[axis setUserString:cell forTick:counter];
    }
    
    if (counter > 0) {
        [graph.delegate modelChangeRequires:RSUpdateWhitespace];
    }
    
    // make sure all pasted labels are visible:
    [axis setUserSpacing:1];
    if( counter > [graph xMax] ) {
	[graph setXMax:counter];
    }
    // hide x-axis end labels
    _shouldHideEndLabels = [graph xAxis];
}

+ (void)labelTitleOfAxis:(RSAxis *)axis fromTable:(NSArray *)table headerRow:(NSUInteger)headerRow column:(NSUInteger)col forGraph:(RSGraph *)graph;
{
    OBPRECONDITION(headerRow < [table count]);
    if (headerRow >= [table count])
	return;
    
    NSArray *header = [table objectAtIndex:headerRow];
    
    if (col >= [header count])
	return;
    
    // We don't currently have NSString-OFExtensions in the iPad app
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    NSString *title = [[header objectAtIndex:col] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
#else
    NSString *title = [[header objectAtIndex:col] stringByCollapsingWhitespaceAndRemovingSurroundingWhitespace];
#endif
    if ([title isEqualToString:@""])
	return;
    
    RSTextLabel *axisTitleLabel = [axis title];
    [axisTitleLabel setText:title];
    
    DEBUG_DATA_IMPORT(@"Labeled %@ title from header column %ld", labelNameFromOrientation([axis orientation]), col);
}


//+ (NSUInteger)processHeaderRowsForTable(NSMutableArray *)table graph:(RSGraph *)graph;
//{
//    
//}


///////////////
#pragma mark -
#pragma mark The main import methods
///////////////

- (NSArray *)_dataSeriesFromString:(NSString *)string forGraph:(RSGraph *)graph;
// returns an array of RSGroups of RSVertices to add to the graph
{
    //////////////////////////////
    //
    // Let floats and dates both be types of "numbers".
    // Then there are x cases:
    //  * [label, number] and [label] and [number]
    //  * [label, number, number(, more numbers)] and [number, number(, more numbers)]
    //
    // That is, the data is either 1-D or 2-D; and there may or may not be labels in
    // the first column.
    //
    ////////////////////////////
    
    _skippedRows = 0;
    self.warning = nil;
    
    //
    // parse the string into an array of arrays:
    //
    NSArray *table = [self tableFromString:string];
    // return if nothing found:
    if( !table )
	return nil;  // (the appropriate dialog sheet has already been generated)
    
    //
    // Get stats and initialize some variables
    //
    NSUInteger nmofRows = [table count];
    if (!nmofRows) {
	self.warning = [RSDataImporter noDataDetectedMessage];
	return nil;
    }
    
    NSUInteger nmofCols = [RSDataImporter numberOfColumnsInTable:table];
    if (!nmofCols) {
	self.warning = [RSDataImporter noDataDetectedMessage];
	return nil;
    }
    
    // Transpose if necessary
    OFPreferenceWrapper *prefWrapper = [OFPreferenceWrapper sharedPreferenceWrapper];
    if ([prefWrapper boolForKey:@"ImportDataSeriesAsRows"]) {
        DEBUG_DATA_IMPORT(@"Transposing table");
        table = [self transposeTable:table numberOfColumns:nmofCols];
    }
    
    DEBUG_DATA_IMPORT(@"Table has %ld rows, %ld columns", nmofRows, nmofCols);
    
    // Master array that will be returned at the end
    NSMutableArray *vertices = [NSMutableArray array];
    
    //
    // Do the interpreting...
    //
    
    // get the column types
    NSInteger types[nmofCols];
    [RSDataImporter detectColumnTypes:table intoArray:types];
    
    NSMutableArray *numberColumns = [NSMutableArray array];
    NSInteger firstLabelsColumn = -1;
    for (NSUInteger i=0; i<nmofCols; i++) {
	if ([RSDataImporter isNumberType:types[i]]) {
	    [numberColumns addObject:[NSNumber numberWithInteger:i]];
	}
        else if (firstLabelsColumn == -1 && types[i] == RS_LABEL_COL) {
            firstLabelsColumn = i;
        }
    }
    
    //
    // If no numeric columns found, just paste the text as a label
    //
    if( (nmofRows <= 10 && [RSDataImporter tableIsAllLabels:table])
       || (nmofRows == 1 && nmofCols - [numberColumns count] > 0) ) {  // i.e. if there is some text included
	DEBUG_DATA_IMPORT(@"Make a text label from pasted data");
	
	// make a text label:
	RSTextLabel *TL = [[[RSTextLabel alloc] initWithGraph:graph] autorelease];
	[TL setText:string];
	
	// (RSGraphView will center the label on the canvas)
	
	RSGroup *group = [RSGroup groupWithGraph:graph];
	[group addElement:TL];
	[vertices addObject:group];
	
	return vertices;
    }
    
    
    // Check for a data set that's too big
    NSInteger columnsToCount = [numberColumns count] - 1;
    if (columnsToCount < 1) {  // for example, if the import is a text column only
        columnsToCount = 1;
    }
    NSUInteger dataSetSize = columnsToCount * nmofRows;
    DEBUG_DATA_IMPORT(@"Data set size: %ld", dataSetSize);
    if ( dataSetSize > maximumDataSetSize() ) {
	self.warning = [RSDataImporter tooMuchDataDetectedMessage];
	return nil;
    }
    
    // Check for a data set that looks suspiciously like it's in rows instead of columns
    if (nmofRows == 2 && nmofCols > 10) {
        self.warning = [RSDataImporter suspectRowDataMessage];
    }

    
    //////////////////////////////
    // for one or more rows...
    
    // 
    // If only labels were found, use the first column as x-axis tick labels
    //
    if (nmofCols > 0 && ![numberColumns count]) {
	DEBUG_DATA_IMPORT(@"Only labels were found; using column %d for x-axis tick labels", 0);
	
	[RSDataImporter labelXAxisFromTable:table startRow:0 labelColumn:0 forGraph:graph];
	
	// Need to update the display
	return nil;
    }
    
    //
    // Process number columns
    //
    NSUInteger xCol = [[numberColumns objectAtIndex:0] intValue];
    [numberColumns removeObjectAtIndex:0];
    NSArray *yColumns = numberColumns;
    NSUInteger nmofVertices = 0;
    
    //
    // Process header
    //
    NSUInteger startRow = 0;
    while ([RSDataImporter rowIsAllLabels:[table objectAtIndex:startRow]]) {
	startRow += 1;
	if (startRow >= nmofRows) {
	    // Only header rows were found
	    OBASSERT_NOT_REACHED("We shouldn't have gotten this far if there were no rows with numbers");
	    return nil;
	}
    }
    if (startRow >= 1) {
	DEBUG_DATA_IMPORT(@"Skipping %ld header rows", startRow);
    }
    
    
    //
    // If just one numeric column found, process it as 1-dimensional data (use a counter for x-values)
    //
    RSAxis *xAxis = [graph xAxis];
    RSAxis *yAxis = [graph yAxis];
    
    if (![yColumns count]) {
	
	// Set the y-axis title
	if (startRow >= 1) {
	    [RSDataImporter labelTitleOfAxis:yAxis fromTable:table headerRow:(startRow - 1) column:xCol forGraph:graph];
	}
	
	// Potentially use the first column to label the x-axis
	if (xCol > 0) {
	    [RSDataImporter labelXAxisFromTable:table startRow:startRow labelColumn:0 forGraph:graph];
	    
	    // Set the x-axis title
	    if (startRow >= 1) {
		[RSDataImporter labelTitleOfAxis:xAxis fromTable:table headerRow:(startRow - 1) column:0 forGraph:graph];
	    }
	}
	
	NSMutableArray *series = [self verticesFromTable:table startRow:startRow singleColumn:xCol forGraph:graph];
	nmofVertices += [series count];
        
        CGFloat maxToUse = nmofVertices + 1;
        // If there is nothing on the graph yet, then set the x-range with abandon
        if ([[graph userElements] count] == 0) {
            [xAxis setMin:0 andMax:maxToUse];
        }
        // If objects are already on the graph, then only expand the range if necessary
        else {
            if ([xAxis min] > 0)
                [xAxis setMin:0];
            if ([xAxis max] < maxToUse)
                [xAxis setMax:maxToUse];
        }
	
	RSGroup *group = [[[RSGroup alloc] initWithGraph:graph identifier:nil elements:series] autorelease];
	[vertices addObject:group];
    }
    
    
    //
    // If multiple numeric columns were found, process each extra column as y-values
    //
    
    else {
	// Potentially set axis titles
	if (startRow >= 1) {
	    [RSDataImporter labelTitleOfAxis:xAxis fromTable:table headerRow:(startRow - 1) column:xCol forGraph:graph];
	    if ([yColumns count] == 1) {
		NSUInteger yCol = [[yColumns objectAtIndex:0] intValue];
		[RSDataImporter labelTitleOfAxis:yAxis fromTable:table headerRow:(startRow - 1) column:yCol forGraph:graph];
	    }
	}
	
	// Special case for two number columns and at least one text column: use the text column as point labels.
	BOOL pointLabelsColumn = -1;
        if ([yColumns count] == 1 && firstLabelsColumn >= 0 && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"ImportTextColumnAsPointLabels"]) {
	    DEBUG_DATA_IMPORT(@"Using column %ld as point labels.", firstLabelsColumn);
	    pointLabelsColumn = firstLabelsColumn;
	}
	
	for (NSNumber *yColumn in yColumns) {
	    NSMutableArray *series = [self verticesFromTable:table startRow:startRow xColumn:xCol yColumn:[yColumn intValue] usePointLabels:pointLabelsColumn forGraph:graph];
	    if (![series count]) {
		OBASSERT_NOT_REACHED("No vertices were processed from a y-column");
		continue;
	    }
	    nmofVertices += [series count];
	    
	    // Put the series in a group
	    RSGroup *group = [[[RSGroup alloc] initWithGraph:graph identifier:nil elements:series] autorelease];
	    
	    // Add group to the master array that we will ultimately return
	    [vertices addObject:group];
	}
    }
    
    
    //
    // Warn if skipped incomplete rows
    //
    self.warning = [RSDataImporter dataSkippedMessageWithNumberImported:nmofVertices numberSkipped:_skippedRows];
    
    
    //
    // Finally, returns an array of RSGroups. Each group contains all vertices in a data series.
    ///
    return vertices;
}


- (void)processDataSeries:(RSGroup *)series addToGroup:(RSGroup *)everything width:(CGFloat)width shape:(NSUInteger)shape color:(OQColor *)currentColor connectMethod:(RSConnectType)connectMethod dashStyle:(NSInteger)dashStyle;
{
    OBASSERT([series isKindOfClass:[RSGroup class]]);
    if (![series count]) {
        OBASSERT_NOT_REACHED("Empty series returned");
        return;
    }
    
    // Add series to the master group
    [everything addElement:series];
    
    // Add the point labels, if any
    for (RSGraphElement *GE in [series elements]) {
        RSTextLabel *TL = [GE label];
        if (TL)
            [everything addElement:TL];
    }
    
    // Lock all vertices in the series
    [series setLocked:YES];
    
    if (width) {
        [series setWidth:width];
    }
    
    [series setShape:shape];
    
    if (currentColor)
        [series setColor:currentColor];
    
    if ([series count] == 1)
        return;
    
    // Group the elements in this series together
    RSGroup *groupObj = [RSGroup groupWithGraph:series.graph];
    [series.graph setGroup:groupObj forElement:series];
    
    // Connect the elements in this series, if requested
    if (connectMethod != RSConnectNone) {
        [series sortElementsUsingSelector:@selector(xSort:)];
        RSConnectLine *L = [RSConnectLine connectLineWithGraph:series.graph vertices:series];
        [L setConnectMethod:defaultConnectMethod()];
        
        [L setDash:dashStyle];
        
        // Set other styles to match the vertices
        if (currentColor) {
            [L setColor:currentColor];
        }
        if (width) {
            [L setWidth:width];
        }
        
        [everything addElement:L];
    }
}

+ (NSArray *)_dataSeriesColorPalette;
{
    static NSArray *colorPalette = nil;
    
    if (!colorPalette) {
        colorPalette = [[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:@"DataSeriesColorPalette"];
        if (![colorPalette count] || ![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"UseColorPaletteWhenImportingData"])
            colorPalette = nil;
    }
    
    return colorPalette;
}

+ (OQColor *)_colorForDataSeriesNumber:(NSUInteger)n;
{
    NSArray *colorPalette = [RSDataImporter _dataSeriesColorPalette];
    NSUInteger count = [colorPalette count];
    if (count == 0)
        return [OQColor blackColor];

    NSUInteger index = n % count;
    
    OQColor *currentColor = [OQColor colorFromRGBAString:[colorPalette objectAtIndex:index]];
    if (!currentColor)
        currentColor = [OQColor blackColor];
    return currentColor;
}

+ (NSInteger)_shapeForDataSeriesNumber:(NSUInteger)n;
{
    NSInteger first = RS_CIRCLE;
    NSInteger count = RS_LAST_STANDARD_SHAPE;  // (1-indexed)
    
    NSInteger index = n % count;
    return index + first;  // account for offset
}

/*
- (RSGraphElement *)graphElementsFromString:(NSString *)string forGraph:(RSGraph *)graph connectSeries:(BOOL)connectSeries;
// Returns all imported graph elements, processed and ready to add to the specified graph.
{
    NSArray *A = [self _dataSeriesFromString:string forGraph:graph];
    if ( !A ) {  // nothing was found
        [RSDataImporter finishInterpretingStringDataForGraph:graph];
        return nil;
    }

    RSGroup *everything = [RSGroup groupWithGraph:graph];

    NSUInteger currentShape = RS_NONE;
    NSArray *colorPalette = [[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:@"DataSeriesColorPalette"];
    if (![colorPalette count] || ![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"UseColorPaletteWhenImportingData"])
        colorPalette = nil;
    NSUInteger currentColorIndex = 0;
    OQColor *currentColor = nil;

    // Process each data series
    for (RSGroup *series in A) {
        OBASSERT([series isKindOfClass:[RSGroup class]]);
        if (![series count]) {
            OBASSERT_NOT_REACHED("Empty series returned");
            continue;
        }
        
        if ([series count] == 1 && [[series firstElement] isKindOfClass:[RSTextLabel class]]) {
            // This is just a single text label, which will be treated differently
            RSTextLabel *TL = (RSTextLabel *)[series firstElement];
            return TL;
        }
        // otherwise, the "series" should really be all vertices
        
        // Get a unique shape for this series
        currentShape += 1;
        if (currentShape > RS_LAST_STANDARD_SHAPE)
            currentShape = RS_CIRCLE;
        
        // Get a new color for this series
        if (colorPalette) {
            OBASSERT(currentColorIndex < [colorPalette count]);
            currentColor = [OQColor colorFromRGBAString:[colorPalette objectAtIndex:currentColorIndex]];
            if (!currentColor)
                currentColor = [OQColor blackColor];
            // set up for next iteration
            currentColorIndex += 1;
            if (currentColorIndex >= [colorPalette count])
                currentColorIndex = 0;
        }
        
        [self processDataSeries:series addToGroup:everything shape:currentShape color:currentColor connectMethod:defaultConnectMethod() dashStyle:0];
    }

    // Return the master group with everything in it
    return everything;
}
*/

- (RSGraphElement *)graphElementsFromString:(NSString *)string forGraph:(RSGraph *)graph connectSeries:(BOOL)connectSeries;
{
    return [self graphElementsFromString:string forGraph:graph prototypes:nil connectSeries:connectSeries found:NULL];
}

- (RSGraphElement *)graphElementsFromString:(NSString *)string forGraph:(RSGraph *)graph prototypes:(NSArray *)prototypes connectSeries:(BOOL)connectSeries found:(NSInteger *)numberOfSeriesFound;
// Returns all imported graph elements, processed and ready to add to the specified graph. If prototype objects are provided, those are used to style each data series. Otherwise, default styles are used, and data series are connected if specified by connectSeries.
{
    NSArray *A = [self _dataSeriesFromString:string forGraph:graph];
    if ( !A ) {  // nothing was found
        [RSDataImporter finishInterpretingStringDataForGraph:graph];
        return nil;
    }
    
    RSGroup *everything = [RSGroup groupWithGraph:graph];
    
    NSUInteger limit = prototypes ? [prototypes count] : 0;
    NSUInteger index = 0;
    
    // Process each data series
    for (RSGroup *series in A) {
        
        OBASSERT([series isKindOfClass:[RSGroup class]]);
        if (![series count]) {
            OBASSERT_NOT_REACHED("Empty series returned");
            continue;
        }
        
        // Initialize default style settings
        CGFloat currentWidth = 0;
        NSUInteger currentShape = RS_NONE;
        OQColor *currentColor = nil;
        RSConnectType connectMethod = RSConnectNone;
        NSInteger dashStyle = 0;
        
        // If we have a prototype for this series, use it to make style choices.
        if (index < limit) {
            RSVertex *prototype = [prototypes objectAtIndex:index];
            OBASSERT([prototype isKindOfClass:[RSVertex class]]);
            
            currentWidth = prototype.width;
            currentShape = prototype.shape;
            currentColor = prototype.color;
            
            // If the prototype is part of a line, use the line's style attributes
            RSLine *line = [prototype lastParentLine];
            if (line) {
                connectMethod = [line connectMethod];
                dashStyle = [line dash];
            }
        }
        
        // If we don't have enough (or any) prototypes, use default styles
        else {
            NSUInteger nonPrototypeNumber = index - limit;
            currentShape = [RSDataImporter _shapeForDataSeriesNumber:nonPrototypeNumber];
            currentColor = [RSDataImporter _colorForDataSeriesNumber:nonPrototypeNumber];
            
            if (connectSeries) {
                connectMethod = defaultConnectMethod();
            }
        }
        
        // Apply the styles and perform other cleanup
        [self processDataSeries:series addToGroup:everything width:currentWidth shape:currentShape color:currentColor connectMethod:connectMethod dashStyle:dashStyle];
        
        index += 1;
    }
    
    if (numberOfSeriesFound != NULL) {
        *numberOfSeriesFound = index - 1;
    }
    
    return everything;
}




+ (void)finishInterpretingStringDataForGraph:(RSGraph *)graph;
{
    if( _shouldHideEndLabels ) {
	[graph hideEndLabelsForAxis:_shouldHideEndLabels];
    }
    _shouldHideEndLabels = nil;
}




@end
