// 8 january 2017
#import "textDisplayView.h"

@interface textDisplayView ()
@property (weak) IBOutlet NSButton *showBaselines;
@property (weak) IBOutlet NSButton *showTypographicBounds;
@property (weak) IBOutlet NSButton *show108Bounds;
@property (weak) IBOutlet NSButton *showBaselineDiffs;
@property (weak) IBOutlet NSButton *showAlgorithm;

@property (weak) IBOutlet NSButton *useParagraphSpaceBefore;
@property (weak) IBOutlet NSButton *useLineHeight;
@property (weak) IBOutlet NSButton *useLineSpacing;
@property (weak) IBOutlet NSButton *useParagraphSpacing;

@property (unsafe_unretained) IBOutlet NSTextView *metricsBox;
@end

@implementation textDisplayView

- (id)initWithFrame:(NSRect)r
{
	self = [super initWithFrame:r];
	if (self)
		[self awakeFromNib];
	return self;
}

- (void)awakeFromNib
{
	self->str = @"";
	self->font = [NSFont fontWithName:@"Helvetica" size:12];
	[[NSFontManager sharedFontManager] setSelectedFont:self->font isMultiple:NO];
	self->framesetter = NULL;
	self->inputWidth = 0;
	self->fitRange = CFRangeMake(kCFNotFound, 0);
	
	[self recomputeFrameSize:[self frame].size.width];
}

- (void)dealloc
{
	if (self->framesetter != NULL)
		CFRelease(self->framesetter);
}

// TODO why is this needed to get the view at the top of the scroll view?
- (BOOL)isFlipped
{
	return YES;
}

- (CTParagraphStyleRef)mkParagraphStyle
{
	CTParagraphStyleSetting settings[20];
	size_t i;
	CGFloat two = 2.0;
	CGFloat thirty = 30.0;
	CGFloat sixty = 60.0;
	CGFloat ninety = 90.0;
	
	memset(settings, 0, 20 * sizeof (CTParagraphStyleSetting));
	i = 0;
	
	if ([self.useParagraphSpaceBefore state] != NSOffState) {
		settings[i].spec = kCTParagraphStyleSpecifierParagraphSpacingBefore;
		settings[i].valueSize = sizeof (CGFloat);
		settings[i].value = &thirty;
		i++;
	}

	if ([self.useLineHeight state] != NSOffState) {
		settings[i].spec = kCTParagraphStyleSpecifierLineHeightMultiple;
		settings[i].valueSize = sizeof (CGFloat);
		settings[i].value = &two;
		i++;
	}
	
	if ([self.useLineSpacing state] != NSOffState) {
		settings[i].spec = kCTParagraphStyleSpecifierLineSpacingAdjustment;
		settings[i].valueSize = sizeof (CGFloat);
		settings[i].value = &sixty;
		i++;
	}
	
	if ([self.useParagraphSpacing state] != NSOffState) {
		settings[i].spec = kCTParagraphStyleSpecifierParagraphSpacing;
		settings[i].valueSize = sizeof (CGFloat);
		settings[i].value = &ninety;
		i++;
	}
	
	if (i == 0)
		return NULL;
	return CTParagraphStyleCreate(settings, i);
}

- (NSString *)stringToUse
{
	NSString *stringToUse;
	
	// in order for these particular paragraph styles to take effect, we need to actually *have* paragraphs
	stringToUse = self->str;
	if ([self multiParagraph])
		stringToUse = [NSString stringWithFormat:@"%@\n%@\n%@", self->str, self->str, self->str];
	return stringToUse;
}

- (CTFramesetterRef)mkFramesetter
{
	CFMutableDictionaryRef dict;
	CTParagraphStyleRef ps;
	NSString *stringToUse;
	CFAttributedStringRef cas;
	CTFramesetterRef fs;
	
	dict = CFDictionaryCreateMutable(NULL, 0,
		&kCFCopyStringDictionaryKeyCallBacks,
		&kCFTypeDictionaryValueCallBacks);
	CFDictionaryAddValue(dict, kCTFontAttributeName, (CTFontRef) (self->font));
	ps = [self mkParagraphStyle];
	if (ps != NULL)
		CFDictionaryAddValue(dict, kCTParagraphStyleAttributeName, ps);
	stringToUse = [self stringToUse];
	cas = CFAttributedStringCreate(NULL,
		(CFStringRef) stringToUse,
		dict);
	fs = CTFramesetterCreateWithAttributedString(cas);
	CFRelease(cas);
	if (ps != NULL)
		CFRelease(ps);
	CFRelease(dict);
	return fs;
}

- (BOOL)multiParagraph
{
	return ([self.useParagraphSpaceBefore state] != NSOffState) || ([self.useParagraphSpacing state] != NSOffState);
}

- (CFRange)strRange
{
	CFRange range;
	
	range.location = 0;
	range.length = [self->str length];
	if ([self multiParagraph]) {
		range.length *= 3;
		range.length += 2;
	}
	return range;
}

- (void)setStroke:(CGContextRef)c r:(CGFloat)r g:(CGFloat)g b:(CGFloat)b
{
	static const CGFloat dashes[] = { 5, 2 };
	
	CGContextSetRGBStrokeColor(c, r, g, b, 0.5);
	CGContextSetLineWidth(c, 1);
	CGContextSetLineDash(c, 0, dashes, 2);
}

// TODO check this in pgdoc
static const CGFloat fillColors[][3] = {
	{ 1.0, 0.25, 0.0 },
	{ 1.0, 0.0, 0.25 },
};

static NSMutableString *loglog = nil;
static void addlogv(NSString *fmt, va_list ap)
{
	NSString *f;
	
	if (loglog == nil)
		loglog = [@"<\n" mutableCopy];
	f = [[NSString alloc] initWithFormat:fmt arguments:ap];
	[loglog appendString:f];
	[loglog appendString:@"\n"];
}
static void endlogv(NSString *fmt, va_list ap)
{
	addlogv(fmt, ap);
	NSLog(@"%@>", loglog);
	loglog = nil;
}
static void addlog(NSString *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	addlogv(fmt, ap);
	va_end(ap);
}
static void endlog(NSString *fmt, ...)
{
	va_list ap;
	
	va_start(ap, fmt);
	endlogv(fmt, ap);
	va_end(ap);
}

- (void)drawGuides:(CGContextRef)c for:(CTFrameRef)frame
{
	BOOL drawAnything;
	BOOL showBaselines, showTypographicBounds, show108Bounds, fillBaselineDiff, showAlgorithm;
	CFArrayRef lines;
	CFIndex i, n;
	CGPoint *origins;
	CTLineRef line;

	drawAnything = NO;
	showBaselines = [self.showBaselines state] != NSOffState;
	drawAnything = drawAnything || showBaselines;
	showTypographicBounds = [self.showTypographicBounds state] != NSOffState;
	drawAnything = drawAnything || showTypographicBounds;
	show108Bounds = [self.show108Bounds state] != NSOffState;
	drawAnything = drawAnything || show108Bounds;
	fillBaselineDiff = [self.showBaselineDiffs state] != NSOffState;
	drawAnything = drawAnything || fillBaselineDiff;
	showAlgorithm = [self.showAlgorithm state] != NSOffState;
	drawAnything = drawAnything || showAlgorithm;
	if (!drawAnything)
		return;

	lines = CTFrameGetLines(frame);
	n = CFArrayGetCount(lines);
	if (n == 0)
		return;
	origins = (CGPoint *) malloc(n * sizeof (CGPoint));
	CTFrameGetLineOrigins(frame, CFRangeMake(0, n), origins);
	
	// TODO also draw ascent and descent
	if (showBaselines) {
		CGFloat width, ascent, descent;
		
		CGContextSaveGState(c);
		for (i = 0; i < n; i++) {
			line = (CTLineRef) CFArrayGetValueAtIndex(lines, i);
			width = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
			[self setStroke:c r:0.0 g:0.0 b:1.0];
			CGContextBeginPath(c);
			CGContextMoveToPoint(c, origins[i].x, origins[i].y);
			CGContextAddLineToPoint(c, origins[i].x + width, origins[i].y);
			CGContextStrokePath(c);
			[self setStroke:c r:1.0 g:0.0 b:1.0];
			CGContextBeginPath(c);
			CGContextMoveToPoint(c, origins[i].x, origins[i].y + ascent);
			CGContextAddLineToPoint(c, origins[i].x + width, origins[i].y + ascent);
			CGContextStrokePath(c);
			[self setStroke:c r:0.0 g:0.5 b:1.0];
			CGContextBeginPath(c);
			CGContextMoveToPoint(c, origins[i].x, origins[i].y - descent);
			CGContextAddLineToPoint(c, origins[i].x + width, origins[i].y - descent);
			CGContextStrokePath(c);
		}
		CGContextRestoreGState(c);
	}
	
	if (showTypographicBounds) {
		CGFloat width, ascent, descent, leading;
		CGRect r;
		
		CGContextSaveGState(c);
		[self setStroke:c r:1.0 g:0.0 b:0.0];
		for (i = 0; i < n; i++) {
			line = (CTLineRef) CFArrayGetValueAtIndex(lines, i);
			width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
			r.origin.x = origins[i].x;
			r.origin.y = origins[i].y - (descent + leading);
			r.size.width = width;
			r.size.height = ascent + descent + leading;
			CGContextBeginPath(c);
			CGContextAddRect(c, r);
			CGContextStrokePath(c);
		}
		CGContextRestoreGState(c);
	}
	
	if (show108Bounds) {
		CGRect r;

		CGContextSaveGState(c);
		[self setStroke:c r:0.0 g:1.0 b:0.0];
		for (i = 0; i < n; i++) {
			line = (CTLineRef) CFArrayGetValueAtIndex(lines, i);
			r = CTLineGetBoundsWithOptions(line, 0);
			r.origin.x += origins[i].x;
			r.origin.y += origins[i].y;
			CGContextBeginPath(c);
			CGContextAddRect(c, r);
			CGContextStrokePath(c);
		}
		CGContextRestoreGState(c);
	}
	
	// note: origins[i].y - origins[i + 1].y is the height of i + 1, NOT of i!
	// TODO this assumes the last line has kCTParagraphStyleSpecifierLineSpacingAdjustment (or alternatively: this treats kCTParagraphStyleSpecifierLineSpacingAdjustment like kCTParagraphStyleSpecifierLineHeightMultiple)
	// TODO this treats kCTParagraphStyleSpecifierParagraphSpacing like kCTParagraphStyleSpecifierParagraphSpacingBefore
	if (fillBaselineDiff) {
		CGRect r;
		int ci;
		
		CGContextSaveGState(c);
		ci = n % 2;
		r.origin.x = 0;
		r.origin.y = 0;
		r.size.width = [self frame].size.width;
		for (i = n - 2; i >= 0; i--) {		// this is safe because CFIndex is signed
			// TODO NOTE THAT THIS IS WRONG
			// this assumes that if the font is the same, all line ascents will be
			// but      oriigns[i].y - origins[i + 1].y != ascents[i  ] + descents[i] + leadings[i]
			// instead, oriigns[i].y - origins[i + 1].y != ascents[i+1] + descents[i] + leadings[i]
			// this is also why it seemed like they aligned to the next line
			r.size.height = origins[i].y - origins[i + 1].y;
			CGContextSetRGBFillColor(c, fillColors[ci][0], fillColors[ci][1], fillColors[ci][2], 0.375);
			CGContextBeginPath(c);
			CGContextAddRect(c, r);
			CGContextFillPath(c);
			r.origin.y += r.size.height;
			if (ci == 1)
				ci = 0;
			else
				ci = 1;
		}
		CGContextRestoreGState(c);
	}
	
	// TODO this still does not handle character-wrapped words properly
	if (showAlgorithm) {
		CGRect r;
		int ci;
		CGFloat curbl;
		
		CGContextSaveGState(c);
		ci = n % 2;
		r.origin.x = 0;
		r.origin.y = 0;
		r.size.width = [self frame].size.width;
		curbl = [self frame].size.height;
		for (i = 0; i < n; i++) {
			CTLineRef line;
			CGRect bounds, boundsNoLeading;
			CGFloat ascent, descent, leading;
			CFArrayRef runs;
			CTRunRef firstRun;
			__block CTParagraphStyleRef ps;
			
			line = (CTLineRef) CFArrayGetValueAtIndex(lines, i);
			bounds = CTLineGetBoundsWithOptions(line, 0);
			boundsNoLeading = CTLineGetBoundsWithOptions(line,
				kCTLineBoundsExcludeTypographicLeading);
			
			// this is equivalent to boundsNoLeading.size.height + boundsNoLeading.origin.y (manually verified)
			ascent = bounds.size.height + bounds.origin.y;
			descent = -boundsNoLeading.origin.y;
			// TODO does this preserve leading sign?
			leading = -bounds.origin.y - descent;
			
			ascent = floor(ascent + 0.5);
			descent = floor(descent + 0.5);
			if (leading > 0)
				leading = floor(leading + 0.5);
			
			ps = NULL;
			runs = CTLineGetGlyphRuns(line);
			if (CFArrayGetCount(runs) > 0) {
				CFDictionaryRef dict;
				
				firstRun = (CTRunRef) CFArrayGetValueAtIndex(runs, 0);
				dict = CTRunGetAttributes(firstRun);
				if (dict != NULL)
					ps = (CTParagraphStyleRef) CFDictionaryGetValue(dict, kCTParagraphStyleAttributeName);
			}
			if (ps != NULL) {
				CGFloat (^get)(CTParagraphStyleSpecifier spec);
				CGFloat lineHeightMultiple;
				CGFloat maximumLineHeight;
				CGFloat minimumLineHeight;
				CGFloat minimumLineSpacing;
				CGFloat maximumLineSpacing;
				CGFloat lineSpacingAdjustment;
				CGFloat paragraphSpacing;
				CGFloat paragraphSpacingBefore;
				CGFloat lineHeight;
				CFRange cfrange;
				NSRange lineRange;
				NSUInteger paraStart, paraEnd;
				
				get = ^(CTParagraphStyleSpecifier spec){
					CGFloat ret;
					
					// don't check errors; we want the default of 0 on unknown specifier
					CTParagraphStyleGetValueForSpecifier(ps, spec, sizeof (CGFloat), &ret);
					return ret;
				};
				lineHeightMultiple = get(kCTParagraphStyleSpecifierLineHeightMultiple);
				if (lineHeightMultiple < 0)
					lineHeightMultiple = 0;
				maximumLineHeight = get(kCTParagraphStyleSpecifierMaximumLineHeight);
				if (maximumLineHeight < 0)
					maximumLineHeight = 0;
				minimumLineHeight = get(kCTParagraphStyleSpecifierMinimumLineHeight);
				if (minimumLineHeight < 0)
					minimumLineHeight = 0;
				minimumLineSpacing = get(kCTParagraphStyleSpecifierMinimumLineSpacing);
				if (minimumLineSpacing != 0)
					if (leading < minimumLineSpacing)
						leading = minimumLineSpacing;
				maximumLineSpacing = get(kCTParagraphStyleSpecifierMaximumLineSpacing);
				lineSpacingAdjustment = get(kCTParagraphStyleSpecifierLineSpacingAdjustment);
				paragraphSpacing = get(kCTParagraphStyleSpecifierParagraphSpacing);
				if (paragraphSpacing <= 0)
					paragraphSpacing = 0;
				paragraphSpacingBefore = get(kCTParagraphStyleSpecifierParagraphSpacingBefore);
				if (paragraphSpacingBefore <= 0)
					paragraphSpacingBefore = 0;
				if (lineHeightMultiple > 0) {
					// line height multiples grow the line above the baseline
					// TODO explain the logic here
					// lineHeightMultiple *= ascent + descent
					// ascent = ascent - ((ascent + descent) - lineHeightMultiple)
					lineHeightMultiple *= ascent + descent;
					ascent = ascent - ((ascent + descent) - lineHeightMultiple);
				}
				lineHeight = ascent + descent;
				if (maximumLineHeight > 0)
					if ((ascent + descent) > maximumLineHeight)
						// TODO explain the logic here
						// ascent = ascent - ((ascent + descent) - maximumLineHeight)
						ascent = maximumLineHeight - descent;
				if (minimumLineHeight > 0)
					if (minimumLineHeight > lineHeight)
						// TODO really explain the logic here
						// TODO copy the formula
						// TODO in particular explain the use of the old lineHeight
						// TODO isn't it used in the fomrula?
						ascent = minimumLineHeight - descent;
				// TODO simplify this somehow? also copy the formula
				lineSpacingAdjustment += leading;
				if (leading < lineSpacingAdjustment)
					leading = lineSpacingAdjustment;
				if (leading > maximumLineSpacing)
					leading = maximumLineSpacing;
				
				cfrange = CTLineGetStringRange(line);
				lineRange.location = cfrange.location;
				lineRange.length = cfrange.length;
				[[self stringToUse] getParagraphStart:&paraStart end:&paraEnd contentsEnd:NULL forRange:lineRange];
				if (lineRange.location != 0 && lineRange.location == paraStart)
					ascent += paragraphSpacingBefore;
				if (NSMaxRange(lineRange) == paraEnd)
					descent += paragraphSpacing;
			}
			
			r.origin.y = origins[i].y - descent - leading;
			r.size.height = ascent + descent + leading;
			CGContextSetRGBFillColor(c, fillColors[ci][0], fillColors[ci][1], fillColors[ci][2], 0.375);
			CGContextBeginPath(c);
			CGContextAddRect(c, r);
			CGContextFillPath(c);
			
			curbl -= ascent;
			if (curbl != origins[i].y)
				NSLog(@"%@ %ld/%ld expected %g got %g", self->font, i, n, origins[i].y, curbl);
			curbl -= descent + leading;
			
/*
			if (i < (n - 1)) {
				CGFloat so;
				CGFloat a, d, l;
				
				// TODO wait, which is correct, this one or the one above?
				so = origins[i].y - origins[i + 1].y;
				if (r.size.height != so) {
					addlog(@"%@ %ld/%ld expected %g got %g", self->font, i, n, so, r.size.height);
					addlog(@"%@ %@ %g %g", NSStringFromRect(bounds), NSStringFromRect(boundsNoLeading), descent, leading);
					addlog(@"%@", NSStringFromRect(r));
					CTLineGetTypographicBounds(line, &a, &d, &l);
					a = floor(a + 0.5);
					d = floor(d + 0.5);
					if (l > 0)
						l = floor(l + 0.5);
					endlog(@"a/d/l %g/%g/%g %g/%g/%g",
						ascent, descent, leading,
						a, d, l);
				}
*/
				
			if (ci == 1)
				ci = 0;
			else
				ci = 1;
		}
		// TODO check that curbl - leading is at where we expect it to be
		CGContextRestoreGState(c);
	}

	free(origins);
}

- (CTFrameRef)mkFrame
{
	CGRect br;
	CTFrameRef frame;
	CFRange range;
	CGPathRef path;

	br.origin = CGPointZero;
	br.size.width = [self frame].size.width;
	br.size.height = [self frame].size.height;
	range = [self strRange];
	path = CGPathCreateWithRect(br, NULL);
	frame = CTFramesetterCreateFrame(self->framesetter,
		range,
		path,
		NULL);
	CFRelease(path);
	return frame;
}

- (void)drawRect:(NSRect)r
{
	CGContextRef c;
	CTFrameRef frame;
	CGRect rr;
	
	c = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	
	CGContextSaveGState(c);
	rr.origin = CGPointZero;
	rr.size = NSSizeToCGSize([self frame].size);
	CGContextSetFillColorWithColor(c, [[NSColor textBackgroundColor] CGColor]);
	CGContextFillRect(c, rr);
	CGContextRestoreGState(c);

	CGContextSaveGState(c);
	CGContextTranslateCTM(c, 0, [self frame].size.height);
	CGContextScaleCTM(c, 1.0, -1.0);
	CGContextSetTextMatrix(c, CGAffineTransformIdentity);
	
	frame = [self mkFrame];
	CTFrameDraw(frame, c);
	[self drawGuides:c for:frame];
	CFRelease(frame);

	CGContextRestoreGState(c);
}

// TODO baseline height differences seem to fall apart at certain widths?
- (void)refillMetricsBox
{
	NSMutableString *s;
	CTFrameRef frame;
	CFArrayRef lines;
	CFIndex i, n;
	CGPoint *origins;
	CGFloat heightRemaining;

	s = [NSMutableString new];
	frame = [self mkFrame];
	lines = CTFrameGetLines(frame);
	n = CFArrayGetCount(lines);
	origins = (CGPoint *) malloc(n * sizeof (CGPoint));
	CTFrameGetLineOrigins(frame, CFRangeMake(0, n), origins);
	
	[s appendFormat:@"input width %g\n", self->inputWidth];
	[s appendFormat:@"expected frame size %@\n", NSStringFromSize(NSSizeFromCGSize(self->expectedSize))];
	[s appendFormat:@"actual frame size %@\n", NSStringFromSize([self frame].size)];
	[s appendFormat:@"input range %@ fit range %@\n",
		NSStringFromRange(NSMakeRange([self strRange].location, [self strRange].length)),
		NSStringFromRange(NSMakeRange(self->fitRange.location, self->fitRange.length))];
	heightRemaining = [self frame].size.height;
	
	[s appendFormat:@"%ld lines\n", n];
	for (i = 0; i < n; i++) {
		CTLineRef line;
		CGFloat width, ascent, descent, leading;
		NSRect nr;
		CGRect cr;
		
		line = (CTLineRef) CFArrayGetValueAtIndex(lines, i);
		[s appendFormat:@"line %ld\n", i];
		nr.origin = NSPointFromCGPoint(origins[i]);
		[s appendFormat:@"	baseline %@\n", NSStringFromPoint(nr.origin)];
		
		width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
		[s appendFormat:@"	typographic:\n"];
		[s appendFormat:@"		width %g\n", width];
		[s appendFormat:@"		ascent %g\n", ascent];
		[s appendFormat:@"		descent %g\n", descent];
		[s appendFormat:@"		leading %g\n", leading];
		nr.origin.y -= descent + leading;
		nr.size = NSMakeSize(width, ascent + descent + leading);
		[s appendFormat:@"		rect: %@\n", NSStringFromRect(nr)];
		if (i == (n - 1)) {
			nr.size.height = ascent + descent;
			[s appendFormat:@"		rect without leading: %@\n", NSStringFromRect(nr)];
		}
		
		cr = CTLineGetBoundsWithOptions(line, 0);
		cr.origin.x += origins[i].x;
		cr.origin.y += origins[i].y;
		nr = NSRectFromCGRect(cr);
		[s appendFormat:@"	10.8: %@\n", NSStringFromRect(nr)];
		
		if (i != (n - 1)) {
			CGFloat ht;
			
			ht = origins[i].y - origins[i + 1].y;
			[s appendFormat:@"	height OF next: %g\n", ht];
			if (i == 0)
				[s appendFormat:@"		expected total: %g\n", ht * n];
			heightRemaining -= ht;
		} else {
			[s appendFormat:@"	remaining height: %g\n", heightRemaining];
			[s appendFormat:@"		with leading: %g\n", heightRemaining + leading];
			[s appendFormat:@"		with floor(leading+0.5): %g\n", heightRemaining + floor(leading + 0.5)];
		}
	}
	
	free(origins);
	CFRelease(frame);
	[self.metricsBox setString:s];
}

- (void)recomputeFrameSize:(CGFloat)width
{
	CGSize frameSize;
	CFRange range;
	
	if (self->framesetter != NULL)
		CFRelease(self->framesetter);
	self->framesetter = [self mkFramesetter];
	range = [self strRange];
	self->inputWidth = width;
	frameSize = CTFramesetterSuggestFrameSizeWithConstraints(self->framesetter, range,
		NULL,
		CGSizeMake(width, CGFLOAT_MAX),
		&(self->fitRange));
	[self setFrameSize:NSMakeSize(width, frameSize.height)];
	self->expectedSize = frameSize;
	[self refillMetricsBox];
	[self setNeedsDisplay:YES];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
	[super resizeWithOldSuperviewSize:oldSize];
	[self recomputeFrameSize:[self frame].size.width];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
	NSTextField *tf;
 
	tf = (NSTextField *) [obj object];
	self->str = [tf stringValue];
	[self recomputeFrameSize:[self frame].size.width];
}

- (void)changeFont:(id)sender
{
	NSFontManager *fm = (NSFontManager *) sender;
	
	self->font = [fm convertFont:self->font];
	[self recomputeFrameSize:[self frame].size.width];
}

- (IBAction)checkboxToggled:(id)sender
{
	[self setNeedsDisplay:YES];
}

- (IBAction)paragraphStyleCheckboxToggled:(id)sender
{
	[self recomputeFrameSize:[self frame].size.width];
}

@end
