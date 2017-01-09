// 8 january 2017
#import "AppDelegate.h"

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
	[[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
	return YES;
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
