// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSDataImporter.h 200244 2013-12-10 00:11:55Z correia $

//
//  This class processes a string to interpret it as data describing points and labels.


#import <OmniBase/OBObject.h>

#if 1 && defined(DEBUG_robin)
#define DEBUG_DATA_IMPORT(format, ...) NSLog( format, ## __VA_ARGS__ )
#else
#define DEBUG_DATA_IMPORT(format, ...)
#endif

#define RS_UNKNOWN_COL 0
#define RS_LABEL_COL 1
#define RS_FLOAT_COL 2
#define RS_DATE_COL 3

#define RS_NM_OF_COL_TYPES 4  // the number of column types supported


extern NSString * const RSDataImporterWarningTitle;
extern NSString * const RSDataImporterWarningDescription;

@class RSGraph, RSVertex, RSAxis, RSGraphElement;


@interface RSDataImporter : OBObject
{
    id delegate;  // non-retained
    NSUInteger _skippedRows;
    
    NSDictionary *_warning;
}

@property (assign) id delegate;
@property (retain) NSDictionary *warning;


// Shared importer object
+ (RSDataImporter *)sharedDataImporter;


// Error messages
+ (NSDictionary *)noDataDetectedMessage;
+ (NSDictionary *)tooMuchDataDetectedMessage;


// cells:
+ (BOOL)isABlank:(NSString *)string;
+ (NSString *)unadornedString:(NSString *)string;
+ (BOOL)isAFloat:(NSString *)string;
+ (BOOL)getDoubleValue:(double *)doubleVal forString:(NSString *)string;
+ (BOOL)cell:(NSString *)cell matchesType:(int)type;
+ (double)doubleValueOfCell:(NSString *)cell withType:(int)type;
+ (BOOL)isNumberType:(NSInteger)type;
+ (BOOL)isADate:(NSString *)string;
//+ (NSDate *)dateValueOfString:(NSString *)string;

// rows:
+ (BOOL)rowIsAllLabels:(NSArray *)row;

// table:
+ (NSUInteger)numberOfColumnsInTable:(NSArray *)table;
+ (void)detectColumnTypes:(NSArray *)table intoArray:(NSInteger *)types;  // takes an int array and fills it with column types
- (NSArray *)tableFromString:(NSString *)rawString;


// The main import methods
- (RSGraphElement *)graphElementsFromString:(NSString *)string forGraph:(RSGraph *)graph connectSeries:(BOOL)connectSeries;
- (RSGraphElement *)graphElementsFromString:(NSString *)string forGraph:(RSGraph *)graph prototypes:(NSArray *)prototypes connectSeries:(BOOL)connectSeries found:(NSInteger *)numberOfSeriesFound;
+ (void)finishInterpretingStringDataForGraph:(RSGraph *)graph;



@end
