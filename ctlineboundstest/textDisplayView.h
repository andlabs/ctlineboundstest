// 8 january 2017
#import <Cocoa/Cocoa.h>

@interface textDisplayView : NSView<NSTextFieldDelegate> {
	NSString *str;
	NSFont *font;
	CTFramesetterRef framesetter;
	CGFloat frameHeight;
}
- (void)controlTextDidChange:(NSNotification *)obj;
- (void)changeFont:(id)sender;
@end
