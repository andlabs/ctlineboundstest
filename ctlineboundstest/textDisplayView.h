// 8 january 2017
#import <Cocoa/Cocoa.h>

@interface textDisplayView : NSView<NSTextFieldDelegate> {
	NSString *str;
	NSFont *font;
	CTFramesetterRef framesetter;
	CGFloat inputWidth;
	CFRange fitRange;
	CGSize expectedSize;
}
- (void)controlTextDidChange:(NSNotification *)obj;
- (void)changeFont:(id)sender;
- (IBAction)checkboxToggled:(id)sender;
- (IBAction)paragraphStyleCheckboxToggled:(id)sender;
@end
