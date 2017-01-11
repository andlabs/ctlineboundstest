// 8 january 2017
#import "textDisplayView.h"

@interface textDisplayView ()
@property (weak) IBOutlet NSButton *showBaselines;
@property (weak) IBOutlet NSButton *showTypographicBounds;
@property (weak) IBOutlet NSButton *show108Bounds;
@property (weak) IBOutlet NSButton *showBaselineDiffs;

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
	CGFloat thirty = 30.0;
	CGFloat two = 2.0;
	
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
		settings[i].value = &thirty;
		i++;
	}
	
	if ([self.useParagraphSpacing state] != NSOffState) {
		settings[i].spec = kCTParagraphStyleSpecifierParagraphSpacing;
		settings[i].valueSize = sizeof (CGFloat);
		settings[i].value = &thirty;
		i++;
	}
	
	if (i == 0)
		return NULL;
	return CTParagraphStyleCreate(settings, i);
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
	// in order for these particular paragraph styles to take effect, we need to actually *have* paragraphs
	stringToUse = self->str;
	if ([self multiParagraph])
		stringToUse = [NSString stringWithFormat:@"%@\n%@\n%@", self->str, self->str, self->str];
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

- (void)drawGuides:(CGContextRef)c for:(CTFrameRef)frame
{
	BOOL drawAnything;
	BOOL showBaselines, showTypographicBounds, show108Bounds, fillBaselineDiff;
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
