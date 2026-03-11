#import "EMRPopoverViewController.h"
#import "EMRPreferences.h"

@implementation EMRPopoverViewController {
    EMRPreferences *_preferences;

    // Move modifier checkboxes
    NSButton *_moveFnCheckbox;
    NSButton *_moveCtrlCheckbox;
    NSButton *_moveAltCheckbox;
    NSButton *_moveShiftCheckbox;
    NSButton *_moveCmdCheckbox;

    // Resize modifier checkboxes
    NSButton *_resizeFnCheckbox;
    NSButton *_resizeCtrlCheckbox;
    NSButton *_resizeAltCheckbox;
    NSButton *_resizeShiftCheckbox;
    NSButton *_resizeCmdCheckbox;

    // Mouse button popups
    NSPopUpButton *_moveMouseButtonPopup;
    NSPopUpButton *_resizeMouseButtonPopup;

    // Boolean toggle checkboxes
    NSButton *_hoverModeCheckbox;
    NSButton *_bringToFrontCheckbox;
    NSButton *_resizeOnlyCheckbox;

    // Conflict warning
    NSTextField *_conflictWarningLabel;
    NSView *_conflictSeparator;

    // Action buttons
    NSButton *_resetButton;
    NSButton *_quitButton;
}

- (instancetype)initWithPreferences:(EMRPreferences *)preferences {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _preferences = preferences;
    }
    return self;
}

#pragma mark - View construction

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 500)];

    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 8;
    stack.edgeInsets = NSEdgeInsetsMake(16, 16, 16, 16);
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [container addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    // Title
    NSTextField *title = [self createLabel:@"Zooom3" bold:YES];
    [stack addArrangedSubview:title];
    [stack addArrangedSubview:[self createSeparator]];

    // Movement shortcut section
    NSTextField *moveLabel = [self createLabel:@"Movement shortcut:" bold:NO];
    [stack addArrangedSubview:moveLabel];

    NSStackView *moveModifiers = [self createMoveModifierRow];
    [stack addArrangedSubview:moveModifiers];

    NSPopUpButton *movePopup = nil;
    NSStackView *moveMouseRow = [self createMouseButtonRow:@"Mouse button:" identifier:@"moveMouseButton" popup:&movePopup];
    _moveMouseButtonPopup = movePopup;
    [stack addArrangedSubview:moveMouseRow];

    [stack addArrangedSubview:[self createSeparator]];

    // Resize shortcut section
    NSTextField *resizeLabel = [self createLabel:@"Resize shortcut:" bold:NO];
    [stack addArrangedSubview:resizeLabel];

    NSStackView *resizeModifiers = [self createResizeModifierRow];
    [stack addArrangedSubview:resizeModifiers];

    NSPopUpButton *resizePopup = nil;
    NSStackView *resizeMouseRow = [self createMouseButtonRow:@"Mouse button:" identifier:@"resizeMouseButton" popup:&resizePopup];
    _resizeMouseButtonPopup = resizePopup;
    [stack addArrangedSubview:resizeMouseRow];

    [stack addArrangedSubview:[self createSeparator]];

    // Conflict warning
    _conflictWarningLabel = [self createLabel:@"⚠️ Shortcuts are conflicting" bold:NO];
    _conflictWarningLabel.textColor = [NSColor systemRedColor];
    _conflictWarningLabel.hidden = YES;
    [stack addArrangedSubview:_conflictWarningLabel];

    _conflictSeparator = [self createSeparator];
    _conflictSeparator.hidden = YES;
    [stack addArrangedSubview:_conflictSeparator];

    // Boolean toggles
    _hoverModeCheckbox = [self createCheckbox:@"Hover to Move/Resize (no click)" identifier:@"hoverMode"];
    [stack addArrangedSubview:_hoverModeCheckbox];

    _bringToFrontCheckbox = [self createCheckbox:@"Bring window to front" identifier:@"bringToFront"];
    [stack addArrangedSubview:_bringToFrontCheckbox];

    _resizeOnlyCheckbox = [self createCheckbox:@"Resize only" identifier:@"resizeOnly"];
    [stack addArrangedSubview:_resizeOnlyCheckbox];

    [stack addArrangedSubview:[self createSeparator]];

    // Reset and Quit buttons on same row
    _resetButton = [NSButton buttonWithTitle:@"Reset to Defaults" target:nil action:nil];
    _resetButton.identifier = @"resetToDefaults";

    _quitButton = [NSButton buttonWithTitle:@"Quit" target:nil action:nil];
    _quitButton.identifier = @"quit";

    NSStackView *buttonRow = [NSStackView stackViewWithViews:@[_resetButton, _quitButton]];
    buttonRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonRow.spacing = 8;
    [stack addArrangedSubview:buttonRow];

    self.view = container;
}

#pragma mark - UI factory helpers

- (NSTextField *)createLabel:(NSString *)text bold:(BOOL)bold {
    NSTextField *label = [NSTextField labelWithString:text];
    label.editable = NO;
    label.selectable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    if (bold) {
        label.font = [NSFont boldSystemFontOfSize:14];
    }
    return label;
}

- (NSButton *)createCheckbox:(NSString *)title identifier:(NSString *)identifier {
    NSButton *checkbox = [NSButton checkboxWithTitle:title target:nil action:nil];
    checkbox.identifier = identifier;
    return checkbox;
}

- (NSButton *)createModifierCheckbox:(NSString *)title identifier:(NSString *)identifier {
    NSButton *checkbox = [NSButton checkboxWithTitle:title target:nil action:nil];
    checkbox.identifier = identifier;
    return checkbox;
}

- (NSView *)createSeparator {
    NSBox *sep = [[NSBox alloc] init];
    sep.boxType = NSBoxSeparator;
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [sep.widthAnchor constraintEqualToConstant:288].active = YES;
    return sep;
}

- (NSStackView *)createMoveModifierRow {
    _moveFnCheckbox = [self createModifierCheckbox:@"fn" identifier:@"move.FN"];
    _moveCtrlCheckbox = [self createModifierCheckbox:@"\u2303" identifier:@"move.CTRL"];
    _moveAltCheckbox = [self createModifierCheckbox:@"\u2325" identifier:@"move.ALT"];
    _moveShiftCheckbox = [self createModifierCheckbox:@"\u21E7" identifier:@"move.SHIFT"];
    _moveCmdCheckbox = [self createModifierCheckbox:@"\u2318" identifier:@"move.CMD"];

    NSStackView *row = [NSStackView stackViewWithViews:@[
        _moveFnCheckbox, _moveCtrlCheckbox, _moveAltCheckbox, _moveShiftCheckbox, _moveCmdCheckbox
    ]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.spacing = 8;
    return row;
}

- (NSStackView *)createResizeModifierRow {
    _resizeFnCheckbox = [self createModifierCheckbox:@"fn" identifier:@"resize.FN"];
    _resizeCtrlCheckbox = [self createModifierCheckbox:@"\u2303" identifier:@"resize.CTRL"];
    _resizeAltCheckbox = [self createModifierCheckbox:@"\u2325" identifier:@"resize.ALT"];
    _resizeShiftCheckbox = [self createModifierCheckbox:@"\u21E7" identifier:@"resize.SHIFT"];
    _resizeCmdCheckbox = [self createModifierCheckbox:@"\u2318" identifier:@"resize.CMD"];

    NSStackView *row = [NSStackView stackViewWithViews:@[
        _resizeFnCheckbox, _resizeCtrlCheckbox, _resizeAltCheckbox, _resizeShiftCheckbox, _resizeCmdCheckbox
    ]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.spacing = 8;
    return row;
}

- (NSStackView *)createMouseButtonRow:(NSString *)labelText identifier:(NSString *)identifier popup:(NSPopUpButton **)outPopup {
    NSTextField *label = [self createLabel:labelText bold:NO];

    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    popup.identifier = identifier;

    NSMenuItem *leftItem = [[NSMenuItem alloc] initWithTitle:@"Left" action:nil keyEquivalent:@""];
    leftItem.tag = EMRMouseButtonLeft;
    NSMenuItem *rightItem = [[NSMenuItem alloc] initWithTitle:@"Right" action:nil keyEquivalent:@""];
    rightItem.tag = EMRMouseButtonRight;
    NSMenuItem *middleItem = [[NSMenuItem alloc] initWithTitle:@"Middle" action:nil keyEquivalent:@""];
    middleItem.tag = EMRMouseButtonMiddle;

    [popup.menu addItem:leftItem];
    [popup.menu addItem:rightItem];
    [popup.menu addItem:middleItem];

    *outPopup = popup;

    NSStackView *row = [NSStackView stackViewWithViews:@[label, popup]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.spacing = 8;
    return row;
}

#pragma mark - Sync controls from preferences

- (void)syncControlStatesFromPreferences {
    // Ensure view is loaded so ivars are set
    (void)[self view];

    // Move modifiers
    NSSet *moveFlags = [_preferences getFlagStringSet];
    _moveFnCheckbox.state = [moveFlags containsObject:FN_KEY] ? NSControlStateValueOn : NSControlStateValueOff;
    _moveCtrlCheckbox.state = [moveFlags containsObject:CTRL_KEY] ? NSControlStateValueOn : NSControlStateValueOff;
    _moveAltCheckbox.state = [moveFlags containsObject:ALT_KEY] ? NSControlStateValueOn : NSControlStateValueOff;
    _moveShiftCheckbox.state = [moveFlags containsObject:SHIFT_KEY] ? NSControlStateValueOn : NSControlStateValueOff;
    _moveCmdCheckbox.state = [moveFlags containsObject:CMD_KEY] ? NSControlStateValueOn : NSControlStateValueOff;

    // Resize modifiers
    NSSet *resizeFlags = [_preferences getResizeFlagStringSet];
    _resizeFnCheckbox.state = [resizeFlags containsObject:FN_KEY] ? NSControlStateValueOn : NSControlStateValueOff;
    _resizeCtrlCheckbox.state = [resizeFlags containsObject:CTRL_KEY] ? NSControlStateValueOn : NSControlStateValueOff;
    _resizeAltCheckbox.state = [resizeFlags containsObject:ALT_KEY] ? NSControlStateValueOn : NSControlStateValueOff;
    _resizeShiftCheckbox.state = [resizeFlags containsObject:SHIFT_KEY] ? NSControlStateValueOn : NSControlStateValueOff;
    _resizeCmdCheckbox.state = [resizeFlags containsObject:CMD_KEY] ? NSControlStateValueOn : NSControlStateValueOff;

    // Mouse buttons
    [_moveMouseButtonPopup selectItemWithTag:[_preferences moveMouseButton]];
    [_resizeMouseButtonPopup selectItemWithTag:[_preferences resizeMouseButton]];

    // Boolean toggles
    BOOL hoverOn = _preferences.hoverModeEnabled;
    _hoverModeCheckbox.state = hoverOn ? NSControlStateValueOn : NSControlStateValueOff;
    _bringToFrontCheckbox.state = _preferences.shouldBringWindowToFront ? NSControlStateValueOn : NSControlStateValueOff;
    _resizeOnlyCheckbox.state = _preferences.resizeOnly ? NSControlStateValueOn : NSControlStateValueOff;

    // Mouse button popups are irrelevant in hover mode
    _moveMouseButtonPopup.enabled = !hoverOn;
    _resizeMouseButtonPopup.enabled = !hoverOn;

    [self updateConflictWarning];
}

#pragma mark - Conflict warning

- (void)updateConflictWarning {
    (void)[self view];
    BOOL hasConflict = [_preferences hasConflictingConfig];
    _conflictWarningLabel.hidden = !hasConflict;
    _conflictSeparator.hidden = !hasConflict;
}

@end
