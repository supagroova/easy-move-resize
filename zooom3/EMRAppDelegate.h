#import <Cocoa/Cocoa.h>

@class EMRPopoverViewController;

@interface EMRAppDelegate : NSObject <NSApplicationDelegate, NSPopoverDelegate> {
    NSStatusItem * statusItem;
    int keyModifierFlags;
    int resizeKeyModifierFlags;
    int cachedMoveMouseButton;
    int cachedResizeMouseButton;
    BOOL cachedHasConflict;
    NSRunningApplication *lastApp;

    NSPopover *popover;
    EMRPopoverViewController *popoverVC;
    id popoverEventMonitor;

    BOOL cachedHoverModeEnabled;
}

- (int)modifierFlags;
- (int)resizeModifierFlags;
- (int)moveMouseButton;
- (int)resizeMouseButton;

- (IBAction)modifierToggle:(id)sender;
- (IBAction)resizeModifierToggle:(id)sender;
- (IBAction)resetToDefaults:(id)sender;
- (IBAction)toggleDisabled:(id)sender;
- (IBAction)toggleBringWindowToFront:(id)sender;
- (IBAction)toggleResizeOnly:(id)sender;
- (IBAction)setMoveMouseButton:(id)sender;
- (IBAction)setResizeMouseButton:(id)sender;
- (IBAction)toggleHoverMode:(id)sender;

@property (nonatomic) BOOL sessionActive;
@property float moveFilterInterval;
@property float resizeFilterInterval;

@end
