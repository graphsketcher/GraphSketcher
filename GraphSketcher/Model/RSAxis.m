// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSAxis.h>

#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGrid.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/OFPreference-RSExtensions.h>
#import <OmniQuartz/OQColor.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>
#endif

#if 0 && defined(DEBUG_robin)
#define DEBUG_AUTOSCALE(format, ...) NSLog((format), ## __VA_ARGS__)
#else
#define DEBUG_AUTOSCALE(format, ...)
#endif


NSString *nameFromOrientation(int orientation)
{
    if (orientation == RS_ORIENTATION_HORIZONTAL)
	return @"x";
    else if (orientation == RS_ORIENTATION_VERTICAL)
	return @"y";
    
    OBASSERT_NOT_REACHED("orientation not supported");
    return @"none";
}
int orientationFromName(NSString *name)
{
    if ([name isEqual:@"x"])
	return RS_ORIENTATION_HORIZONTAL;
    else if ([name isEqual:@"y"])
	return RS_ORIENTATION_VERTICAL;
    
    OBASSERT_NOT_REACHED("orientation not supported");
    return RS_ORIENTATION_UNASSIGNED;
}

NSString *labelNameFromOrientation(int orientation)
{
    if (orientation == RS_ORIENTATION_HORIZONTAL)
	return NSLocalizedStringFromTableInBundle(@"X Axis", @"GraphSketcherModel", OMNI_BUNDLE, @"Default x-axis label");
    else if (orientation == RS_ORIENTATION_VERTICAL)
	return NSLocalizedStringFromTableInBundle(@"Y Axis", @"GraphSketcherModel", OMNI_BUNDLE, @"Default y-axis label");
    
    OBASSERT_NOT_REACHED("orientation not supported");
    return @"Axis";
}

NSString *nameFromPlacement(RSAxisPlacement placement)
{
    switch (placement) {
	case RSOriginPlacement:
	    return @"origin";
	case RSEdgePlacement:
	    return @"edge";
	case RSBothEdgesPlacement:
	    return @"both-edges";
	default:
	    return @"origin";
    }
}

RSAxisPlacement placementFromName(NSString *name)
{
    if ([name isEqualToString:@"origin"]) {
	return RSOriginPlacement;
    }
    else if ([name isEqualToString:@"edge"]) {
	return RSEdgePlacement;
    }
    else if ([name isEqualToString:@"both-edges"]) {
	return RSBothEdgesPlacement;
    }
    
    OBASSERT_NOT_REACHED("Unknown placement string");
    return RSOriginPlacement;
}

NSString *nameFromExtent(RSAxisExtent extent)
{
    switch (extent) {
	case RSAxisExtentFull:
	    return @"full";
	case RSAxisExtentDataRange:
	    return @"data-range";
	case RSAxisExtentDataQuartiles:
	    return @"data-quartiles";
	default:
	    return @"full";
    }
}

RSAxisExtent extentFromName(NSString *name)
{
    if ([name isEqualToString:@"full"]) {
	return RSAxisExtentFull;
    }
    else if ([name isEqualToString:@"data-range"]) {
	return RSAxisExtentDataRange;
    }
    else if ([name isEqualToString:@"data-quartiles"]) {
	return RSAxisExtentDataQuartiles;
    }
    
    OBASSERT_NOT_REACHED("Unknown axis extent string");
    return RSAxisExtentFull;
}

NSString *nameFromTickLayout(RSAxisTickLayout tickLayout)
{
    switch (tickLayout) {
	case RSAxisTickLayoutSimple:
	    return @"simple";
	case RSAxisTickLayoutAtData:
	    return @"at-data";
	case RSAxisTickLayoutHidden:
	    return @"hidden";
	default:
	    return @"simple";
    }
}

RSAxisTickLayout tickLayoutFromName(NSString *name)
{
    if ([name isEqualToString:@"simple"]) {
	return RSAxisTickLayoutSimple;
    }
    else if ([name isEqualToString:@"at-data"]) {
	return RSAxisTickLayoutAtData;
    }
    else if ([name isEqualToString:@"hidden"]) {
	return RSAxisTickLayoutHidden;
    }
    
    OBASSERT_NOT_REACHED("Unknown tick layout string");
    return RSAxisTickLayoutSimple;
}

NSString *nameFromAxisType(int axisType)
{
    if (axisType == RSAxisTypeLinear) {
        return @"linear";
    }
    else if (axisType == RSAxisTypeLogarithmic) {
        return @"logarithmic";
    }
    
    OBASSERT_NOT_REACHED("Unknown axis type");
    return @"linear";
}

int axisTypeFromName(NSString *name)
{
    if ([name isEqualToString:@"linear"]) {
        return RSAxisTypeLinear;
    }
    else if ([name isEqualToString:@"logarithmic"]) {
        return RSAxisTypeLogarithmic;
    }
    
    OBASSERT_NOT_REACHED("Unknown axis type string");
    return RSAxisTypeLinear;
}

NSString *nameFromScientificNotationSetting(RSScientificNotationSetting setting)
{
    switch (setting) {
        case RSScientificNotationSettingAuto:
            return @"auto";
        case RSScientificNotationSettingOn:
            return @"on";
        case RSScientificNotationSettingOff:
            return @"off";
        default:
            return @"auto";
    }
}

RSScientificNotationSetting scientificNotationSettingFromName(NSString *name)
{
    if ([name isEqualToString:@"auto"]) {
        return RSScientificNotationSettingAuto;
    }
    else if ([name isEqualToString:@"on"]) {
        return RSScientificNotationSettingOn;
    }
    else if ([name isEqualToString:@"off"]) {
        return RSScientificNotationSettingOff;
    }
    
    OBASSERT_NOT_REACHED("Unknown scientific notation setting string");
    return RSScientificNotationSettingAuto;
}



@interface RSAxis (PrivateAPI)
- (data_p)_closestTickMarkToMin:(data_p)min usingMax:(data_p)max;
- (data_p)_closestTickMarkToMax:(data_p)max usingMin:(data_p)min;

- (void)updateDateFormat;
@end



@implementation RSAxis


//////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////////////////
+ (void)initialize
{
    OBINITIALIZE;
    [self setVersion:10];
}

- (id)copyWithZone:(NSZone *)zone;
{
    OBASSERT_NOT_REACHED("Axes cannot currently be copied.");
    return nil;
}


- (id)initWithGraph:(RSGraph *)graph orientation:(int)orientation;
{
    return [self initWithGraph:graph identifier:[NSString stringWithFormat:@"a%@", nameFromOrientation(orientation)] orientation:orientation min:0 max:10];
}

// Designated initializer
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier orientation:(int)orientation min:(data_p)min max:(data_p)max;
{
    if (!(self = [super initWithGraph:graph identifier:identifier]))
	return nil;
    //NSMutableDictionary *attributes;
    
    OFPreferenceWrapper *prefWrapper = [OFPreferenceWrapper sharedPreferenceWrapper];
    
    // scale
    _orientation = orientation;
    _min = min;
    _max = max;
    _axisType = RSAxisTypeLinear;
    _userModifiedRange = NO;
    
    
    // axis
    _placement = placementFromName([prefWrapper stringForKey:@"DefaultAxisPlacement"]);
    _width = [prefWrapper floatForKey:@"DefaultAxisWidth"];
    _color = [[OQColor colorForPreferenceKey:@"DefaultAxisColor"] retain];
    _displayAxis = [prefWrapper boolForKey:@"DisplayAxis"];
    _extent = RSAxisExtentFull;
    
    
    // ticks
    _spacing = 1;
    _spacingSigFigs = 0;
    _userSpacing = 0;
    _tickWidthIn = [prefWrapper floatForKey:@"DefaultAxisTickWidthIn"];
    _tickWidthOut = [prefWrapper floatForKey:@"DefaultAxisTickWidthOut"];
    _tickType = 0;
    _shape = [prefWrapper integerForKey:@"DefaultAxisShape"];
    _displayTicks = [prefWrapper boolForKey:@"DisplayAxisTicks"];
    
    
    // grid
    _grid = [[RSGrid alloc] initWithOrientation:_orientation spacing:_spacing];
    
    
    // tick labels
    if( orientation == RS_ORIENTATION_HORIZONTAL ) {
	_labelDistance = [prefWrapper floatForKey:@"DefaultDistanceToXAxisTickLabels"];
	_tickLabelPadding = DEFAULT_TICK_LABEL_PADDING_HORIZONTAL;
        _titlePlacement = [prefWrapper floatForKey:@"DefaultXAxisTitlePlacement"];
    } else {
	_labelDistance = [prefWrapper floatForKey:@"DefaultDistanceToYAxisTickLabels"];
	_tickLabelPadding = DEFAULT_TICK_LABEL_PADDING_VERTICAL;
        _titlePlacement = [prefWrapper floatForKey:@"DefaultYAxisTitlePlacement"];
    }
    _userLabels = [[NSMutableDictionary alloc] init];
    
    _scientificNotation = scientificNotationSettingFromName([prefWrapper stringForKey:@"ScientificNotationSetting"]);
    
    
    OAFontDescriptor *tickLabelFontDescriptor;
    if (orientation == RS_ORIENTATION_HORIZONTAL && [[OFPreference preferenceForKey:@"DefaultXAxisTickLabelFont"] hasNonDefaultValue]) {
        tickLabelFontDescriptor = [prefWrapper fontDescriptorForKey:@"DefaultXAxisTickLabelFont"];
    }
    else if (orientation == RS_ORIENTATION_VERTICAL && [[OFPreference preferenceForKey:@"DefaultYAxisTickLabelFont"] hasNonDefaultValue]) {
        tickLabelFontDescriptor = [prefWrapper fontDescriptorForKey:@"DefaultYAxisTickLabelFont"];
    }
    else {
        tickLabelFontDescriptor = [prefWrapper fontDescriptorForKey:@"DefaultAxisTickLabelFont"];
    }

    
    _minLabel = [[RSTextLabel alloc] initWithGraph:_graph fontDescriptor:tickLabelFontDescriptor];
    [_minLabel setPartOfAxis:YES];
    [_userLabels setObject:_minLabel forKey:@"minLabel"];
    [_minLabel setTickValue:_min axisOrientation:_orientation];
    [_minLabel release];
    
    _maxLabel = [[RSTextLabel alloc] initWithGraph:_graph fontDescriptor:tickLabelFontDescriptor];
    [_maxLabel setPartOfAxis:YES];
    [_userLabels setObject:_maxLabel forKey:@"maxLabel"];
    [_maxLabel setTickValue:_max axisOrientation:_orientation];
    [_maxLabel release];
    
    // set the text in the min and max labels:
    [self updateAxisEndLabels];
    
    _displayTickLabels = [prefWrapper boolForKey:@"DisplayAxisTickLabels"];
    
    
    // title
    OAFontDescriptor *defaultTitleFontDescriptor;
    if (orientation == RS_ORIENTATION_HORIZONTAL) {
        defaultTitleFontDescriptor = [prefWrapper fontDescriptorForKey:@"DefaultXAxisTitleFont"];
        _titleDistance = [prefWrapper floatForKey:@"DefaultDistanceToXAxisTitle"];
    }
    else {
        defaultTitleFontDescriptor = [prefWrapper fontDescriptorForKey:@"DefaultYAxisTitleFont"];
        _titleDistance = [prefWrapper floatForKey:@"DefaultDistanceToYAxisTitle"];
    }
    _axisTitle = [[RSTextLabel alloc] initWithGraph:_graph fontDescriptor:defaultTitleFontDescriptor];
    [_axisTitle setPartOfAxis:YES];
    [self setDisplayTitle:[prefWrapper boolForKey:@"DisplayAxisTitles"]];
    [_axisTitle setText:labelNameFromOrientation(orientation)];
    [self rotateTitle];
    
    _cachedTickArray = nil;
    _tickLabelSpacing = 0;
    _tickLabelNumberFormatter = nil;
    _inspectorNumberFormatter = nil;
    [self resetNumberFormatters];
    
    return self;
}

- (id)init {
    OBRejectInvalidCall(self, _cmd, @"use designated initializer");
    return nil;
}

- (void)invalidate;
{
    [_grid release];
    _grid = nil;
    
    [_axisTitle release];
    _axisTitle =nil;
    
    [_color release];
    _color = nil;
    
    [_userLabels release];
    _userLabels = nil;
    
    self.cachedTickArray = nil;
    
    [_tickLabelNumberFormatter release];
    _tickLabelNumberFormatter = nil;
    
    [_inspectorNumberFormatter release];
    _inspectorNumberFormatter = nil;
    
    [super invalidate];
}

- (void)dealloc
{
    [self invalidate];
    
    [super dealloc];
}




//////////////////////////////////////////////////
#pragma mark -
#pragma mark RSGraphElement subclass
///////////////////////////////////////////////////

- (OQColor *)color {
    return _color;
}
- (void)setColor:(OQColor *)color;
{
    if ([color isEqual:_color])
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setColor"]) {
	[(typeof(self))[[_graph undoManager] prepareWithInvocationTarget:self] setColor:_color];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Color", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    [_color autorelease];
    _color = [color retain];
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    for (RSTextLabel *TL in [_userLabels allValues]) {
        [TL setColor:color];
    }
#endif
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}
- (CGFloat)width {
    return _width;
}
- (void)setWidth:(CGFloat)width;
{
    if (_width == width)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setWidth"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setWidth:_width];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Thickness", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _width = width;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];  // because axis thickness can affect axis title position
}
- (BOOL)hasWidth;
{
    return YES;
}
- (OAFontDescriptor *)fontDescriptor;
{
    return _maxLabel.fontDescriptor;
}
- (void)setFontDescriptor:(OAFontDescriptor *)newFontDescriptor;
{
    for (RSTextLabel *TL in [_userLabels allValues]) {
        OBASSERT([TL conformsToProtocol:@protocol(RSFontAttributes)]);
        [TL setFontDescriptor:newFontDescriptor];
    }
}
- (CGFloat)fontSize;
{
    return [[self visibleUserLabels] fontSize];
}
- (void)setFontSize:(CGFloat)value;
{
    [[self allUserLabels] setFontSize:value];
}
- (id)attributeForKey:(NSString *)name;
{
    return [_maxLabel attributeForKey:name];
}
- (void)setAttribute:(id)attribute forKey:(NSString *)name;
{
    [[self allUserLabels] setAttribute:attribute forKey:name];
}
- (NSString *)text;
// Shown in the inspector's "label text" field
{
    return [[self title] text];
}

- (NSInteger)dash {
    return 1;
}
- (NSInteger)shape {
    return _shape;
}
- (void)setShape:(NSInteger)style;
{
    if (_shape == style)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setShape"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setShape:_shape];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Axis Arrows", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _shape = style;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];  // because arrows affect the axis position
}
- (BOOL)canHaveArrows;
{
    return YES;
}

- (BOOL)hasUserCoords;
{
    return NO;
}

- (BOOL)hasLabel;
{
    return [self displayTickLabels] || [self displayTitle];
}
- (CGFloat)labelDistance {
    return _labelDistance;
}
- (void)setLabelDistance:(CGFloat)value;
{
    if (_labelDistance == value)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setLabelDistance"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setLabelDistance:_labelDistance];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Adjust Axis Tick Label Distance", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _labelDistance = value;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}

- (BOOL)isPartOfAxis {
    return YES;
}
- (BOOL)isMovable {
    return NO;
}
- (BOOL)canBeCopied {
    return NO;
}

- (NSArray *)elementsBetweenElement:(RSGraphElement *)e1 andElement:(RSGraphElement *)e2;
{
    NSArray *userLabels = [[self visibleUserLabels] elements];
    
    if (![userLabels containsObject:e1] || ![userLabels containsObject:e2])
	return nil;
    
    data_p tick1 = [e1 tickValue];
    data_p tick2 = [e2 tickValue];
    
    if (tick1 > tick2) {
	data_p temp = tick1;
	tick1 = tick2;
	tick2 = temp;
    }
    
    NSMutableArray *result = [NSMutableArray array];
    for (RSTextLabel *TL in userLabels) {
        data_p tickValue = [TL tickValue];
        if (tickValue > tick1 && tickValue < tick2) {
            [result addObject:TL];
        }
    }
    
    return result;
}



///////////////////////////////////////////
#pragma mark -
#pragma mark Axis layout/display settings
///////////////////////////////////////////
- (CGFloat)tickWidthIn {
    return _tickWidthIn;
}
- (void)setTickWidthIn:(CGFloat)value {
    _tickWidthIn = value;
}
- (CGFloat)tickWidthOut {
    return _tickWidthOut;
}
- (void)setTickWidthOut:(CGFloat)value {
    _tickWidthOut = value;
}
- (BOOL)displayAxis {
    return _displayAxis;
}
- (void)setDisplayAxis:(BOOL)flag {
    if (_displayAxis == flag)
	return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setDisplayAxis:_displayAxis];
    
    if (![undoManager isUndoing]) {
	NSString *undoName;
	if (flag == YES)
	    undoName = NSLocalizedStringFromTableInBundle(@"Show Axis", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	else
	    undoName = NSLocalizedStringFromTableInBundle(@"Hide Axis", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	[[_graph undoer] setActionName:undoName];
    }
    
    _displayAxis = flag;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}
- (BOOL)displayTickLabels {
    return _displayTickLabels;
}
- (void)setDisplayTickLabels:(BOOL)flag {
    if (_displayTickLabels == flag)
	return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setDisplayTickLabels:_displayTickLabels];
    
    if (![undoManager isUndoing]) {
	NSString *undoName;
	if (flag == YES)
	    undoName = NSLocalizedStringFromTableInBundle(@"Show Axis Tick Labels", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	else
	    undoName = NSLocalizedStringFromTableInBundle(@"Hide Axis Tick Labels", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	
	[[_graph undoer] setActionName:undoName];
    }
    
    _displayTickLabels = flag;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}
- (BOOL)displayTicks {
    return _displayTicks;
}
- (void)setDisplayTicks:(BOOL)flag {
    if (_displayTicks == flag)
	return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setDisplayTicks:_displayTicks];
    
    if (![undoManager isUndoing]) {
	NSString *undoName;
	if (flag == YES)
	    undoName = NSLocalizedStringFromTableInBundle(@"Show Axis Tick Marks", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	else
	    undoName = NSLocalizedStringFromTableInBundle(@"Hide Axis Tick Marks", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	
	[[_graph undoer] setActionName:undoName];
    }
    
    _displayTicks = flag;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}
- (BOOL)displayTitle {
    return [_axisTitle isVisible];
}
- (void)setDisplayTitle:(BOOL)flag {
    if ([_axisTitle isVisible] == flag)
	return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setDisplayTitle:[_axisTitle isVisible]];
    
    if (![undoManager isUndoing]) {
	NSString *undoName;
	if (flag == YES)
	    undoName = NSLocalizedStringFromTableInBundle(@"Show Axis Title", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	else
	    undoName = NSLocalizedStringFromTableInBundle(@"Hide Axis Title", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	
	[[_graph undoer] setActionName:undoName];
    }
    
    [_axisTitle setVisible:flag];
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}
- (BOOL)displayGrid {
    return [_grid displayGrid];
}
- (void)setDisplayGrid:(BOOL)flag;
{
    if ([_grid displayGrid] == flag)
	return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setDisplayGrid:[_grid displayGrid]];
    
    if (![undoManager isUndoing]) {
	NSString *undoName;
	if (flag == YES)
	    undoName = NSLocalizedStringFromTableInBundle(@"Show Grid Lines", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	else
	    undoName = NSLocalizedStringFromTableInBundle(@"Hide Grid Lines", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name");
	
	[[_graph undoer] setActionName:undoName];
    }
    
    [_grid setDisplayGrid:flag];
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}

@synthesize placement=_placement;
- (void)setPlacement:(RSAxisPlacement)placement;
{
    if (_placement == placement)
	return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setPlacement:_placement];
    
    if (![undoManager isUndoing]) {
	[[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Axis Placement", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _placement = placement;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}

@synthesize tickLayout=_tickLayout;
- (void)setTickLayout:(RSAxisTickLayout)tickLayout;
{
    if (_tickLayout == tickLayout)
        return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setTickLayout:_tickLayout];
    
    if (![undoManager isUndoing]) {
	[[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Tick Mark Style", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _tickLayout = tickLayout;
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}

- (void)toggleTickLayoutAtData;
{
    RSAxisTickLayout oldLayout = [self tickLayout];
    if (oldLayout == RSAxisTickLayoutAtData) {
        self.tickLayout = RSAxisTickLayoutSimple;
    } else {
        self.tickLayout = RSAxisTickLayoutAtData;
    }
}

@synthesize extent = _extent;
- (void)setExtent:(RSAxisExtent)extent;
{
    if (_extent == extent)
        return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setExtent:_extent];
    
    if (![undoManager isUndoing]) {
	[[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Axis Extent", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _extent = extent;
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}

- (int)orientation {
    return _orientation;
}
- (void)setOrientation:(int)orientation {
    _orientation = orientation;
    [self rotateTitle];
}
- (RSTextLabel *)maxLabel {
    return _maxLabel;
}
- (RSTextLabel *)minLabel {
    return _minLabel;
}
- (RSTextLabel *)title {
    return _axisTitle;
}
- (void)rotateTitle;
{
    if( _orientation == RS_ORIENTATION_VERTICAL ) {
	[[self title] setRotation:90];
    } else {
	[[self title] setRotation:0];
    }
}

@synthesize titleDistance = _titleDistance;
- (void)setTitleDistance:(CGFloat)value;
{
    if (_titleDistance == value)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setTitleDistance"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setTitleDistance:_titleDistance];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Adjust Axis Title Distance", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _titleDistance = value;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}
@synthesize titlePlacement = _titlePlacement;
- (void)setTitlePlacement:(CGFloat)placement;
{
    if (_titlePlacement == placement)
	return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setTitlePlacement"]) {
        NSUndoManager *undoManager = [_graph undoManager];
        [[undoManager prepareWithInvocationTarget:self] setTitlePlacement:_titlePlacement];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Axis Title Placement", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _titlePlacement = placement;
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}

@synthesize tickLabelPadding = _tickLabelPadding;
- (CGFloat)tickLabelPadding;
{
    // Double the minimum padding if we're using decimal points or scientific notation.
    if ([self usesDecimalPoint] || [self usesScientificNotation]) {
        return _tickLabelPadding * 2;
    }
    
    // Reduce the padding if all tick marks are negative numbers. <bug:///73104>
    if (_orientation == RS_ORIENTATION_HORIZONTAL && [self max] <= 0) {
        return _tickLabelPadding * 0.8f;
    }
    
    return _tickLabelPadding;
}

- (BOOL)hasArrows {
    if( _shape == RS_RIGHT_ARROW || _shape == RS_LEFT_ARROW || _shape == RS_BOTH_ARROW )  return YES;
    else  return NO;
}
- (BOOL)minEndIsArrow {
    NSInteger styleIndex = [self shape];
    if( styleIndex == RS_LEFT_ARROW || styleIndex == RS_BOTH_ARROW )  return YES;
    else  return NO;
}
- (BOOL)maxEndIsArrow {
    NSInteger styleIndex = [self shape];
    if( styleIndex == RS_RIGHT_ARROW || styleIndex == RS_BOTH_ARROW )  return YES;
    else  return NO;
}
- (BOOL)shouldDrawMinArrow;
{
    return [self minEndIsArrow] && [self min] != [self visualOrigin];
}
- (BOOL)shouldDrawMaxArrow;
{
    return [self maxEndIsArrow] && [self max] != [self visualOrigin];
}

- (BOOL)shouldDrawMinTick;
{
    // No extra ticks if we're using data ticks
    if (self.tickLayout == RSAxisTickLayoutAtData)
        return NO;
    
    // No tick if the end label is deleted
    if ([[self minLabel] isDeletedString])
        return NO;
    
    return ![self shouldDrawMinArrow];
}

- (BOOL)shouldDrawMaxTick;
{
    // No extra ticks if we're using data ticks
    if (self.tickLayout == RSAxisTickLayoutAtData)
        return NO;
    
    // No tick if the end label is deleted
    if ([[self maxLabel] isDeletedString])
        return NO;
    
    return ![self shouldDrawMaxArrow];
}


- (BOOL)noGridComponentsAreDisplayed;
{
    if(   ![self displayTickLabels]
       && ![self displayTicks]
       && ![[_graph otherAxis:self] displayGrid] )  return YES;
    
    else  return NO;
}


///////////////////////////////////////////
#pragma mark -
#pragma mark Axis range settings
///////////////////////////////////////////

- (void)_updateLogScaleParameters;
{
    // By default, use whatever the user has specified:
    _logMin = _min;
    _logMax = _max;
    
    // But logarithmic axes can't span 0 (because 0 is infinitely far away).
    // If min is 0 or less, use a min above zero (based on data in the graph).
    if (_min <= 0 && _max > 0) {
        data_p closestToZero = _max;
        for (RSVertex *V in [_graph Vertices]) {
            data_p dataPos = dimensionOfDataPointInOrientation([V position], _orientation);
            if (dataPos > 0 && dataPos < closestToZero) {
                closestToZero = dataPos;
            }
        }
        
        if (closestToZero < _max) {
            closestToZero *= (1 - RS_SCALE_TO_FIT_BORDER_PERCENTAGE);  // Add some padding
            _logMin = [self _closestTickMarkToMin:closestToZero usingMax:_max];
        }
        else {
            _logMin = _max/10;  // If no data, then make the graph span one order of magnitude by default.
            
            // But allow users to experiment with log axes by keeping 1 as the min even if they enter a much higher max:
            if (_logMin > 1) {
                _logMin = 1;
            }
        }
    }
    // If max is 0, use a max below zero (based on data in the graph)
    else if (_min < 0 && _max >= 0) {
        data_p closestToZero = _min;
        for (RSVertex *V in [_graph Vertices]) {
            data_p dataPos = dimensionOfDataPointInOrientation([V position], _orientation);
            if (dataPos < 0 && dataPos > closestToZero) {
                closestToZero = dataPos;
            }
        }
        
        if (closestToZero > _min) {
            closestToZero *= (1 - RS_SCALE_TO_FIT_BORDER_PERCENTAGE);  // Add some padding
            _logMax = [self _closestTickMarkToMax:closestToZero usingMin:_min];
        }
        else {
            _logMax = _min/10;  // If no data, then make the graph span one order of magnitude by default.
            
            if (_logMax < -1) {
                _logMax = -1;
            }
        }
    }
    
    //NSLog(@"Updated _logMin: %f  _logMax: %f", _logMin, _logMax);
}

- (data_p)min {
    if (_axisType == RSAxisTypeLogarithmic) {
        return _logMin;
    }
    return _min;
}
- (data_p)max {
    if (_axisType == RSAxisTypeLogarithmic) {
        return _logMax;
    }
    return _max;
}
- (void)setMin:(data_p)value {
    if (_min == value)
	return;
    
    self.cachedTickArray = nil;
    
    if (value < RS_AXIS_MIN_MIN)
        value = RS_AXIS_MIN_MIN;
    
    if (value > RS_AXIS_MAX_MAX / 10)
        value = RS_AXIS_MAX_MAX / 10;
    
    if ( value > _max || nearlyEqualDataValues(value, _max) ) {
	NSLog(@"Warning: illegal axis min should have been caught sooner.");
	[self setMax:(_max + (value - _min))];
    }
    
    [_graph prepareUndoForAxisRanges];
    
    _min = value;
    
    if (_axisType == RSAxisTypeLogarithmic) {
        [self _updateLogScaleParameters];
    }
    
    [self updateTickMarks];
    [self resetNumberFormatters];
    
    [_minLabel setTickValue:[self min] axisOrientation:_orientation];
    //[self setUserLabel:nil forTick:_min];
    [self updateAxisEndLabels];
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}
- (void)setMax:(data_p)value {
    if (_max == value)
	return;
    
    self.cachedTickArray = nil;
    
    if (value > RS_AXIS_MAX_MAX)
        value = RS_AXIS_MAX_MAX;
    
    if (value < RS_AXIS_MIN_MIN / 10)
        value = RS_AXIS_MIN_MIN / 10;
    
    //if( [self userLabelIsCustomForTick:_max] ) {
    // transfer values to the "underlying" tick label
    //	[self setUserLabel:[[_maxLabel copy] autorelease] forTick:_max andKey:[self formattedDataValue:value]];
    //}
    
    if ( value < _min || nearlyEqualDataValues(value, _min) ) {
	NSLog(@"Warning: illegal axis max should have been caught sooner.");
	[self setMin:(_min - (_max - value))];
    }
    
    [_graph prepareUndoForAxisRanges];
    
    _max = value;
    
    if (_axisType == RSAxisTypeLogarithmic) {
        [self _updateLogScaleParameters];
    }
    
    [self updateTickMarks];
    [self resetNumberFormatters];
    
    [_maxLabel setTickValue:[self max] axisOrientation:_orientation];
    //[self setUserLabel:nil forTick:_max];
    [self updateAxisEndLabels];
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}
- (void)setMin:(data_p)min andMax:(data_p)max {
    if ( min < [self max] ) {
	[self setMin:min];
	[self setMax:max];
    } else {
	[self setMax:max];
	[self setMin:min];
    }
}

- (BOOL)valueIsNearlyEqualToZero:(data_p)value;
{
    data_p relevantScale;
    
    if (_axisType == RSAxisTypeLogarithmic) {
        relevantScale = ([self min] > 0) ? [self min] : -[self max];
    }
    else {
        relevantScale = [self max] - [self min];
    }

    OBASSERT(relevantScale > 0);
    
    return fabs(value) < relevantScale * 1e-12;
}

- (data_p)_closestTickMarkToMin:(data_p)min usingMax:(data_p)max;
{
    // Logarithmic axes with a sufficiently high n-value.
    if (_axisType == RSAxisTypeLogarithmic) {
        OBASSERT( min != 0 );
        
        data_p magnitude = magnitudeOfRangeRelativeToZero(min, max);
        DEBUG_AUTOSCALE(@"-min- magnitude: %.13g", magnitude);
        if (magnitude > RSMagnitudeOfRangeForLogarithmicAutoScaling) {
            data_p baseSpacing = pow(10, ceil(log10(max)));
            data_p spacing = baseSpacing;
            data_p newMin = min;
            
            // Positive log axes
            if (0 < min) {
                // Find enclosing regime boundary
                while (min < spacing) {
                    spacing /= 10;
                }
                DEBUG_AUTOSCALE(@"chose regime boundary: %.13g", spacing);
                
                // If range does not span many orders of magnitude, find closest tick
                newMin = spacing;
                DEBUG_AUTOSCALE(@"magnitude: %.13g", magnitude);
                if (magnitude < RSMagnitudeOfRangeForRegimeBoundaryAutoSpacing) {
                    while (newMin + spacing <= min) {
                        newMin += spacing;
                    }
                }
                DEBUG_AUTOSCALE(@"chose new min: %.13g", newMin);
                return newMin;
            }
            
            // Negative log axes
            else {  // max < 0
                OBASSERT(max < 0);
                while (-min > spacing) {
                    spacing *= 10;
                }
                newMin = spacing;
                if (magnitude < RSMagnitudeOfRangeForRegimeBoundaryAutoSpacing) {
                    spacing /= 10;
                    while (newMin - spacing >= -min) {
                        newMin -= spacing;
                    }
                }
                return -newMin;
            }
        }
    }
    
    // Special case for linear axes close to zero.
    if (_axisType == RSAxisTypeLinear) {
        // If min is close to zero, then just use zero
        if ( (min >= 0 || [self valueIsNearlyEqualToZero:min]) && min/(max - min) < RS_SCALE_TO_FIT_MAX_SPACE_TO_ZERO_PERCENTAGE) {
            return 0;
        }
    }
    
    
    // Normal case -- find the closest enclosing tick mark.
    data_p spacing = [self calculateAutoSpacingForMin:min max:max];
    data_p reduced = (data_p)floor(min/spacing);  // reduce to int so can round
    data_p newMin = reduced*spacing;  // then grow back to full size
    
    return newMin;
}

- (data_p)_closestTickMarkToMax:(data_p)max usingMin:(data_p)min;
{
    // Handle logarithmic axes separately
    if (_axisType == RSAxisTypeLogarithmic) {
        OBASSERT( min != 0 );
        
        data_p magnitude = magnitudeOfRangeRelativeToZero(min, max);
        DEBUG_AUTOSCALE(@"-max- magnitude: %.13g", magnitude);
        if (magnitude > RSMagnitudeOfRangeForLogarithmicAutoScaling) {

            // Choose a tick mark that is a regime boundary.
            data_p baseSpacing = pow(10, floor(log10(max)));
            data_p spacing = baseSpacing;
            data_p newMax = max;
            
            // Positive log axes
            if (0 < min) {
                // Find enclosing regime boundary
                while (max > spacing) {
                    spacing *= 10;
                }
                DEBUG_AUTOSCALE(@"chose regime boundary: %.13g", spacing);
                // If range does not span many orders of magnitude, find closest tick
                newMax = spacing;
                if (magnitude < RSMagnitudeOfRangeForRegimeBoundaryAutoSpacing) {
                    spacing /= 10;
                    while (newMax - spacing >= max) {
                        newMax -= spacing;
                    }
                }
                DEBUG_AUTOSCALE(@"chose new max: %.13g", newMax);
                return newMax;
            }
            
            // Negative log axes
            else {  // max < 0
                OBASSERT(max < 0);
                while (-max < spacing) {
                    spacing /= 10;
                }
                newMax = spacing;
                if (magnitude < RSMagnitudeOfRangeForRegimeBoundaryAutoSpacing) {
                    while (newMax + spacing <= -max) {
                        newMax += spacing;
                    }
                }
                DEBUG_AUTOSCALE(@"chose new max: %.13g", -newMax);
                return -newMax;
            }
        }
    }
    
    // Special case for linear axes close to zero.
    if (_axisType == RSAxisTypeLinear) {
        // If max is close to zero, then just use zero
        if ( (max <= 0 || [self valueIsNearlyEqualToZero:max]) && max/(max - min) > -RS_SCALE_TO_FIT_MAX_SPACE_TO_ZERO_PERCENTAGE) {
            return 0;
        }
    }
    
    
    // Normal case -- find the closest enclosing tick mark.
    data_p spacing = [self calculateAutoSpacingForMin:min max:max];
    data_p reduced = (data_p)ceil(max/spacing);  // reduce to int so can round
    data_p newMax = reduced*spacing;  // then grow back to full size
    
    return newMax;
}

- (data_p)closestTickMarkToMin:(data_p)min;
{
    return [self _closestTickMarkToMin:min usingMax:[self max]];
}

- (data_p)closestTickMarkToMax:(data_p)max;
{
    return [self _closestTickMarkToMax:max usingMin:[self min]];
}

- (void)expandRangeToIncludeValue:(data_p)value;
{
    if (value < [self min]) {
        
        data_p adjustedValue = value;
        if (value != 0) {
            data_p border = ([self max] - value)*RS_SCALE_TO_FIT_BORDER_PERCENTAGE;
            adjustedValue = value - border;
        }
        
        [self setMin:[self _closestTickMarkToMin:adjustedValue usingMax:[self max]]];
    }
    else if (value > [self max]) {
        
        data_p adjustedValue = value;
        if (value != 0) {
            data_p border = (value - [self min])*RS_SCALE_TO_FIT_BORDER_PERCENTAGE;
            adjustedValue = value + border;
        }
        
        [self setMax:[self _closestTickMarkToMax:adjustedValue usingMin:[self min]]];
    }
    // otherwise do nothing
}

- (void)expandRangeToIncludePoint:(RSDataPoint)p;
{
    if ([self orientation] == RS_ORIENTATION_HORIZONTAL) {
        [self expandRangeToIncludeValue:p.x];
    } else {
        [self expandRangeToIncludeValue:p.y];
    }
}

- (void)setRangeAsClosestTickMarksToMin:(data_p)min andMax:(data_p)max;
{
    if (min == DBL_MAX || max == -DBL_MAX || !isfinite(min) || !isfinite(max)) {
        return;  // bail out if there was not enough data
    }
    
    // Check for 0-width range
    if (nearlyEqualDataValues(min, max)) {
        DEBUG_RS(@"nearlyEqual min and max");
        
        if (min >= [self min] && max <= [self max]) {
            return;  // bail out if it is a zero-width range within the current range
        }
        
        if (min < [self min])
            max = [self max];
        if (max > [self max])
            min = [self min];
    }
    OBASSERT(!nearlyEqualDataValues(min, max));
    
    data_p newMin = min;
    data_p newMax = max;
    
    if (_axisType == RSAxisTypeLogarithmic) {
        if (newMin <= 0 && newMax > 0) {
            newMin = _logMin;
        }
        if (newMax == 0) {
            newMax = _logMax;
        }
    }
    
    // Save the min/max values we had to make sure we don't take them too far.
    data_p savedNewMin = newMin;
    data_p savedNewMax = newMax;
    
    // Add a small amount of padding to non-zero ends of the range
    if ([self usesLinearAutoSpacing]) {
        data_p range = max - min;
        if (min != 0) {
            newMin = min - range*RS_SCALE_TO_FIT_BORDER_PERCENTAGE;
        }
        if (max != 0) {
            newMax = max + range*RS_SCALE_TO_FIT_BORDER_PERCENTAGE;
        }
    }
    else if (_axisType == RSAxisTypeLogarithmic) {
        if (min != 0) {
            newMin *= (1 - RS_SCALE_TO_FIT_BORDER_PERCENTAGE);
        }
        if (max != 0) {
            newMax *= (1 + RS_SCALE_TO_FIT_BORDER_PERCENTAGE);
        }
    }

    // If padding resulted in swapping a min or max from positive to negative, go back to the original
    if (savedNewMin*newMin < 0)
        newMin = savedNewMin;
    if (savedNewMax*newMax < 0) {
        newMax = savedNewMax;
    }
    
    DEBUG_AUTOSCALE(@"start setRange with min: %.13g, max: %.13g", newMin, newMax);
    
    // Cycle through twice to converge on a solution
    for (int i = 0; i<2; i++) {
        newMin = [self _closestTickMarkToMin:newMin usingMax:newMax];
        newMax = [self _closestTickMarkToMax:newMax usingMin:newMin];
    }
    
    DEBUG_AUTOSCALE(@"end setRange with min: %.13g, max: %.13g", newMin, newMax);
    
    [self setMin:newMin andMax:newMax];
}

@synthesize userModifiedRange = _userModifiedRange;
- (void)setUserModifiedRange:(BOOL)flag;
{
    if (_userModifiedRange == flag)
        return;
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] setUserModifiedRange:_userModifiedRange];
    
    _userModifiedRange = flag;
}

@synthesize scientificNotationSetting = _scientificNotation;
- (void)setScientificNotationSetting:(RSScientificNotationSetting)flag;
{
    if (_scientificNotation == flag)
        return;
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] setScientificNotationSetting:_scientificNotation];
    
    _scientificNotation = flag;
    
    [self resetNumberFormatters];
    [self updateAxisEndLabels];
    [self resetTickLabelSizeCaches];
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}

- (data_p)visualOrigin;
{
    RSAxis *otherAxis = [_graph otherAxis:self];
    if( [otherAxis placement] != RSOriginPlacement || [self min] >= 0 || [self max] < 0 )
        return [self min];
    else
        return 0.0;
}

- (BOOL)zeroLabelIsHidden;
{
    RSAxis *otherAxis = [_graph otherAxis:self];
    if ([otherAxis displayAxis] && [otherAxis placement] == RSOriginPlacement && [otherAxis visualOrigin] != [otherAxis min]) {
        return YES;
    }
    return NO;
}


///////////////////////////////////////////
#pragma mark -
#pragma mark Axis Type
///////////////////////////////////////////

- (RSAxisType)axisType {
    return _axisType;
}
- (void)setAxisType:(RSAxisType)newType;
{
    if (_axisType == newType)
        return;
    
    self.cachedTickArray = nil;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setAxisType:_axisType];
    
    if (![undoManager isUndoing]) {
	[[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Axis Type", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _axisType = newType;
    
    if (_axisType == RSAxisTypeLogarithmic) {
        [self _updateLogScaleParameters];
    }
    
    [self updateTickMarks];
    [self resetNumberFormatters];
    
    [_minLabel setTickValue:[self min] axisOrientation:_orientation];
    [_maxLabel setTickValue:[self max] axisOrientation:_orientation];
    [self updateAxisEndLabels];
    
    [self resetTickLabelSizeCaches];
    
    // Need new tick labels, etc.
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
    
    // ... and points snapped to lines will be in a new location. <bug:///71043>
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
    
    
    
    /*
    NSDate *minDate;
    NSDate *maxDate;
    CGFloat minRep, maxRep;
    
    if( _axisType != newType ) {
	// first
	Log1(@"changing axis type to: %d", newType);
	_axisType = newType;
	
	if( newType == RSAxisTypeLinear ) {
	    [self setMin:0 andMax:10];
	}
	//
	else if( newType == RSAxisTypeDate ) {
	    // choose suitable min/max
	    // the min will be right now
	    minDate = [NSDate date];
	    // the max will be 10 days from now (in seconds)
	    maxDate = [NSDate dateWithTimeIntervalSinceNow:10*24*60*60];
	    // convert to float representation
	    minRep = (float)[minDate timeIntervalSinceReferenceDate];
	    maxRep = (float)[maxDate timeIntervalSinceReferenceDate];
	    //NSLog(@"min: %f, max: %f", minRep, [maxDate timeIntervalSinceReferenceDate]);
	    // update such that no errors are thrown
	    [self setMin:minRep andMax:maxRep];
	}
	else {
	    NSLog(@"Error: axis type not supported in [RSAxis setAxisType]");
	}
	
	// last
	[self updateTickMarks];
	
    }
     */
}

- (BOOL)isLinear;
{
    return (_axisType == RSAxisTypeLinear || _axisType == RSAxisTypeDate);
}

- (BOOL)usesEvenlySpacedTickMarks;
{
    if (_axisType == RSAxisTypeLogarithmic && [self ordersOfMagnitude] < 0.8)
        return YES;
    else
        return (_axisType == RSAxisTypeLinear);
}

- (BOOL)usesLinearAutoSpacing;
{
    if (_axisType == RSAxisTypeLogarithmic && [self ordersOfMagnitude] <= RSMagnitudeOfRangeForLogarithmicAutoScaling)
        return YES;
    else
        return (_axisType == RSAxisTypeLinear);
}



///////////////////////////////////////////
#pragma mark -
#pragma mark Tick spacing
///////////////////////////////////////////
- (data_p)spacing;
{
    data_p range = [self max] - [self min];
    if ( _spacing > range ) {
        OBASSERT_NOT_REACHED("Tick spacing should not be more than the range of the axis");
	return range;
    }
    else  return _spacing;
}
- (void)setSpacing:(data_p)value {
    if (_spacing == value)
        return;
    
    self.cachedTickArray = nil;
    
    data_p max = [self max];
    data_p min = [self min];
    data_p range = max - min;
    if (value > range) {
        OBASSERT_NOT_REACHED("Tick spacing should not be more than the range of the axis");
        value = range;
    }
    
    if ( ![self valueIsNearlyEqualToZero:value] // for finite-precision reasons
        && ((max - min) <= (value * RSMaximumNumberOfTicks))  // not too many ticks displayed
        )
        _spacing = value;
    else {
        OBASSERT_NOT_REACHED("Illegal axis spacing should have been caught sooner.");
        _spacing = (max - min)/100;
    }
    
    [self updateSpacingSigFigs];
    [self updateAxisEndLabels];
}

- (void)updateSpacingSigFigs;
{
    // Calculate the number of significant digits in the spacing.  This is used to configure number formatters.
    NSString *format = [NSString stringWithFormat:@"%.12e", _spacing];
    // Remove exponent part
    NSRange eRange = [format rangeOfString:@"e"];
    format = [format substringToIndex:eRange.location];
    // Remove trailing zeros
    format = [format stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0"]];
    // Remove decimal point
    format = [format stringByReplacingOccurrencesOfString:@"." withString:@""];
    //NSLog(@"format: %@", format);
    _spacingSigFigs = [format length];
    
    if (_spacingSigFigs > 12)  // Sanity check
        _spacingSigFigs = 12;
}

- (data_p)userSpacing {
    return _userSpacing;
}
- (void)setUserSpacing:(data_p)value;
{
    if (_userSpacing == value)
	return;
    
    self.cachedTickArray = nil;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setUserSpacing"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setUserSpacing:_userSpacing];
    }
    
    _userSpacing = value;
    
    [self updateTickMarks];  // sets the _spacing variable
    
    [_graph.delegate modelChangeRequires:RSUpdateWhitespace];
}


- (void)updateTickMarks;
// Update tick spacing if necessary and clear the tick array cache.
{
    data_p spacing = [self calculateAutoSpacingForMin:[self min] max:[self max]];
    [self setSpacing:spacing];
    
    if (![self usesEvenlySpacedTickMarks]) {
        self.cachedTickArray = nil;
        self.tickLabelSpacing = 0;
        
        if (_axisType == RSAxisTypeDate) {
            // Set date format based on date range
            [self updateDateFormat];
        }
    }
}


- (data_p)ordersOfMagnitude;
{
    data_p max = [self max];
    data_p min = [self min];
    
    if (_axisType == RSAxisTypeLogarithmic) {
        data_p range = magnitudeOfRangeRelativeToZero(min, max);
        return log10(range);
    }
    else {
        data_p range = max - min;
        return log10(range);
    }
}

- (data_p)_baseTickSpacing;
// Only use for linear axes
{
    data_p max = [self max];
    data_p min = [self min];
    data_p range = max - min;
    
    data_p order = floor(log10(range) - log10(2.5));
    return pow(10, order);
}

- (data_p)calculateAutoSpacingForMin:(data_p)min max:(data_p)max;
// This is for linear axes with even spacing.
{
    data_p ticks, spacing = 1;
    
    if( max == min ) {
	OBASSERT_NOT_REACHED("Proposed axis min and max are the same.");
	NSLog(@"Problem: Proposed axis min (%f) and max (%f) are the same.", min, max);
	// Let's just use 0 or 10 to make the range non-zero
	if( min > 0.00001 )  min = 0;
	else if( max < 0.00001 )  max = 0;
	else { // min == max == 0
	    max = 10;
	}
    }
    data_p range = max - min;
    
    if( _userSpacing && _axisType == RSAxisTypeLinear ) {
	ticks = range/_userSpacing;
	if( ticks >= 1 && ticks <= RSMaximumNumberOfTicks ) {  // use the user-set spacing
	    return _userSpacing;
	}
    }
    
    // Special case for tick spacing == 1
    if (range >= (RSMinimumNumberOfTicksForAutoSpacingEqualToOne - 1e-12) && range <= (RSMaximumNumberOfTicksForAutoSpacingEqualToOne + 1e-12)) {
        spacing = 1;
    }
    
    // if got this far, the system has to choose good spacing.
    else {
        spacing = [self _baseTickSpacing];
        ticks = range/spacing;
        
        if( ticks < 6.67 )  spacing /= 2;
        else if( ticks > 13.33 )  spacing *= 2;
    }
    
    OBASSERT(range/spacing <= RSMaximumNumberOfTicks);
    
    DEBUG_AUTOSCALE(@"autoSpacing: %.13g", spacing);
    return spacing;
}

- (data_p)snapTickSpacing:(data_p)spacing;
{
    data_p base = [self _baseTickSpacing]/10;  // start out with an order of magnitude less than the base for autospacing
    //NSLog(@"base: %f", base);
    
    // Don't snap to any tick spacing smaller than this base amount.
    if (spacing < base) {
        return base;
    }
    
    // Snap to one of these multiples.
    data_p multiples[] = {1.0f, 1.5f, 2.0f, 2.5f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 10.0f, 15.0f, 20.0f, 25.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f, 100.0f, 200.0f};
    for (int i=0; i<22; i++) {
        
        data_p snap1 = base * multiples[i];
        data_p snap2 = base * multiples[i + 1];
        
        if (spacing > snap2)
            continue;
        
        data_p mid = (snap1 + snap2)/2;
        if (spacing < mid)
            return snap1;
        else
            return snap2;
    }
    
    return spacing;
}

//- (NSInteger)numberOfTickRegimes;
//// The number of "sets" of tick marks, where each set uses 1/10 the previous tick spacing.
//{
//    if (_axisType != RSAxisTypeLogarithmic)
//        return 1;
//    
//    data_p max = [self max];
//    data_p min = [self min];
//    
//    // Normalize the axis range to a number that reflects the orders of magnitude spanned relative to the distance from zero:
//    data_p n = magnitudeOfRangeRelativeToZero(min, max);
//    
//    // We empirically determined that aesthetic cutoffs between numbers of regimes happen whenever _n_ passes a multiple of 2.5.
//    NSInteger regimes = ceil(log10(n/2.5));
//    if (regimes < 1) {
//        regimes = 1;
//    }
//    return regimes;
//}

- (data_p)tickSpacingWithTickLimit:(NSInteger)tickLimit;
// Calculated tick spacing for major tick marks
{
    data_p range, minorSpacing;
    if ([self usesEvenlySpacedTickMarks]) {
        range = [self max] - [self min];
        minorSpacing = [self spacing];
    }
    else {  // logarithmic
        range = fabs(log10(fabs([self max])) - log10(fabs([self min])));
        minorSpacing = 1;
    }
    
    NSInteger multiples[] = {1, 2, 5, 10, 20, 25, 50, 100, 200};
    for (int i=0; i<9; i++) {
        
        NSInteger multiple = multiples[i];
        
        data_p majorSpacing = minorSpacing * (data_p)multiple;
        data_p ticks = range/majorSpacing;
        
        if (ticks <= tickLimit) {
            return majorSpacing;
        }
    }
    
    // If got this far, there are a LOT of tick marks
    return minorSpacing * 500.0f;
}

@synthesize tickLabelSpacing = _tickLabelSpacing;

- (BOOL)usesMinorTicks;
{
    if (_axisType == RSAxisTypeLinear) {
        if (!_tickLabelSpacing)
            return NO;
        
        data_p ticksPer = _tickLabelSpacing/[self spacing];
        if (ticksPer >= 5.0 - 1e-12) {  // allow for rounding error
            return YES;
        }
    }
    else if (_axisType == RSAxisTypeLogarithmic) {
        if ([self ordersOfMagnitude] >= RSLogarithmicMinorLabelsMaxMagnitude)
            return YES;
        
        return (_tickLabelSpacing > 0);
    }
    
    return NO;
}

- (BOOL)tickIsMinor:(data_p)tick;
{
    if (![self usesMinorTicks])
        return NO;
    
    RSAxisType axisType = [self axisType];
    
    if (axisType == RSAxisTypeLinear) {
        //NSLog(@"tick: %g, remainder: %.15g", tick, remainder(tick, _tickLabelSpacing));
        return (fabs(remainder(tick, _tickLabelSpacing)) > 1e-12);
    }
    else if (axisType == RSAxisTypeLogarithmic) {
        
        if ([self max] < 0)  // If all-negative log axis, make it positive for this calculation
            tick = -tick;
        
        // Tick marks that are not powers of 10 are always minor.
        data_p reduced = log10(tick);
        if ( !nearlyEqualDataValues(reduced, floor(reduced)) )
            return YES;
        
        // If tickLabelSpacing is > 1, intermediate powers of 10 can also be minor.
        return (fabs(remainder(reduced, _tickLabelSpacing)) > 1e-12);
    }
    
    return NO;
}

- (data_p)firstTick;
{
    return [self closestTickMarkToMin:[self min]];
}

- (data_p)controlTick;
// This is the second tick out from the axis min. So in the common case that a tick mark falls on the axis min, the control tick is the first tick that's not the min.
{
    NSArray *allTicks = [self allTicks];
    if ([allTicks count] < 2) {
        return ([self max] - [self min])/5;
    }
    
    data_p first = [self firstTick];
    NSUInteger tickIndex = (first == [self min]) ? 0 : 1;
    return [[allTicks objectAtIndex:tickIndex] doubleValue];
}


#pragma mark -
#pragma mark Computing tick marks

@synthesize cachedTickArray = _cachedTickArray;

- (NSMutableArray *)linearTicksWithSpacing:(data_p)spacing min:(data_p)min max:(data_p)max;
// Returns the tick positions in data coords
{
    NSMutableArray *array = [NSMutableArray array];
    
    // Sanity check for reasonable spacing values.
    if (spacing == 0 || (max - min)/spacing > RSMaximumNumberOfTicks) {
        return array;
    }
    
    // Intermediate ticks
    data_p tickStart = (data_p)nearbyint(([self min]/* - 0*/)/spacing) * spacing;
    
    for (data_p p = tickStart; p < max; p += spacing) {
        if (p <= min || p >= max)
            continue;
        
        [array addObject:[NSNumber numberWithDouble:p]];
    }
    
    return array;
}

- (NSMutableArray *)linearTicksWithSpacing:(data_p)spacing;
{
    return [self linearTicksWithSpacing:spacing min:[self min] max:[self max]];
}

- (NSArray *)linearTicks;
{
    if (!_cachedTickArray) {
        self.cachedTickArray = [self linearTicksWithSpacing:[self spacing]];
    }
    return self.cachedTickArray;
}

- (NSMutableArray *)logarithmicTicksWithRegimeBoundarySpacing:(data_p)regimeBoundarySpacing min:(data_p)min max:(data_p)max;
// Returns the tick positions in data coords.  regimeBoundarySpacing is in powers of 10; a value of 0 means to return between-regime tick marks too.
{
    // If the range is small compared to the distance from zero, use linear tick marks.
    if ([self usesEvenlySpacedTickMarks]) {
        return [self linearTicksWithSpacing:[self spacing]];
    }
    
    NSMutableArray *array = [NSMutableArray array];
    
    BOOL reversed = NO;
    if (min < 0 && max < 0) {
        reversed = YES;
        data_p realMin = min;
        min = -max;
        max = -realMin;
    }
    
    OBASSERT(regimeBoundarySpacing >= 0);
    if (!regimeBoundarySpacing) {
        if ([self ordersOfMagnitude] > RSLogarithmicMinorTickMarksMaxMagnitude)
            regimeBoundarySpacing = 1;
        
        CGFloat axisLength = dimensionOfSizeInOrientation([_graph sizeOfGraphRect], _orientation);
        CGFloat pixelsPerRegime = axisLength/(CGFloat)[self ordersOfMagnitude];
        if (pixelsPerRegime < RSLogarithmicMinorTickMarksMinPixels) {
            regimeBoundarySpacing = 1;
        }
    }
    
    NSInteger top = (NSInteger)ceil(log10(max));
    //DEBUG_RS(@"regimes: %d, baseSpacing: %g", regimes, baseSpacing);
    NSInteger orderIncrement = (NSInteger)MAX(1, regimeBoundarySpacing);
    NSInteger orderStart = (NSInteger)floor(log10(min)/orderIncrement) * orderIncrement;
    
    for (NSInteger r = orderStart; r <= top; r += orderIncrement) {  // For each tick regime
        data_p spacing = pow(10, r);
        
        // Start at a multiple of spacing
        data_p start = MAX(min, spacing);
        data_p tickStart = (data_p)nearbyint((start/* - 0*/)/spacing) * spacing;
        data_p stop = spacing * 10;
        if (r == top) {
            stop = max;  // Small tick spacing values might go past the multiple of 10 in the largest regime
        }
        
        if (regimeBoundarySpacing) {
            stop = tickStart + spacing;
        }
        
        for (data_p p = tickStart; p < stop; p += spacing) {
            if (p <= min)
                continue;
            
            if (p >= max)
                return array;
            
            data_p tickValue = reversed ? -p : p;
            [array addObject:[NSNumber numberWithDouble:tickValue]];
        }
    }
    
    // Make sure the ticks are in ascending order
    [array sortUsingSelector:@selector(compare:)];
    
    return array;
}

- (NSMutableArray *)logarithmicTicksWithRegimeBoundarySpacing:(data_p)regimeBoundarySpacing;
{
    return [self logarithmicTicksWithRegimeBoundarySpacing:regimeBoundarySpacing min:[self min] max:[self max]];
}

- (NSArray *)logarithmicTicks;
{
    if (!_cachedTickArray) {
        self.cachedTickArray = [self logarithmicTicksWithRegimeBoundarySpacing:0];
    }
    return self.cachedTickArray;
}

- (NSMutableArray *)dateTicksWithMin:(data_p)min max:(data_p)max;
// Returns the tick positions in data coords
{
    DEBUG_RS(@"Computing date ticks");
    NSMutableArray *array = [NSMutableArray array];
    
    data_p range = max - min;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *minDate = [NSDate dateWithTimeIntervalSinceReferenceDate:min];
    //NSDate *maxDate = [NSDate dateWithTimeIntervalSinceReferenceDate:max];
    
    NSDateComponents *oneSpacingUnit = [[[NSDateComponents alloc] init] autorelease];
    NSUInteger unitFlags = 0;// = NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    
    if( range > 3*365.2422*24*60*60 ) {  // > 3 years
        data_p spacing = 365.2422*24*60*60;  // years
        return [self linearTicksWithSpacing:spacing];
    }
    else if( range > 3*31*24*60*60 ) {  // > 3 months
        //spacing = (365.2422/12)*24*60*60; // months
        
        // Space by month
        [oneSpacingUnit setMonth:1];
        unitFlags = NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit;
    }
//    else if( range > 35*24*60*60 ) {  // > 35 days
//        //spacing = 7*24*60*60;  // weeks
//        [oneSpacingUnit setWeek:1];
//        unitFlags = NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit;
//    }
    else if( range > 3*24*60*60 ) {  // > 3 days
        //spacing = 24*60*60;  // days
        [oneSpacingUnit setDay:1];
        unitFlags = NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
    }
    else if( range > 12*60*60 ) {  // > 12 hours
        //spacing = 60*60;  // hours
        [oneSpacingUnit setHour:1];
        unitFlags = NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit;
    }
    else if( range > 10*60 ) {  // > 10 minutes
        //spacing = 60;  // minutes
    }
    else if( range > 60 ) {  // > 1 minutes
        //spacing = 20;  // 20 seconds
    }
    else if( range > 3 ) {  // > 3 seconds
        return [self linearTicksWithSpacing:[self spacing]];
    }
    else {  // < 3 seconds
        return [self linearTicksWithSpacing:[self spacing]];
    }
    
    
    NSDateComponents *minDateComponents = [calendar components:unitFlags fromDate:minDate];
    NSDate *tickDate = [calendar dateFromComponents:minDateComponents];
    data_p tickValue = [tickDate timeIntervalSinceReferenceDate];
    
    while (tickValue < max) {
        tickDate = [calendar dateByAddingComponents:oneSpacingUnit toDate:tickDate options:0];
        tickValue = [tickDate timeIntervalSinceReferenceDate];
        
        if (tickValue > min && tickValue < max) {
            if (_orientation)
                NSLog(@"using date: %@", [tickDate descriptionWithLocale:[NSLocale currentLocale]]);
            
            [array addObject:[NSNumber numberWithDouble:tickValue]];
        }
    }
    
    return array;
}

- (NSArray *)dateTicks;
{
    if (!_cachedTickArray) {
        self.cachedTickArray = [self dateTicksWithMin:[self min] max:[self max]];
    }
    return self.cachedTickArray;
}

- (NSArray *)allTicks;
// Returns an array of tick mark locations in data coords.  Does not include the min and max tick.  The tick marks are in ascending sequential order in the array.
{
    NSArray *tickArray = nil;
    if (_axisType == RSAxisTypeLogarithmic) {
        tickArray = [self logarithmicTicks];
    } else if (_axisType == RSAxisTypeDate) {
        tickArray = [self dateTicks];
    } else {
        tickArray = [self linearTicks];
    }
    
#if 0 && defined(DEBUG_robin)
    NSMutableArray *tickStrings = [NSMutableArray arrayWithCapacity:[tickArray count]];
    for (NSNumber *tick in tickArray) {
        [tickStrings addObject:[tick stringValue]];
    }
    NSLog(@"ticks: %@", [tickStrings componentsJoinedByComma]);
#endif
    
    return tickArray;
}

- (NSMutableArray *)samplingTicks;
// Tries to return a representative sample of all tick marks, for tick label sizing purposes.
{
    data_p spacingMagnitude = [self tickSpacingWithTickLimit:14];
    if ([self usesEvenlySpacedTickMarks]) {
        return [self linearTicksWithSpacing:spacingMagnitude];
    }
    else if (_axisType == RSAxisTypeLogarithmic) {
        return [self logarithmicTicksWithRegimeBoundarySpacing:spacingMagnitude];
    }
    
    return nil;
}

- (NSMutableArray *)dataTicks;
{
    // Data ticks do not use the cache, since they change so often.
    
    NSMutableArray *array = [NSMutableArray array];
    int orientation = [self orientation];
    
    for (RSVertex *V in [_graph Vertices]) {
        if ([V isBar])
            continue;
        if ([V shape] == RS_NONE)
            continue;
        
        data_p p = dimensionOfDataPointInOrientation([V position], orientation);
        [array addObject:[NSNumber numberWithDouble:p]];
    }
    
    return array;
}


///////////////////////////////////////////
#pragma mark -
#pragma mark Grid
///////////////////////////////////////////
@synthesize grid = _grid;


///////////////////////////////////////////
#pragma mark -
#pragma mark Number formatting
///////////////////////////////////////////

- (NSUInteger)significantDigits;
{
    data_p sigfigs = RS_DEFAULT_SIGNIFICANT_DIGITS;
    
    data_p range = [self max] - [self min];
    data_p bigger = MAX(fabs([self max]), fabs([self min]));
    data_p logRatio = log10(range/bigger);
    if (logRatio <= -1) {
        sigfigs += floor(-logRatio);
    }
    
    //NSLog(@"maxSigFigs: %d", (NSInteger)sigfigs);
    OBASSERT(sigfigs >= RS_DEFAULT_SIGNIFICANT_DIGITS);
    return (NSUInteger)sigfigs;
}

- (NSUInteger)minimumSignificantDigitsForValue:(data_p)val;
// Formula: # of sig figs in the tick spacing + difference in orders of magnitude between the data point and the tick spacing.
{
    if ([self valueIsNearlyEqualToZero:val]) {
        return 1;
    }
    
    if (_spacingSigFigs == 0) {
        [self updateSpacingSigFigs];
    }
    
    // Find the difference in orders of magnitude between the data value and the tick spacing
    data_p valOrders = floor(log10(fabs(val)));
    data_p spacingOrders = floor(log10([self spacing]));
    NSInteger orderDiff = (NSInteger)nearbyint(valOrders - spacingOrders);
    if (orderDiff < 0) {
        orderDiff = 0;
    }
    
    //NSLog(@"For val: %.13g; spacingFigs: %d; orderDiff: %d", val, _spacingSigFigs, orderDiff);
    return _spacingSigFigs + orderDiff;
}

- (BOOL)usesDecimalPoint;
{
    if ([self usesEvenlySpacedTickMarks]) {
        return ([self spacing] < 1.0);
    }
    else if (_axisType == RSAxisTypeLogarithmic) {
        if ([self min] > 0)
            return ([self min] < 1.0);
        else
            return ([self max] > -1.0);
    }
    
    // If in doubt
    return NO;
}

- (BOOL)usesScientificNotation;
{
    if (_scientificNotation == RSScientificNotationSettingOn) {
        return YES;
    }
    
    data_p min = [self min];
    data_p max = [self max];
    
    data_p highStart, lowStart;
    if (_scientificNotation == RSScientificNotationSettingOff) {
        highStart = RSScientificNotationOffHighStart;
        lowStart = RSScientificNotationOffLowStart;
    } else {
        if (_axisType == RSAxisTypeLogarithmic ) {
            highStart = RSScientificNotationAutoHighStartLogarithmic;
        } else {
            highStart = RSScientificNotationAutoHighStart;
        }
        lowStart = RSScientificNotationAutoLowStart;
    }
    
    if ([self axisType] == RSAxisTypeLinear) {
        data_p biggest = MAX(fabs(max), fabs(min));
        if (biggest >= highStart)
            return YES;
        
        data_p smallest = MIN(fabs(max), fabs(min));
        data_p range = max - min;
        return (smallest < lowStart && range < lowStart);
    }
    else {  // RSAxisTypeLogarithmic
        if (min > 0) {
            return (max >= highStart || min < lowStart);
        } else {
            return (max > -lowStart || min <= -highStart);
        }
    }
}

- (NSNumberFormatter *)tickLabelNumberFormatter;
{
    if (!_tickLabelNumberFormatter) {
        _tickLabelNumberFormatter = [[NSNumberFormatter alloc] init];
        
        [_tickLabelNumberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        
        [_tickLabelNumberFormatter setLenient:YES];
        [_tickLabelNumberFormatter setUsesSignificantDigits:YES];
        [_tickLabelNumberFormatter setZeroSymbol:@"0"];
    }
    
    return _tickLabelNumberFormatter;
}

- (NSNumberFormatter *)inspectorNumberFormatter;
// When we want to display full-precision formatted numbers (to reassure users).
{
    if (!_inspectorNumberFormatter) {
        _inspectorNumberFormatter = [[NSNumberFormatter alloc] init];
        
        [_inspectorNumberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        
        [_inspectorNumberFormatter setLenient:YES];
        [_inspectorNumberFormatter setUsesSignificantDigits:YES];
        [_inspectorNumberFormatter setZeroSymbol:@"0"];
    }
    
    return _inspectorNumberFormatter;
}

- (void)resetNumberFormatter:(NSNumberFormatter *)formatter withSignificantDigits:(NSUInteger)sigfigs;
{
    if ([self usesScientificNotation]) {
        [formatter setNumberStyle:NSNumberFormatterScientificStyle];
        
        [formatter setLenient:YES];
        [formatter setUsesSignificantDigits:YES];
        [formatter setZeroSymbol:@"0"];
    } else {
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        
        [formatter setLenient:YES];
        [formatter setUsesSignificantDigits:YES];
        [formatter setZeroSymbol:@"0"];
    }
    
    [formatter setMaximumSignificantDigits:sigfigs];
}

- (void)resetNumberFormatters;
{
    [self resetNumberFormatter:[self tickLabelNumberFormatter] withSignificantDigits:[self significantDigits]];
    [self resetNumberFormatter:[self inspectorNumberFormatter] withSignificantDigits:15];
}

- (void)configureNumberFormatter:(NSNumberFormatter *)formatter forValue:(data_p)val;
{
    if (![self usesScientificNotation]) {
        BOOL usesGroupingSeparator = (fabs(val) >= 10000);
        if ([formatter usesGroupingSeparator] != usesGroupingSeparator)
            [formatter setUsesGroupingSeparator:usesGroupingSeparator];
    }
    
//    if (!useMinSigFigs) {
//        NSLog(@"val: %.13g; sigFigs: %d", val, sigfigs);
//    }

//    NSUInteger minSigFigs = 0;
//    if (useMinSigFigs && _axisType == RSAxisTypeLinear) {
//        minSigFigs = [self minimumSignificantDigitsForValue:val];
//    }
//    if ([formatter minimumSignificantDigits] != minSigFigs)
//        [formatter setMinimumSignificantDigits:minSigFigs];
}

- (NSString *)useNumberFormatter:(NSNumberFormatter *)formatter toFormatDataValue:(data_p)value;
{
    if ([self valueIsNearlyEqualToZero:value]) {
        value = 0;
    }
    
    [self configureNumberFormatter:formatter forValue:value];
    
    NSString *string = [formatter stringForObjectValue:[NSNumber numberWithDouble:value]];
    return string;
}

- (NSString *)formattedDataValue:(data_p)value;
{
    return [self useNumberFormatter:[self tickLabelNumberFormatter] toFormatDataValue:value];
}

- (NSString *)inspectorFormattedDataValue:(data_p)value;
{
    return [self useNumberFormatter:[self inspectorNumberFormatter] toFormatDataValue:value];
}

- (data_p)dataValueFromFormat:(NSString *)format;
{
    NSNumberFormatter *formatter = [self tickLabelNumberFormatter];
    NSNumber *number = [formatter numberFromString:format];
    return [number doubleValue];
}



static NSDateFormatter *tickFormatterDates = nil;
//static NSNumberFormatter *tickFormatterThousands = nil;
//static NSNumberFormatter *tickFormatterTens = nil;
//static NSNumberFormatter *tickFormatterTenths = nil;

+ (NSDateFormatter *)sharedDateFormatter;
{
    if (!tickFormatterDates) {
        tickFormatterDates = [[NSDateFormatter alloc] init];
        [tickFormatterDates setFormatterBehavior:NSDateFormatterBehavior10_4];
    }
    return tickFormatterDates;
}

- (void)updateDateFormat;
{
    //
    // see http://unicode.org/reports/tr35/tr35-4.html#Date_Format_Patterns for details on the formatting codes
    //
    Log1(@"updateDateFormat");
    
    if( _axisType != RSAxisTypeDate )  return;
    
    data_p range = [self max] - [self min];
    
    NSDateFormatter *formatter = [RSAxis sharedDateFormatter];
    
    if( range > 3*365*24*60*60 ) {  // > 3 years
	[formatter setDateFormat:@"yyyy"];
    }
    else if( range > 12*31*24*60*60 ) {  // > 12 months
	[formatter setDateFormat:@"MMM, yyyy"];
    }
    else if( range > 3*31*24*60*60 ) {  // > 3 months
	[formatter setDateFormat:@"MMM"];
    }
    else if( range > 3*24*60*60 ) {  // > 3 days
	[formatter setDateFormat:@"MMM. d"];
    }
    else if( range > 12*60*60 ) {  // > 12 hours
	[formatter setDateFormat:@"h:mm a"];
    }
    else if( range > 10*60 ) {  // > 10 minutes
	[formatter setDateFormat:@"h:mm a"];
    }
    else if( range > 60 ) {  // > 1 minutes
	[formatter setDateFormat:@"h:mm:ss"];
    }
    else if( range > 3 ) {  // > 1 seconds
	[formatter setDateFormat:@"s.SS 's'"];
    }
    else {  // < 1 second
	[formatter setDateFormat:@"SSS"];
    }
    
    // update the (weird) min and max labels
    [_maxLabel setText:[self formattedDataValue:[self max]]];
    [_minLabel setText:[self formattedDataValue:[self min]]];
    
}

- (NSAttributedString *)formatExponentsInString:(NSAttributedString *)original;
{
    NSNumberFormatter *formatter = [self tickLabelNumberFormatter];
    BOOL removeLeadingOne = (_axisType == RSAxisTypeLogarithmic);
    
    return [RSTextLabel formatExponentsInString:original exponentSymbol:[formatter exponentSymbol] removeLeadingOne:removeLeadingOne];
}


///////////////////////////////////////////
#pragma mark -
#pragma mark Tick labels
///////////////////////////////////////////

- (NSString *)keyStringForTick:(data_p)value {
    // this ensures that the min and max labels stay constant
    if( value == [self min] )  return @"minLabel";
    if( value == [self max] )  return @"maxLabel";
    // else
    return [self formattedDataValue:value];
}
- (NSString *)stringForTick:(data_p)value {
    // this is just the string version of a numeric tick
    return [self formattedDataValue:value];
}
- (BOOL)userLabelExistsForTick:(data_p)value;
{
    NSString *key = [self keyStringForTick:value];
    return ([_userLabels objectForKey:key] != nil);
}
- (BOOL)userLabelIsCustomForTick:(data_p)value;
{
    // Don't look any farther if a user label hasn't even been created for this tick.
    if (![self userLabelExistsForTick:value]) {
        return NO;
    }
    
    // Make the key into a string:
    NSString *formattedNumber = [self formattedDataValue:value];
    // Find the text of the user label:
    NSString *userLabelText = [[self userLabelForTick:value] text];
    //NSLog(@"key: '%@', userLabelText: '%@'", key, userLabelText);
    if ( [formattedNumber isEqualToString:userLabelText] ) 
	return NO;
    else  return YES;
}
- (RSTextLabel *)userLabelForTick:(data_p)value {
    RSTextLabel *userLabel;
    
    // Make the key into a string:
    NSString *key = [self keyStringForTick:value];
    userLabel = [_userLabels objectForKey:key];
    
    if( !userLabel ) {  // if nil, create a new default label
	userLabel = [[_maxLabel copy] autorelease];
	[userLabel setText:key];
	// and "cache" it:
	[self setUserLabel:userLabel forTick:value];
        [userLabel setVisible:NO];  // Assume the new label is invisible until it actually gets displayed
    }
    return userLabel;
}
- (RSTextLabel *)nonEndUserLabelForTick:(data_p)value {
    RSTextLabel *userLabel;
    
    // Make the key into a string:
    NSString *key = [self formattedDataValue:value];
    userLabel = [_userLabels objectForKey:key];
    
    if( !userLabel ) {  // if nil, create a new default label
	userLabel = [[_maxLabel copy] autorelease];
	[userLabel setText:key];
	// and "cache" it:
	[self setUserLabel:userLabel forTick:value andKey:key];
        [userLabel setVisible:NO];  // Assume the new label is invisible until it actually gets displayed
    }
    return userLabel;
}
- (void)setUserLabel:(RSTextLabel *)label forTick:(data_p)value {
    // Make the key into a string:
    NSString *key = [self keyStringForTick:value];
    [self setUserLabel:label forTick:value andKey:key];
}
- (void)setUserLabel:(RSTextLabel *)label forTick:(data_p)value andKey:(NSString *)key;
{
    if ( label ) {
	OBASSERT([label isKindOfClass:[RSTextLabel class]]);
	OBASSERT(![_userLabels objectForKey:key]);
	
	//atm, user labels are never really removed once created//
	//[[[_graph undoManager] prepareWithInvocationTarget:self] setUserLabel:nil forTick:value andKey:key];
	
	[_userLabels setObject:label forKey:key];
	[label setTickValue:value axisOrientation:_orientation];
    }
    // if label is nil, revert to the default text
    else {
	[self setUserString:[self formattedDataValue:value] forTick:value];
//	[_userLabels removeObjectForKey:key];
    }
}
- (void)setUserString:(NSString *)userString forTick:(data_p)value {
    RSTextLabel *userLabel = [self nonEndUserLabelForTick:value];
    OBASSERT(userLabel);
    [userLabel setText:userString];
}

- (NSDictionary *)userLabelsDictionary;
{
    return _userLabels;
}
- (RSGroup *)allUserLabels;
{
    RSGroup *G = [RSGroup groupWithGraph:_graph];
    for (id obj in [_userLabels objectEnumerator]) {
	[G addElement:obj];
    }
    // add min/max labels:
    [G addElement:_minLabel];
    [G addElement:_maxLabel];
    
    return G;
}
- (RSGroup *)visibleUserLabels;
{
    RSGroup *G = [RSGroup groupWithGraph:_graph];

    for (RSTextLabel *TL in [_userLabels objectEnumerator]) {
	if( [TL isVisible] )  [G addElement:TL];
    }
    // add min/max labels:
    [G addElement:_minLabel];
    [G addElement:_maxLabel];
    //RSGroup *G = [[[RSGroup alloc] initWithGraph:_graph byCopyingArray:[_userLabels allValues]] autorelease];
    return G;
}
- (BOOL)shouldDisplayLabel:(RSGraphElement *)TL {
    if( ![self displayTickLabels] && (TL == _minLabel || TL == _maxLabel) )
	return NO;
    if( ![self displayTitle] && TL == _axisTitle )
	return NO;
    // else:
    return YES;
}

- (void)updateAxisEndLabels;
{
    if( ![_maxLabel isDeletedString] ) {
	[_maxLabel setText:[self formattedDataValue:[self max]]];
    }
    
    if( ![_minLabel isDeletedString] ) {
	[_minLabel setText:[self formattedDataValue:[self min]]];
    }
    
    // I'm not sure why the cache reset in -[RSTextLabel setText:] isn't kicking in. This fixes: <bug:///73047> (When editing axis max tick label without re-typing the "E", label goes too far to the right).
    [_maxLabel resetSizeCache];
    [_minLabel resetSizeCache];
}

- (void)resetUserLabelVisibility;
{
    for (NSString *key in _userLabels) {
        RSTextLabel *TL = [_userLabels objectForKey:key];
        [TL setVisible:NO];
    }
}

- (void)purgeUnnecessaryUserLabels;
{
    if ([_userLabels count] <= 50) {  // don't bother checking if there are fewer than 50 labels (per axis)
        return;
    }
    
    NSMutableArray *keyArray = [[NSMutableArray alloc] init];
    for (NSString *key in _userLabels) {
        RSTextLabel *TL = [_userLabels objectForKey:key];
        if ([TL isVisible])
            continue;
        
        if (TL == _maxLabel || TL == _minLabel) {
            continue;
        }
        
#if 0 && defined(DEBUG_robin)
        data_p tickValue = [TL tickValue];
        NSString *derivedKey = [self keyStringForTick:tickValue];
        RSTextLabel *derivedLabel = [_userLabels objectForKey:derivedKey];
        if (!derivedLabel) {
            NSLog(@"Tried to purge label with key '%@'", derivedKey);
        }
        OBASSERT(derivedLabel);
#endif
        
        // Preserve user-customized values
        if ( ![key isEqualToString:[TL text]] ) {
            continue;
        }
        
// This has side effects on _userLabels:
//        if ([self userLabelIsCustomForTick:[TL tickValue]]) {

// This could maybe work:
//        double doubleVal;
//        BOOL isNumber = [RSNumber getStrictDoubleValue:&doubleVal forString:TL.text];
//        if (!isNumber) {
//            continue;
//        }
        
        // Otherwise, mark for removal
        [keyArray addObject:key];
    }
    
#if defined(DEBUG_robin)
    NSString *someLabels = [[keyArray subarrayWithRange:NSMakeRange(0, [keyArray count]/2)] componentsJoinedByString:@", "];
    NSLog(@"Purging %d unnecessary user labels out of %d.", (int)[keyArray count], (int)[_userLabels count]);
    NSLog(@"Some of the purged labels: %@", someLabels);
#endif
    
    [_userLabels removeObjectsForKeys:keyArray];
    [keyArray release];
}

- (void)resetTickLabelSizeCaches;
{
    for (NSString *key in _userLabels) {
        RSTextLabel *TL = [_userLabels objectForKey:key];
        [TL resetSizeCache];
    }
}


////////////////////////////////////
#pragma mark -
#pragma mark Describing
////////////////////////////////////
- (NSString *)prettyName {
    if ( _orientation == RS_ORIENTATION_HORIZONTAL )
	return  @"X-Axis";
    if ( _orientation == RS_ORIENTATION_VERTICAL )
	return  @"Y-Axis";
    
    OBASSERT_NOT_REACHED("Unknown axis type.");
    return nil;
}




@end
