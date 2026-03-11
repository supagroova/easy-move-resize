#import <XCTest/XCTest.h>
#import "EMRPreferences.h"
#import "EMRPopoverViewController.h"

@interface EMRPopoverViewControllerTest : XCTestCase

@end

@implementation EMRPopoverViewControllerTest {
    NSString *testDefaultsName;
    NSUserDefaults *testDefaults;
    EMRPreferences *preferences;
    EMRPopoverViewController *viewController;
}

- (void)setUp {
    [super setUp];
    NSString *uuid = [[NSUUID UUID] UUIDString];
    testDefaultsName = [@"com.supagroova.zooom3.test.popover." stringByAppendingString:uuid];
    testDefaults = [[NSUserDefaults alloc] initWithSuiteName:testDefaultsName];
    preferences = [[EMRPreferences alloc] initWithUserDefaults:testDefaults];
    viewController = [[EMRPopoverViewController alloc] initWithPreferences:preferences];
}

- (void)tearDown {
    viewController = nil;
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:testDefaultsName];
    [super tearDown];
}

#pragma mark - Helper: find checkbox by identifier in a view hierarchy

- (NSButton *)findCheckboxWithIdentifier:(NSString *)identifier inView:(NSView *)view {
    if ([view isKindOfClass:[NSButton class]]) {
        NSButton *btn = (NSButton *)view;
        if ([btn.identifier isEqualToString:identifier]) {
            return btn;
        }
    }
    for (NSView *subview in view.subviews) {
        NSButton *found = [self findCheckboxWithIdentifier:identifier inView:subview];
        if (found) return found;
    }
    return nil;
}

- (NSPopUpButton *)findPopUpButtonWithIdentifier:(NSString *)identifier inView:(NSView *)view {
    if ([view isKindOfClass:[NSPopUpButton class]]) {
        NSPopUpButton *btn = (NSPopUpButton *)view;
        if ([btn.identifier isEqualToString:identifier]) {
            return btn;
        }
    }
    for (NSView *subview in view.subviews) {
        NSPopUpButton *found = [self findPopUpButtonWithIdentifier:identifier inView:subview];
        if (found) return found;
    }
    return nil;
}

- (NSTextField *)findLabelContaining:(NSString *)text inView:(NSView *)view {
    if ([view isKindOfClass:[NSTextField class]]) {
        NSTextField *label = (NSTextField *)view;
        if ([label.stringValue containsString:text]) {
            return label;
        }
    }
    for (NSView *subview in view.subviews) {
        NSTextField *found = [self findLabelContaining:text inView:subview];
        if (found) return found;
    }
    return nil;
}

#pragma mark - Initialization

- (void)testInitCreatesValidViewController {
    XCTAssertNotNil(viewController);
    // Trigger loadView
    NSView *view = viewController.view;
    XCTAssertNotNil(view);
}

#pragma mark - View hierarchy: modifier checkboxes exist

- (void)testViewContainsMoveModifierCheckboxes {
    NSView *view = viewController.view;
    NSArray *moveKeys = @[@"move.FN", @"move.CTRL", @"move.ALT", @"move.SHIFT", @"move.CMD"];
    for (NSString *key in moveKeys) {
        NSButton *checkbox = [self findCheckboxWithIdentifier:key inView:view];
        XCTAssertNotNil(checkbox, @"Missing move modifier checkbox: %@", key);
    }
}

- (void)testViewContainsResizeModifierCheckboxes {
    NSView *view = viewController.view;
    NSArray *resizeKeys = @[@"resize.FN", @"resize.CTRL", @"resize.ALT", @"resize.SHIFT", @"resize.CMD"];
    for (NSString *key in resizeKeys) {
        NSButton *checkbox = [self findCheckboxWithIdentifier:key inView:view];
        XCTAssertNotNil(checkbox, @"Missing resize modifier checkbox: %@", key);
    }
}

#pragma mark - View hierarchy: mouse button popups exist

- (void)testViewContainsMoveMouseButtonPopup {
    NSView *view = viewController.view;
    NSPopUpButton *popup = [self findPopUpButtonWithIdentifier:@"moveMouseButton" inView:view];
    XCTAssertNotNil(popup, @"Missing move mouse button popup");
    XCTAssertEqual(popup.numberOfItems, 3, @"Should have Left, Right, Middle");
}

- (void)testViewContainsResizeMouseButtonPopup {
    NSView *view = viewController.view;
    NSPopUpButton *popup = [self findPopUpButtonWithIdentifier:@"resizeMouseButton" inView:view];
    XCTAssertNotNil(popup, @"Missing resize mouse button popup");
    XCTAssertEqual(popup.numberOfItems, 3, @"Should have Left, Right, Middle");
}

#pragma mark - View hierarchy: boolean toggle checkboxes exist

- (void)testViewContainsHoverModeCheckbox {
    NSView *view = viewController.view;
    NSButton *checkbox = [self findCheckboxWithIdentifier:@"hoverMode" inView:view];
    XCTAssertNotNil(checkbox, @"Missing hover mode checkbox");
}

- (void)testViewContainsBringToFrontCheckbox {
    NSView *view = viewController.view;
    NSButton *checkbox = [self findCheckboxWithIdentifier:@"bringToFront" inView:view];
    XCTAssertNotNil(checkbox, @"Missing bring to front checkbox");
}

- (void)testViewContainsResizeOnlyCheckbox {
    NSView *view = viewController.view;
    NSButton *checkbox = [self findCheckboxWithIdentifier:@"resizeOnly" inView:view];
    XCTAssertNotNil(checkbox, @"Missing resize only checkbox");
}

#pragma mark - View hierarchy: labels exist

- (void)testViewContainsMovementShortcutLabel {
    NSView *view = viewController.view;
    NSTextField *label = [self findLabelContaining:@"Movement shortcut" inView:view];
    XCTAssertNotNil(label, @"Missing 'Movement shortcut' label");
}

- (void)testViewContainsResizeShortcutLabel {
    NSView *view = viewController.view;
    NSTextField *label = [self findLabelContaining:@"Resize shortcut" inView:view];
    XCTAssertNotNil(label, @"Missing 'Resize shortcut' label");
}

#pragma mark - View hierarchy: action buttons exist

- (void)testViewContainsResetButton {
    NSView *view = viewController.view;
    NSTextField *label = [self findLabelContaining:@"Reset" inView:view];
    // Reset could be a button, so also check for a button with that title
    NSButton *btn = [self findCheckboxWithIdentifier:@"resetToDefaults" inView:view];
    BOOL found = (label != nil || btn != nil);
    XCTAssertTrue(found, @"Missing 'Reset to Defaults' button");
}

- (void)testViewContainsQuitButton {
    NSView *view = viewController.view;
    NSButton *btn = [self findCheckboxWithIdentifier:@"quit" inView:view];
    XCTAssertNotNil(btn, @"Missing 'Quit' button");
}

- (void)testResetAndQuitAreOnSameRow {
    NSView *view = viewController.view;
    NSButton *resetBtn = [self findCheckboxWithIdentifier:@"resetToDefaults" inView:view];
    NSButton *quitBtn = [self findCheckboxWithIdentifier:@"quit" inView:view];
    XCTAssertNotNil(resetBtn);
    XCTAssertNotNil(quitBtn);
    // Both should share the same NSStackView parent (the row)
    XCTAssertEqual(resetBtn.superview, quitBtn.superview, @"Reset and Quit should be in the same row");
}

- (void)testNoDisabledAppsControls {
    NSView *view = viewController.view;
    NSButton *disableBtn = [self findCheckboxWithIdentifier:@"disableLastApp" inView:view];
    NSPopUpButton *enablePopup = [self findPopUpButtonWithIdentifier:@"enableDisabledApp" inView:view];
    XCTAssertNil(disableBtn, @"Disabled apps button should not exist");
    XCTAssertNil(enablePopup, @"Re-enable popup should not exist");
}

#pragma mark - Hover mode disables mouse button popups

- (void)testMouseButtonPopupsEnabledWhenHoverModeOff {
    [preferences setToDefaults];
    [preferences setHoverModeEnabled:NO];
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSPopUpButton *movePopup = [self findPopUpButtonWithIdentifier:@"moveMouseButton" inView:view];
    NSPopUpButton *resizePopup = [self findPopUpButtonWithIdentifier:@"resizeMouseButton" inView:view];

    XCTAssertTrue(movePopup.isEnabled, @"Move mouse button popup should be enabled when hover mode is off");
    XCTAssertTrue(resizePopup.isEnabled, @"Resize mouse button popup should be enabled when hover mode is off");
}

- (void)testMouseButtonPopupsDisabledWhenHoverModeOn {
    [preferences setToDefaults];
    [preferences setHoverModeEnabled:YES];
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSPopUpButton *movePopup = [self findPopUpButtonWithIdentifier:@"moveMouseButton" inView:view];
    NSPopUpButton *resizePopup = [self findPopUpButtonWithIdentifier:@"resizeMouseButton" inView:view];

    XCTAssertFalse(movePopup.isEnabled, @"Move mouse button popup should be disabled when hover mode is on");
    XCTAssertFalse(resizePopup.isEnabled, @"Resize mouse button popup should be disabled when hover mode is on");
}

#pragma mark - syncControlStatesFromPreferences: move modifiers

- (void)testSyncSetsDefaultMoveModifiers {
    // Defaults: CMD + CTRL enabled
    [preferences setToDefaults];
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSButton *cmdBtn = [self findCheckboxWithIdentifier:@"move.CMD" inView:view];
    NSButton *ctrlBtn = [self findCheckboxWithIdentifier:@"move.CTRL" inView:view];
    NSButton *altBtn = [self findCheckboxWithIdentifier:@"move.ALT" inView:view];
    NSButton *shiftBtn = [self findCheckboxWithIdentifier:@"move.SHIFT" inView:view];
    NSButton *fnBtn = [self findCheckboxWithIdentifier:@"move.FN" inView:view];

    XCTAssertEqual(cmdBtn.state, NSControlStateValueOn, @"CMD should be on by default");
    XCTAssertEqual(ctrlBtn.state, NSControlStateValueOn, @"CTRL should be on by default");
    XCTAssertEqual(altBtn.state, NSControlStateValueOff, @"ALT should be off by default");
    XCTAssertEqual(shiftBtn.state, NSControlStateValueOff, @"SHIFT should be off by default");
    XCTAssertEqual(fnBtn.state, NSControlStateValueOff, @"FN should be off by default");
}

- (void)testSyncSetsCustomMoveModifiers {
    [preferences setToDefaults];
    [preferences setModifierKey:CMD_KEY enabled:NO];
    [preferences setModifierKey:ALT_KEY enabled:YES];
    [preferences setModifierKey:SHIFT_KEY enabled:YES];

    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSButton *cmdBtn = [self findCheckboxWithIdentifier:@"move.CMD" inView:view];
    NSButton *ctrlBtn = [self findCheckboxWithIdentifier:@"move.CTRL" inView:view];
    NSButton *altBtn = [self findCheckboxWithIdentifier:@"move.ALT" inView:view];
    NSButton *shiftBtn = [self findCheckboxWithIdentifier:@"move.SHIFT" inView:view];

    XCTAssertEqual(cmdBtn.state, NSControlStateValueOff, @"CMD should be off");
    XCTAssertEqual(ctrlBtn.state, NSControlStateValueOn, @"CTRL should still be on");
    XCTAssertEqual(altBtn.state, NSControlStateValueOn, @"ALT should be on");
    XCTAssertEqual(shiftBtn.state, NSControlStateValueOn, @"SHIFT should be on");
}

#pragma mark - syncControlStatesFromPreferences: resize modifiers

- (void)testSyncSetsDefaultResizeModifiers {
    [preferences setToDefaults];
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSButton *cmdBtn = [self findCheckboxWithIdentifier:@"resize.CMD" inView:view];
    NSButton *ctrlBtn = [self findCheckboxWithIdentifier:@"resize.CTRL" inView:view];
    NSButton *altBtn = [self findCheckboxWithIdentifier:@"resize.ALT" inView:view];

    XCTAssertEqual(cmdBtn.state, NSControlStateValueOn, @"CMD should be on by default");
    XCTAssertEqual(ctrlBtn.state, NSControlStateValueOn, @"CTRL should be on by default");
    XCTAssertEqual(altBtn.state, NSControlStateValueOff, @"ALT should be off by default");
}

- (void)testSyncSetsCustomResizeModifiers {
    [preferences setToDefaults];
    [preferences setResizeModifierKey:CMD_KEY enabled:NO];
    [preferences setResizeModifierKey:FN_KEY enabled:YES];

    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSButton *cmdBtn = [self findCheckboxWithIdentifier:@"resize.CMD" inView:view];
    NSButton *fnBtn = [self findCheckboxWithIdentifier:@"resize.FN" inView:view];

    XCTAssertEqual(cmdBtn.state, NSControlStateValueOff, @"CMD should be off");
    XCTAssertEqual(fnBtn.state, NSControlStateValueOn, @"FN should be on");
}

#pragma mark - syncControlStatesFromPreferences: mouse buttons

- (void)testSyncSetsDefaultMouseButtons {
    [preferences setToDefaults];
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSPopUpButton *movePopup = [self findPopUpButtonWithIdentifier:@"moveMouseButton" inView:view];
    NSPopUpButton *resizePopup = [self findPopUpButtonWithIdentifier:@"resizeMouseButton" inView:view];

    XCTAssertEqual([[movePopup selectedItem] tag], EMRMouseButtonLeft, @"Move default is Left");
    XCTAssertEqual([[resizePopup selectedItem] tag], EMRMouseButtonRight, @"Resize default is Right");
}

- (void)testSyncSetsCustomMouseButtons {
    [preferences setMoveMouseButton:EMRMouseButtonMiddle];
    [preferences setResizeMouseButton:EMRMouseButtonLeft];
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSPopUpButton *movePopup = [self findPopUpButtonWithIdentifier:@"moveMouseButton" inView:view];
    NSPopUpButton *resizePopup = [self findPopUpButtonWithIdentifier:@"resizeMouseButton" inView:view];

    XCTAssertEqual([[movePopup selectedItem] tag], EMRMouseButtonMiddle, @"Move should be Middle");
    XCTAssertEqual([[resizePopup selectedItem] tag], EMRMouseButtonLeft, @"Resize should be Left");
}

#pragma mark - syncControlStatesFromPreferences: boolean toggles

- (void)testSyncSetsBooleanToggles {
    [preferences setToDefaults];
    [preferences setShouldBringWindowToFront:YES];
    [preferences setResizeOnly:YES];
    [preferences setHoverModeEnabled:YES];

    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSButton *bringFront = [self findCheckboxWithIdentifier:@"bringToFront" inView:view];
    NSButton *resizeOnly = [self findCheckboxWithIdentifier:@"resizeOnly" inView:view];
    NSButton *hoverMode = [self findCheckboxWithIdentifier:@"hoverMode" inView:view];

    XCTAssertEqual(bringFront.state, NSControlStateValueOn, @"Bring to front should be on");
    XCTAssertEqual(resizeOnly.state, NSControlStateValueOn, @"Resize only should be on");
    XCTAssertEqual(hoverMode.state, NSControlStateValueOn, @"Hover mode should be on");
}

- (void)testSyncSetsBooleansOff {
    [preferences setToDefaults];
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSButton *bringFront = [self findCheckboxWithIdentifier:@"bringToFront" inView:view];
    NSButton *resizeOnly = [self findCheckboxWithIdentifier:@"resizeOnly" inView:view];
    NSButton *hoverMode = [self findCheckboxWithIdentifier:@"hoverMode" inView:view];

    XCTAssertEqual(bringFront.state, NSControlStateValueOff, @"Bring to front should be off");
    XCTAssertEqual(resizeOnly.state, NSControlStateValueOff, @"Resize only should be off");
    XCTAssertEqual(hoverMode.state, NSControlStateValueOff, @"Hover mode should be off");
}

#pragma mark - Conflict warning

- (void)testConflictWarningHiddenWhenNoConflict {
    [preferences setToDefaults]; // same modifiers but different mouse buttons
    [viewController syncControlStatesFromPreferences];
    [viewController updateConflictWarning];

    NSView *view = viewController.view;
    NSTextField *warning = [self findLabelContaining:@"identical" inView:view];
    // Warning should either not exist or be hidden when there's no conflict
    if (warning) {
        XCTAssertTrue(warning.isHidden, @"Conflict warning should be hidden");
    }
}

- (void)testConflictWarningVisibleWhenConflict {
    [preferences setToDefaults];
    // Make move and resize have identical config: same button + same modifiers
    [preferences setMoveMouseButton:EMRMouseButtonLeft];
    [preferences setResizeMouseButton:EMRMouseButtonLeft];
    XCTAssertTrue([preferences hasConflictingConfig], @"Should have conflict");

    [viewController syncControlStatesFromPreferences];
    [viewController updateConflictWarning];

    NSView *view = viewController.view;
    NSTextField *warning = [self findLabelContaining:@"conflict" inView:view];
    XCTAssertNotNil(warning, @"Conflict warning label should exist");
    XCTAssertFalse(warning.isHidden, @"Conflict warning should be visible");
}

- (NSView *)findSeparatorAfterWarningInView:(NSView *)rootView {
    NSTextField *warning = [self findLabelContaining:@"conflicting" inView:rootView];
    if (!warning) return nil;
    NSStackView *stack = (NSStackView *)warning.superview;
    if (![stack isKindOfClass:[NSStackView class]]) return nil;
    NSArray *arranged = stack.arrangedSubviews;
    NSUInteger idx = [arranged indexOfObject:warning];
    if (idx == NSNotFound || idx + 1 >= arranged.count) return nil;
    NSView *next = arranged[idx + 1];
    if ([next isKindOfClass:[NSBox class]]) return next;
    return nil;
}

- (void)testConflictSeparatorHiddenWhenWarningHidden {
    [preferences setToDefaults]; // no conflict with defaults
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSTextField *warning = [self findLabelContaining:@"conflict" inView:view];
    XCTAssertNotNil(warning);
    XCTAssertTrue(warning.isHidden, @"Warning should be hidden when no conflict");

    NSView *separator = [self findSeparatorAfterWarningInView:view];
    XCTAssertNotNil(separator, @"Separator after warning should exist");
    XCTAssertTrue(separator.isHidden, @"Separator after warning should be hidden when warning is hidden");
}

- (void)testConflictSeparatorVisibleWhenWarningVisible {
    [preferences setToDefaults];
    [preferences setMoveMouseButton:EMRMouseButtonLeft];
    [preferences setResizeMouseButton:EMRMouseButtonLeft];
    [viewController syncControlStatesFromPreferences];

    NSView *view = viewController.view;
    NSTextField *warning = [self findLabelContaining:@"conflict" inView:view];
    XCTAssertNotNil(warning);
    XCTAssertFalse(warning.isHidden, @"Warning should be visible when conflict");

    NSView *separator = [self findSeparatorAfterWarningInView:view];
    XCTAssertNotNil(separator, @"Separator after warning should exist");
    XCTAssertFalse(separator.isHidden, @"Separator after warning should be visible when warning is visible");
}

- (void)testConflictWarningVisibleInHoverModeWithSameModifiers {
    [preferences setToDefaults];
    [preferences setHoverModeEnabled:YES];
    // Same modifiers (defaults: CMD+CTRL) but different mouse buttons (Left vs Right)
    // In hover mode, mouse buttons are irrelevant — warning should appear
    [viewController syncControlStatesFromPreferences];
    [viewController updateConflictWarning];

    NSView *view = viewController.view;
    NSTextField *warning = [self findLabelContaining:@"conflict" inView:view];
    XCTAssertNotNil(warning, @"Conflict warning label should exist");
    XCTAssertFalse(warning.isHidden, @"Conflict warning should be visible in hover mode with same modifiers");
}

@end
