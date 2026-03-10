#import <Cocoa/Cocoa.h>

@class EMRPreferences;

@interface EMRPopoverViewController : NSViewController

- (instancetype)initWithPreferences:(EMRPreferences *)preferences;

// Refresh all controls from current preference values
- (void)syncControlStatesFromPreferences;

// Show/hide conflict warning based on preferences state
- (void)updateConflictWarning;

@end
