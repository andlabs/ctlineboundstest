// 8 january 2017
#import "AppDelegate.h"

// TODOs
// - add an option for having line and paragraph styles taken into consideration
// - run a test to see where the line differences don't match ascent+descent+leading from typographic bounds is the largest positive
// - take a screenshot of the largest 10.8 difference

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSScrollView *scrollView;
@property (weak) IBOutlet NSSlider *scrollZoom;
- (IBAction)setMagnification:(id)sender;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
	[[NSFontManager sharedFontManager] orderFrontFontPanel:self];
	
	[self.scrollZoom setMinValue:[self.scrollView minMagnification]];
	[self.scrollZoom setMaxValue:[self.scrollView maxMagnification]];
	[self.scrollZoom setDoubleValue:[self.scrollView magnification]];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
	return YES;
}

- (IBAction)setMagnification:(id)sender
{
	[self.scrollView setMagnification:[self.scrollZoom doubleValue]];
}

@end

@implementation App

- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender
{
	if (action == @selector(changeFont:))
		target = self.chooseFontTarget;
	return [super sendAction:action to:target from:sender];
}

@end
