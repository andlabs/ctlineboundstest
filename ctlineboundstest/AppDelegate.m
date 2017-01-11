// 8 january 2017
#import "AppDelegate.h"

// TODOs
// - run a test to see where the line differences don't match ascent+descent+leading from typographic bounds is the largest positive
// - TODO make all the panels float

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSPanel *metricsPanel;
@property (weak) IBOutlet NSScrollView *scrollView;
@property (weak) IBOutlet NSSlider *scrollZoom;
- (IBAction)setMagnification:(id)sender;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
	NSFontPanel *fp;
	
	fp = [[NSFontManager sharedFontManager] fontPanel:YES];
	// make it match the metrics panel
	[fp setStyleMask:([fp styleMask] & ~(NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask))];
	// and show it
	[[NSFontManager sharedFontManager] orderFrontFontPanel:self];
	
	// for some reason this property isn't settable in IB...
	[fp setFloatingPanel:NO];
	[self.metricsPanel setFloatingPanel:NO];
	
	[self.scrollZoom setMinValue:[self.scrollView minMagnification]];
	[self.scrollZoom setMaxValue:[self.scrollView maxMagnification]];
	[self.scrollZoom setDoubleValue:[self.scrollView magnification]];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
	return YES;
}

// TODO this is wonky with respect to how the text display view responds
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
