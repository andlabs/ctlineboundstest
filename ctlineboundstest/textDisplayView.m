// 8 january 2017
#import "textDisplayView.h"

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
	self->frameHeight = 0;
	
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

- (CTFramesetterRef)mkFramesetter
{
	CFMutableDictionaryRef dict;
	CFAttributedStringRef cas;
	CTFramesetterRef fs;
	
	dict = CFDictionaryCreateMutable(NULL, 0,
		&kCFCopyStringDictionaryKeyCallBacks,
		&kCFTypeDictionaryValueCallBacks);
	CFDictionaryAddValue(dict, kCTFontAttributeName, (CTFontRef) (self->font));
	cas = CFAttributedStringCreate(NULL,
		(CFStringRef) (self->str),
		dict);
	fs = CTFramesetterCreateWithAttributedString(cas);
	CFRelease(cas);
	CFRelease(dict);
	return fs;
}

- (void)drawRect:(NSRect)r
{
	CGContextRef c;
	CTFrameRef frame;
	CFRange range;
	CGPathRef path;
		
	c = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	
	CGContextSaveGState(c);
	CGContextTranslateCTM(c, 0, [self bounds].size.height);
	CGContextScaleCTM(c, 1.0, -1.0);
	CGContextSetTextMatrix(c, CGAffineTransformIdentity);
	
	range.location = 0;
	range.length = [self->str length];
	path = CGPathCreateWithRect([self bounds], NULL);
	frame = CTFramesetterCreateFrame(self->framesetter,
		range,
		path,
		NULL);
	CTFrameDraw(frame, c);
	CFRelease(path);
	CFRelease(frame);
	
	CGContextRestoreGState(c);
}

- (void)recomputeFrameSize:(CGFloat)width
{
	CGSize frameSize;
	CFRange range;
	CFRange fitRange;
	
	if (self->framesetter != NULL)
		CFRelease(self->framesetter);
	self->framesetter = [self mkFramesetter];
	range.location = 0;
	range.length = [self->str length];
	frameSize = CTFramesetterSuggestFrameSizeWithConstraints(self->framesetter, range,
		NULL,
		CGSizeMake(width, CGFLOAT_MAX),
		&fitRange);
	self->frameHeight = frameSize.height;
	[self setFrameSize:NSMakeSize(width, self->frameHeight)];
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

@end
