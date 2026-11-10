//
//  RSLatexMarkup.h
//  GraphSketcher
//
//  LaTeX-style markup for text labels (added for the Apple Silicon port).
//
//  Forward (when editing ends):
//    \alpha, \Delta, \leq, \infty, \minus, ...  -> Unicode symbols   (unknown commands are left as typed)
//    _{...}  -> subscript,   ^{...}  -> superscript                  (braces required)
//    \_  \^  \{  \}  \\  \%  \$  \#  \&  -> the literal character
//    A hyphen becomes a true minus sign (U+2212) inside sub/superscripts, and in front of a number
//    when it follows the start of the label, a space, ( [ = , < or >.
//    A command may run straight into following letters (\DeltaY -> ΔY), end with {} (\Delta{}Y),
//    or end with a single space, which is dropped as in LaTeX (\Delta Y -> ΔY).
//
//    Spacing: \, thin  \: or \> medium  \; thick  \quad  \qquad  "\ " normal space  \! (removed).
//
//  Reverse (for display in the Inspector): rich text -> the same markup.
//
//  Header-only (static functions) so it can be shared without changing the Xcode project.

#import <Cocoa/Cocoa.h>

static NSDictionary *RSLatexSymbolTable(void)
{
    static NSDictionary *table = nil;
    if (table == nil) {
        table = [[NSDictionary alloc] initWithObjectsAndKeys:
                 // Greek, lowercase
                 @"α", @"alpha", @"β", @"beta", @"γ", @"gamma", @"δ", @"delta",
                 @"ε", @"epsilon", @"ε", @"varepsilon", @"ζ", @"zeta", @"η", @"eta",
                 @"θ", @"theta", @"ϑ", @"vartheta", @"ι", @"iota", @"κ", @"kappa",
                 @"λ", @"lambda", @"μ", @"mu", @"ν", @"nu", @"ξ", @"xi",
                 @"ο", @"omicron", @"π", @"pi", @"ϖ", @"varpi", @"ρ", @"rho",
                 @"ϱ", @"varrho", @"σ", @"sigma", @"ς", @"varsigma", @"τ", @"tau",
                 @"υ", @"upsilon", @"φ", @"phi", @"φ", @"varphi", @"χ", @"chi",
                 @"ψ", @"psi", @"ω", @"omega",
                 // Greek, uppercase
                 @"Γ", @"Gamma", @"Δ", @"Delta", @"Θ", @"Theta", @"Λ", @"Lambda",
                 @"Ξ", @"Xi", @"Π", @"Pi", @"Σ", @"Sigma", @"Υ", @"Upsilon",
                 @"Φ", @"Phi", @"Ψ", @"Psi", @"Ω", @"Omega",
                 // Operators and relations
                 @"\u2009", @",", @"\u205F", @":", @"\u205F", @">", @"\u2005", @";", @"", @"!", @" ", @" ",
                 @"\u2003", @"quad", @"\u2003\u2003", @"qquad",
                 @"\u2212", @"minus", @"±", @"pm", @"∓", @"mp", @"×", @"times", @"÷", @"div",
                 @"·", @"cdot", @"∗", @"ast", @"∘", @"circ", @"∙", @"bullet",
                 @"≤", @"leq", @"≤", @"le", @"≥", @"geq", @"≥", @"ge",
                 @"≠", @"neq", @"≠", @"ne", @"≈", @"approx", @"≡", @"equiv",
                 @"∼", @"sim", @"≃", @"simeq", @"∝", @"propto", @"≪", @"ll", @"≫", @"gg",
                 @"∞", @"infty", @"∂", @"partial", @"∇", @"nabla",
                 @"∑", @"sum", @"∏", @"prod", @"∫", @"int", @"√", @"sqrt",
                 @"→", @"rightarrow", @"→", @"to", @"←", @"leftarrow", @"↔", @"leftrightarrow",
                 @"⇒", @"Rightarrow", @"⇐", @"Leftarrow", @"⇔", @"Leftrightarrow",
                 @"↑", @"uparrow", @"↓", @"downarrow", @"↦", @"mapsto",
                 @"∈", @"in", @"∉", @"notin", @"⊂", @"subset", @"⊆", @"subseteq",
                 @"∪", @"cup", @"∩", @"cap", @"∅", @"emptyset", @"∀", @"forall", @"∃", @"exists",
                 @"¬", @"neg", @"∧", @"wedge", @"∨", @"vee",
                 @"°", @"degree", @"′", @"prime", @"…", @"ldots", @"⋯", @"cdots", @"…", @"dots",
                 @"ℓ", @"ell", @"ħ", @"hbar", @"∠", @"angle", @"⊥", @"perp", @"∥", @"parallel",
                 @"‖", @"Vert", @"∣", @"mid", @"⟨", @"langle", @"⟩", @"rangle",
                 @"⌈", @"lceil", @"⌉", @"rceil", @"⌊", @"lfloor", @"⌋", @"rfloor",
                 nil];
    }
    return table;
}


static NSDictionary *RSLatexReverseSymbolTable(void)
{
    static NSDictionary *reverse = nil;
    if (reverse == nil) {
        NSSet *preferred = [NSSet setWithObjects:@"epsilon", @"phi", @"leq", @"geq", @"neq", @"rightarrow", @"ldots", nil];
        NSMutableDictionary *r = [NSMutableDictionary dictionary];
        NSDictionary *table = RSLatexSymbolTable();
        for (NSString *name in [[table allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *symbol = [table objectForKey:name];
            if ([r objectForKey:symbol] == nil || [preferred containsObject:name])
                [r setObject:name forKey:symbol];
        }
        [r removeObjectForKey:@"−"];  // minus sign is handled specially
        [r removeObjectForKey:@" "];        // ordinary spaces stay as they are
        [r removeObjectForKey:@""];
        reverse = [r copy];
    }
    return reverse;
}

// Placeholders (Unicode private-use characters) protect escaped literals during conversion.
#define RSLatexEscapeChars @"_^{}\\%$#&"
#define RSLatexPlaceholderBase 0xE100
#define RSLatexMinusSign @"−"

static BOOL RSLatexIsMinusContextBefore(unichar c)
{
    return [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c] || c == '(' || c == '[' || c == '=' || c == ',' || c == '<' || c == '>';
}

static void RSLatexShiftScript(NSMutableAttributedString *str, NSRange range, NSInteger delta)
{
    // Adjust superscript level and shrink to 2/3 size, matching GraphSketcher's own Superscript/Subscript menu commands.
    NSMutableArray *runs = [NSMutableArray array];
    [str enumerateAttribute:NSSuperscriptAttributeName inRange:range options:0 usingBlock:^(id value, NSRange r, BOOL *stop) {
        [runs addObject:@[[NSValue valueWithRange:r], @([value integerValue] + delta)]];
    }];
    for (NSArray *run in runs)
        [str addAttribute:NSSuperscriptAttributeName value:[run objectAtIndex:1] range:[[run objectAtIndex:0] rangeValue]];
    
    [runs removeAllObjects];
    [str enumerateAttribute:NSFontAttributeName inRange:range options:0 usingBlock:^(id value, NSRange r, BOOL *stop) {
        if (value)
            [runs addObject:@[[NSValue valueWithRange:r], [(NSFont *)value fontWithSize:[(NSFont *)value pointSize] * 2.0 / 3.0]]];
    }];
    for (NSArray *run in runs)
        [str addAttribute:NSFontAttributeName value:[run objectAtIndex:1] range:[[run objectAtIndex:0] rangeValue]];
}

// Returns the converted string, or nil if nothing needed converting.
static NSAttributedString *RSConvertLatexMarkup(NSAttributedString *input)
{
    NSString *s = [input string];
    if ([s rangeOfString:@"\\"].location == NSNotFound && [s rangeOfString:@"{"].location == NSNotFound && [s rangeOfString:@"-"].location == NSNotFound)
        return nil;
    
    NSMutableAttributedString *m = [[input mutableCopy] autorelease];
    NSDictionary *table = RSLatexSymbolTable();
    NSString *escapes = RSLatexEscapeChars;
    BOOL changed = NO;
    
    // Pass 1: backslash commands and escapes, processed from the end so earlier ranges stay valid.
    NSRegularExpression *cmdRE = [NSRegularExpression regularExpressionWithPattern:@"\\\\([A-Za-z]+|[_^\\{\\}\\\\%$#&,:;>! ])(\\{\\}| )?" options:0 error:NULL];
    NSArray *matches = [cmdRE matchesInString:[m string] options:0 range:NSMakeRange(0, [m length])];
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSString *name = [[m string] substringWithRange:[match rangeAtIndex:1]];
        NSString *replacement = nil;
        NSRange replaceRange = [match range];
        
        NSRange escapeIndex = [escapes rangeOfString:name];
        BOOL isEscape = ([name length] == 1 && escapeIndex.location != NSNotFound);
        // As in LaTeX, one space after a command name (\alpha y) just ends the name and is dropped;
        // after an escaped character (\% ) the space is kept.
        BOOL isControlSymbol = ([name length] == 1 && ![[NSCharacterSet letterCharacterSet] characterIsMember:[name characterAtIndex:0]]);
        if (isControlSymbol && [match rangeAtIndex:2].location != NSNotFound && [[[m string] substringWithRange:[match rangeAtIndex:2]] isEqualToString:@" "])
            replaceRange.length -= 1;
        if (isEscape) {
            unichar placeholder = (unichar)(RSLatexPlaceholderBase + escapeIndex.location);
            replacement = [NSString stringWithCharacters:&placeholder length:1];
        } else if ((replacement = [table objectForKey:name]) == nil) {
            // Allow a command to run straight into following letters: \DeltaY -> ΔY. Use the longest known prefix.
            for (NSUInteger len = [name length] - 1; len >= 2 && replacement == nil; len--) {
                replacement = [table objectForKey:[name substringToIndex:len]];
                if (replacement)
                    replaceRange = NSMakeRange([match range].location, 1 + len);  // backslash + prefix; keep the rest
            }
        }
        if (replacement) {
            [m replaceCharactersInRange:replaceRange withString:replacement];
            changed = YES;
        }
    }
    
    // Pass 2: hyphen in front of a number -> minus sign.
    NSRegularExpression *negRE = [NSRegularExpression regularExpressionWithPattern:@"-(?=\\.?[0-9])" options:0 error:NULL];
    for (NSTextCheckingResult *match in [negRE matchesInString:[m string] options:0 range:NSMakeRange(0, [m length])]) {
        NSUInteger loc = [match range].location;
        if (loc == 0 || RSLatexIsMinusContextBefore([[m string] characterAtIndex:loc - 1])) {
            [m replaceCharactersInRange:NSMakeRange(loc, 1) withString:RSLatexMinusSign];  // same length, ranges stay valid
            changed = YES;
        }
    }
    
    // Pass 3: _{...} and ^{...}; repeat so nested forms work from the inside out.
    NSRegularExpression *scriptRE = [NSRegularExpression regularExpressionWithPattern:@"([_^])\\{([^{}]*)\\}" options:0 error:NULL];
    for (NSUInteger pass = 0; pass < 10; pass++) {
        NSArray *scripts = [scriptRE matchesInString:[m string] options:0 range:NSMakeRange(0, [m length])];
        if ([scripts count] == 0)
            break;
        for (NSTextCheckingResult *match in [scripts reverseObjectEnumerator]) {
            NSRange whole = [match range];
            NSRange content = [match rangeAtIndex:2];
            NSInteger delta = [[[m string] substringWithRange:[match rangeAtIndex:1]] isEqualToString:@"^"] ? 1 : -1;
            // hyphens inside sub/superscripts are minus signs
            for (NSUInteger i = content.location; i < NSMaxRange(content); i++)
                if ([[m string] characterAtIndex:i] == '-')
                    [m replaceCharactersInRange:NSMakeRange(i, 1) withString:RSLatexMinusSign];
            if (content.length > 0)
                RSLatexShiftScript(m, content, delta);
            [m deleteCharactersInRange:NSMakeRange(NSMaxRange(whole) - 1, 1)];                          // closing brace
            [m deleteCharactersInRange:NSMakeRange(whole.location, content.location - whole.location)];  // "_{" or "^{"
            changed = YES;
        }
    }
    
    // Restore escaped literals.
    NSMutableString *plain = [m mutableString];
    for (NSUInteger i = 0; i < [escapes length]; i++) {
        unichar placeholder = (unichar)(RSLatexPlaceholderBase + i);
        [plain replaceOccurrencesOfString:[NSString stringWithCharacters:&placeholder length:1]
                               withString:[escapes substringWithRange:NSMakeRange(i, 1)]
                                  options:0 range:NSMakeRange(0, [plain length])];
    }
    
    return changed ? m : nil;
}

// Converts rich label text back into markup, for editing in the Inspector.
static NSString *RSLatexMarkupFromAttributedString(NSAttributedString *a)
{
    if (a == nil)
        return @"";
    NSString *s = [a string];
    NSDictionary *reverse = RSLatexReverseSymbolTable();
    NSCharacterSet *asciiLetters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    NSMutableString *out = [NSMutableString string];
    
    [a enumerateAttribute:NSSuperscriptAttributeName inRange:NSMakeRange(0, [s length]) options:0 usingBlock:^(id value, NSRange run, BOOL *stop) {
        NSInteger level = [value integerValue];
        BOOL inScript = (level != 0);
        NSMutableString *piece = [NSMutableString string];
        for (NSUInteger i = run.location; i < NSMaxRange(run); i++) {
            unichar c = [s characterAtIndex:i];
            NSString *ch = [NSString stringWithCharacters:&c length:1];
            NSString *name = [reverse objectForKey:ch];
            if (c == '\\' || c == '{' || c == '}') {
                [piece appendFormat:@"\\%@", ch];
            } else if (c == 0x2212) {
                BOOL beforeNumber = (i + 1 < [s length]) && ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[s characterAtIndex:i + 1]] || [s characterAtIndex:i + 1] == '.');
                BOOL goodContext = (i == 0) || RSLatexIsMinusContextBefore([s characterAtIndex:i - 1]);
                [piece appendString:(inScript || (beforeNumber && goodContext)) ? @"-" : @"\\minus{}"];
            } else if (name) {
                [piece appendFormat:@"\\%@", name];
                if ([asciiLetters characterIsMember:[name characterAtIndex:0]] && i + 1 < NSMaxRange(run) && ([asciiLetters characterIsMember:[s characterAtIndex:i + 1]] || [s characterAtIndex:i + 1] == ' '))
                    [piece appendString:@"{}"];
            } else {
                [piece appendString:ch];
            }
        }
        if (level > 0)
            [out appendFormat:@"^{%@}", piece];
        else if (level < 0)
            [out appendFormat:@"_{%@}", piece];
        else
            [out appendString:piece];
    }];
    return out;
}
