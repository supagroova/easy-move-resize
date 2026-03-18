#import <Cocoa/Cocoa.h>

@class Preferences;

@interface EMRPopoverViewController : NSViewController

- (instancetype)initWithPreferences:(Preferences *)preferences;

// Refresh all controls from current preference values
- (void)syncControlStatesFromPreferences;

// Show/hide conflict warning based on preferences state
- (void)updateConflictWarning;

@end
