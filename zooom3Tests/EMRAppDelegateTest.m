#import <XCTest/XCTest.h>
#import "EMRAppDelegate.h"
#import "ResizeTypes.h"
#import "Zooom3-Swift.h"

// The callback is a C function with external linkage in EMRAppDelegate.m
extern CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon);

// Expose refreshCachedPreferences and private ivars for testing via category
@interface EMRAppDelegate (Testing)
- (void)refreshCachedPreferences;
- (BOOL)resizeOnly;
- (void)ensurePopoverCreated;
- (void)installPopoverEventMonitor;
- (void)removePopoverEventMonitor;
- (void)handlePermissionRevoked;
- (void)showAccessibilityOnboarding;
- (void)togglePopover:(id)sender;
@end

@interface EMRAppDelegateTest : XCTestCase

@end

@implementation EMRAppDelegateTest {
    EMRAppDelegate *delegate;
}

- (void)setUp {
    [super setUp];
    delegate = [[EMRAppDelegate alloc] init];
    // Reset MoveResize singleton state
    MoveResize *mr = [MoveResize instance];
    [mr setTracking:0];
    [mr setIsResizing:NO];
    [mr setIsHoverActive:NO];
    [mr setWindow:nil];
}

#pragma mark - Helper: set cached ivars directly via KVC

- (void)setCachedMoveModifiers:(int)flags {
    [delegate setValue:@(flags) forKey:@"keyModifierFlags"];
}
- (void)setCachedResizeModifiers:(int)flags {
    [delegate setValue:@(flags) forKey:@"resizeKeyModifierFlags"];
}
- (void)setCachedMoveButton:(int)btn {
    [delegate setValue:@(btn) forKey:@"cachedMoveMouseButton"];
}
- (void)setCachedResizeButton:(int)btn {
    [delegate setValue:@(btn) forKey:@"cachedResizeMouseButton"];
}
- (void)setCachedHasConflict:(BOOL)conflict {
    [delegate setValue:@(conflict) forKey:@"cachedHasConflict"];
}
- (void)setCachedHoverModeEnabled:(BOOL)enabled {
    [delegate setValue:@(enabled) forKey:@"cachedHoverModeEnabled"];
}

#pragma mark - Helper: create a CGEvent with specific type and modifier flags

- (CGEventRef)createMouseEvent:(CGEventType)type flags:(CGEventFlags)flags {
    // Create a mouse event at position (100, 100)
    CGPoint location = CGPointMake(100, 100);

    // Map CGEventType to CGMouseButton
    CGMouseButton button = kCGMouseButtonLeft;
    if (type == kCGEventRightMouseDown || type == kCGEventRightMouseDragged || type == kCGEventRightMouseUp) {
        button = kCGMouseButtonRight;
    } else if (type == kCGEventOtherMouseDown || type == kCGEventOtherMouseDragged || type == kCGEventOtherMouseUp) {
        button = kCGMouseButtonCenter;
    }

    CGEventRef event = CGEventCreateMouseEvent(NULL, type, location, button);
    if (event && flags != 0) {
        CGEventSetFlags(event, flags);
    }
    return event;
}

- (CGEventRef)createFlagsChangedEvent:(CGEventFlags)flags {
    // kCGEventFlagsChanged carries current mouse location
    CGEventRef event = CGEventCreate(NULL);
    CGEventSetType(event, kCGEventFlagsChanged);
    CGEventSetFlags(event, flags);
    CGEventSetLocation(event, CGPointMake(100, 100));
    return event;
}

- (CGEventRef)createMouseMovedEvent:(CGEventFlags)flags deltaX:(int64_t)dx deltaY:(int64_t)dy {
    CGEventRef event = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, CGPointMake(200, 200), kCGMouseButtonLeft);
    if (event) {
        CGEventSetFlags(event, flags);
        CGEventSetIntegerValueField(event, kCGMouseEventDeltaX, dx);
        CGEventSetIntegerValueField(event, kCGMouseEventDeltaY, dy);
    }
    return event;
}

#pragma mark - refreshCachedPreferences

- (void)testRefreshCachedPreferencesUpdatesAccessors {
    // The delegate uses the "userPrefs" suite which may have leftover state.
    // Reset to known defaults first, then verify cache sync.
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
    [prefs setObject:@"CTRL,CMD" forKey:@"ModifierFlags"];
    [prefs setObject:@"CTRL,CMD" forKey:@"ResizeModifierFlags"];
    [prefs setInteger:0 /* MouseButton.left */ forKey:@"MoveMouseButton"];
    [prefs setInteger:1 /* MouseButton.right */ forKey:@"ResizeMouseButton"];

    [delegate refreshCachedPreferences];

    int expectedFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    XCTAssertEqual([delegate modifierFlags], expectedFlags, "Cached move modifiers should match preferences");
    XCTAssertEqual([delegate resizeModifierFlags], expectedFlags, "Cached resize modifiers should match preferences");
    XCTAssertEqual([delegate moveMouseButton], 0 /* MouseButton.left */, "Cached move button should match preferences");
    XCTAssertEqual([delegate resizeMouseButton], 1 /* MouseButton.right */, "Cached resize button should match preferences");

    // Now change preferences and refresh — verify update
    [prefs setObject:@"CMD,ALT" forKey:@"ResizeModifierFlags"];
    [prefs setInteger:2 /* MouseButton.middle */ forKey:@"ResizeMouseButton"];

    [delegate refreshCachedPreferences];

    int expectedResizeFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate;
    XCTAssertEqual([delegate resizeModifierFlags], expectedResizeFlags, "Cached resize modifiers should update after preference change");
    XCTAssertEqual([delegate resizeMouseButton], 2 /* MouseButton.middle */, "Cached resize button should update after preference change");

    // Restore defaults to not pollute other tests
    [prefs setObject:@"CTRL,CMD" forKey:@"ModifierFlags"];
    [prefs setObject:@"CTRL,CMD" forKey:@"ResizeModifierFlags"];
    [prefs setInteger:0 /* MouseButton.left */ forKey:@"MoveMouseButton"];
    [prefs setInteger:1 /* MouseButton.right */ forKey:@"ResizeMouseButton"];
}

#pragma mark - Accessor methods return cached ivars

- (void)testModifierFlagsReturnsCachedValue {
    [self setCachedMoveModifiers:42];
    XCTAssertEqual([delegate modifierFlags], 42);
}

- (void)testResizeModifierFlagsReturnsCachedValue {
    [self setCachedResizeModifiers:99];
    XCTAssertEqual([delegate resizeModifierFlags], 99);
}

- (void)testMoveMouseButtonReturnsCachedValue {
    [self setCachedMoveButton:2 /* MouseButton.middle */];
    XCTAssertEqual([delegate moveMouseButton], 2 /* MouseButton.middle */);
}

- (void)testResizeMouseButtonReturnsCachedValue {
    [self setCachedResizeButton:0 /* MouseButton.left */];
    XCTAssertEqual([delegate resizeMouseButton], 0 /* MouseButton.left */);
}

#pragma mark - Callback: session inactive passes through

- (void)testCallbackPassesThroughWhenSessionInactive {
    [delegate setSessionActive:NO];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];

    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown
                                        flags:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through when session is inactive");
    CFRelease(event);
}

#pragma mark - Callback: both modifiers zero → early return

- (void)testCallbackPassesThroughWhenBothModifiersZero {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:0];
    [self setCachedResizeModifiers:0];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through when both modifier sets are zero");
    CFRelease(event);
}

#pragma mark - Callback: wrong modifiers → pass through

- (void)testCallbackPassesThroughWithWrongModifiers {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    // Send left-click with only Shift — matches neither move nor resize
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:kCGEventFlagMaskShift];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through with non-matching modifiers");
    CFRelease(event);
}

#pragma mark - Callback: wrong button → pass through

- (void)testCallbackPassesThroughWithWrongButton {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    // Send middle-click with correct modifiers — neither move (Left) nor resize (Right)
    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseEvent:kCGEventOtherMouseDown flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventOtherMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through when button doesn't match move or resize");
    CFRelease(event);
}

#pragma mark - Callback: extra modifiers → pass through

- (void)testCallbackPassesThroughWithExtraModifiers {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:0 /* MouseButton.left */];

    // Send left-click with Cmd+Ctrl+Alt — has extras for both sets
    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Callback should pass through when extra modifiers are held for both sets");
    CFRelease(event);
}

#pragma mark - Callback: resizeOnly suppresses move

- (void)testCallbackPassesThroughMoveWhenResizeOnly {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    // Set resizeOnly via preferences (the callback reads it via [ourDelegate resizeOnly])
    // The delegate's init creates its own preferences, so we need to use KVC or the accessor
    // Actually, resizeOnly is read from preferences, not cached. Let me check...
    // The callback calls: bool resizeOnly = [ourDelegate resizeOnly];
    // which calls: [preferences resizeOnly] which reads from NSUserDefaults "userPrefs"

    // We can use the delegate's own preferences by writing to the "userPrefs" suite
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
    [prefs setBool:YES forKey:@"ResizeOnly"];

    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Move event should pass through when resizeOnly is ON");

    // Clean up
    [prefs setBool:NO forKey:@"ResizeOnly"];
    CFRelease(event);
}

#pragma mark - Callback: mouse-up clears tracking and isResizing

- (void)testMouseUpClearsTrackingAndIsResizing {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    // Simulate an active tracking session (as if mouse-down already happened)
    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:YES];

    XCTAssertTrue([mr tracking] > 0, "Precondition: tracking should be active");
    XCTAssertTrue([mr isResizing], "Precondition: isResizing should be YES");

    // Send mouse-up (left button) — the button/modifiers don't need to match for up events
    // as long as tracking > 0
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseUp flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseUp, event, (__bridge void *)delegate);

    XCTAssertTrue(result == NULL, "Mouse-up during tracking should be handled (return NULL)");
    XCTAssertEqual([mr tracking], 0, "tracking should be cleared after mouse-up");
    XCTAssertFalse([mr isResizing], "isResizing should be NO after mouse-up");
    CFRelease(event);
}

- (void)testRightMouseUpClearsTrackingAndIsResizing {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:YES];

    CGEventRef event = [self createMouseEvent:kCGEventRightMouseUp flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventRightMouseUp, event, (__bridge void *)delegate);

    XCTAssertTrue(result == NULL, "Right mouse-up during tracking should be handled");
    XCTAssertEqual([mr tracking], 0);
    XCTAssertFalse([mr isResizing]);
    CFRelease(event);
}

#pragma mark - Callback: mouse-up with no active tracking → pass through

- (void)testMouseUpWithNoTrackingPassesThrough {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    MoveResize *mr = [MoveResize instance];
    [mr setTracking:0]; // No active tracking

    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseUp flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseUp, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Mouse-up with no active tracking should pass through");
    CFRelease(event);
}

#pragma mark - Callback: unrecognized event type → pass through

- (void)testCallbackPassesThroughUnrecognizedEventType {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    // Create a scroll wheel event (not handled by the callback)
    CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, 1, 1);
    CGEventRef result = myCGEventCallback(NULL, kCGEventScrollWheel, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "Scroll wheel events should pass through");
    CFRelease(event);
}

// Note: kCGEventTapDisabledByTimeout handling cannot be tested without a real event tap,
// as the callback calls CGEventTapEnable([MoveResize instance].eventTap, true)
// which crashes on a NULL event tap reference.

#pragma mark - Callback: conflict resolution (both match → resize wins)

- (void)testConflictResolutionResizeWins {
    [delegate setSessionActive:YES];
    // Configure: same button (Left) + same modifiers for both operations
    int flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    [self setCachedMoveModifiers:flags];
    [self setCachedResizeModifiers:flags];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:0 /* MouseButton.left */];
    [self setCachedHasConflict:YES];

    // Send mouse-down with matching modifiers.
    // Both move and resize match → conflict resolution should pick resize.
    // The callback enters the resize path (isForResize=YES), which tries to get window size
    // via AX. In test environment with no real window, the AX size query fails and the callback
    // clears tracking+isResizing and returns NULL.
    //
    // Key verification: if move had been chosen instead, the callback would NOT enter the
    // resize size-query path, so tracking would remain active and isResizing would be NO.
    // By checking that tracking is 0 (resize path's AX failure cleanup ran), we confirm
    // the callback chose the resize path, proving conflict resolution chose resize.
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);

    MoveResize *mr = [MoveResize instance];
    // The resize path was entered (AX size query ran and failed, clearing tracking)
    // If move had been chosen, tracking would still be > 0 (move path doesn't query size)
    XCTAssertTrue(result == NULL, "Conflicting event should be consumed (not passed through)");
    XCTAssertEqual([mr tracking], 0, "Resize path AX failure should have cleared tracking, confirming resize was chosen over move");

    [mr setIsResizing:NO];
    CFRelease(event);
}

#pragma mark - Callback: independent modifier matching

- (void)testMoveModifiersMatchResizeModifiersDont {
    [delegate setSessionActive:YES];
    // Move: Cmd+Ctrl on Left, Resize: Cmd+Alt on Left
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:0 /* MouseButton.left */];

    // Send left-click with Cmd+Ctrl — should match move only
    CGEventFlags moveFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:moveFlags];
    myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);

    MoveResize *mr = [MoveResize instance];
    // Move matched, resize didn't → isResizing should be NO
    XCTAssertFalse([mr isResizing], "Move modifiers should match but resize should not — isResizing should be NO");

    [mr setTracking:0];
    [mr setIsResizing:NO];
    CFRelease(event);
}

- (void)testResizeModifiersMatchMoveModifiersDont {
    [delegate setSessionActive:YES];
    // Move: Cmd+Ctrl on Left, Resize: Cmd+Alt on Left
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:0 /* MouseButton.left */];

    // Send left-click with Cmd+Alt — should match resize only.
    // In test env: resize path enters AX size query which fails on NULL window,
    // clearing tracking to 0 and returning NULL. This confirms the resize path was chosen.
    // (If move had been chosen, tracking would remain > 0 since move doesn't query size.)
    CGEventFlags resizeFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDown flags:resizeFlags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDown, event, (__bridge void *)delegate);

    MoveResize *mr = [MoveResize instance];
    XCTAssertTrue(result == NULL, "Resize-matching event should be consumed (not passed through)");
    XCTAssertEqual([mr tracking], 0, "Resize path AX failure clears tracking, confirming resize was chosen");

    [mr setIsResizing:NO];
    CFRelease(event);
}

#pragma mark - Callback: drag during active tracking respects isResizing

- (void)testDragDuringMoveTrackingDoesNotSetIsResizing {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    // Simulate active move tracking
    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:NO];
    [mr setWndPosition:NSMakePoint(100, 100)];

    // Send drag event — during active tracking, the drag handler should fire
    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseDragged flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseDragged, event, (__bridge void *)delegate);

    // Drag during move tracking: isResizing should still be NO
    XCTAssertFalse([mr isResizing], "isResizing should remain NO during move drag");
    // The drag was handled (but AX calls to move window may fail in test — that's OK)
    // If window is nil, the AX call is a no-op but doesn't crash
    XCTAssertTrue(result == NULL, "Drag during active tracking should be handled (return NULL)");

    [mr setTracking:0];
    CFRelease(event);
}

- (void)testDragDuringResizeTrackingKeepsIsResizing {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    // Simulate active resize tracking
    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:YES];
    [mr setWndPosition:NSMakePoint(100, 100)];
    [mr setWndSize:NSMakeSize(400, 300)];
    struct ResizeSection section = { .xResizeDirection = right, .yResizeDirection = bottom };
    [mr setResizeSection:section];

    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate;
    CGEventRef event = [self createMouseEvent:kCGEventRightMouseDragged flags:flags];
    CGEventRef result = myCGEventCallback(NULL, kCGEventRightMouseDragged, event, (__bridge void *)delegate);

    XCTAssertTrue([mr isResizing], "isResizing should remain YES during resize drag");
    XCTAssertTrue(result == NULL, "Drag during active tracking should be handled");

    [mr setTracking:0];
    [mr setIsResizing:NO];
    CFRelease(event);
}

#pragma mark - Callback: different button configurations

- (void)testMiddleClickResizeConfiguration {
    [delegate setSessionActive:YES];
    int flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    [self setCachedMoveModifiers:flags];
    [self setCachedResizeModifiers:flags];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:2 /* MouseButton.middle */]; // Middle-click resize

    // Left-click should match move, not resize
    CGEventRef leftEvent = [self createMouseEvent:kCGEventLeftMouseDown flags:flags];
    myCGEventCallback(NULL, kCGEventLeftMouseDown, leftEvent, (__bridge void *)delegate);

    MoveResize *mr = [MoveResize instance];
    XCTAssertFalse([mr isResizing], "Left-click should match move (not resize) when resize is middle-click");

    [mr setTracking:0];
    [mr setIsResizing:NO];

    // Middle-click should match resize.
    // The resize path enters AX size query which fails in test env, clearing tracking.
    // We confirm the resize path was chosen by checking return value is NULL and tracking == 0.
    CGEventRef middleEvent = [self createMouseEvent:kCGEventOtherMouseDown flags:flags];
    CGEventRef middleResult = myCGEventCallback(NULL, kCGEventOtherMouseDown, middleEvent, (__bridge void *)delegate);

    XCTAssertTrue(middleResult == NULL, "Middle-click resize event should be consumed");
    XCTAssertEqual([mr tracking], 0, "Resize path AX failure clears tracking, confirming middle-click matched resize");

    [mr setIsResizing:NO];
    CFRelease(leftEvent);
    CFRelease(middleEvent);
}

#pragma mark - Hover mode: kCGEventFlagsChanged

- (void)testFlagsChangedPassesThroughWhenHoverDisabled {
    [delegate setSessionActive:YES];
    [self setCachedHoverModeEnabled:NO];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];

    CGEventRef event = [self createFlagsChangedEvent:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    CGEventRef result = myCGEventCallback(NULL, kCGEventFlagsChanged, event, (__bridge void *)delegate);

    XCTAssertEqual(result, event, "Flags changed should pass through when hover mode is disabled");
    MoveResize *mr = [MoveResize instance];
    XCTAssertFalse([mr isHoverActive], "isHoverActive should remain NO when hover disabled");
    CFRelease(event);
}

- (void)testFlagsChangedAlwaysReturnsEvent {
    // Modifier events should never be swallowed
    [delegate setSessionActive:YES];
    [self setCachedHoverModeEnabled:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    CGEventRef event = [self createFlagsChangedEvent:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    CGEventRef result = myCGEventCallback(NULL, kCGEventFlagsChanged, event, (__bridge void *)delegate);
    XCTAssertEqual(result, event, "kCGEventFlagsChanged should always return event (never swallowed)");

    // Cleanup
    MoveResize *mr = [MoveResize instance];
    [mr setIsHoverActive:NO];
    [mr setTracking:0];
    CFRelease(event);
}

- (void)testFlagsChangedDeactivatesOnModifierRelease {
    [delegate setSessionActive:YES];
    [self setCachedHoverModeEnabled:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    // Simulate active hover
    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsHoverActive:YES];
    [mr setIsResizing:NO];

    // Release all modifiers (flags = 0)
    CGEventRef event = [self createFlagsChangedEvent:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventFlagsChanged, event, (__bridge void *)delegate);

    XCTAssertEqual(result, event, "Event should be passed through");
    XCTAssertFalse([mr isHoverActive], "isHoverActive should be NO after modifier release");
    XCTAssertEqual([mr tracking], 0, "tracking should be cleared after deactivation");
    XCTAssertFalse([mr isResizing], "isResizing should be NO after deactivation");
    CFRelease(event);
}

- (void)testFlagsChangedResizeOnlySuppressesMoveHover {
    [delegate setSessionActive:YES];
    [self setCachedHoverModeEnabled:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
    [prefs setBool:YES forKey:@"ResizeOnly"];

    // Send move modifiers — should not activate due to resizeOnly
    CGEventRef event = [self createFlagsChangedEvent:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    myCGEventCallback(NULL, kCGEventFlagsChanged, event, (__bridge void *)delegate);

    MoveResize *mr = [MoveResize instance];
    XCTAssertFalse([mr isHoverActive], "Hover move should not activate when resizeOnly is ON");

    [prefs setBool:NO forKey:@"ResizeOnly"];
    CFRelease(event);
}

#pragma mark - Hover mode: kCGEventMouseMoved

- (void)testMouseMovedPassesThroughWhenNotHovering {
    [delegate setSessionActive:YES];
    [self setCachedHoverModeEnabled:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];

    MoveResize *mr = [MoveResize instance];
    [mr setIsHoverActive:NO];
    [mr setTracking:0];

    CGEventRef event = [self createMouseMovedEvent:0 deltaX:10 deltaY:5];
    CGEventRef result = myCGEventCallback(NULL, kCGEventMouseMoved, event, (__bridge void *)delegate);

    XCTAssertEqual(result, event, "Mouse moved should pass through when not hovering");
    CFRelease(event);
}

- (void)testMouseMovedAlwaysReturnsEvent {
    // Mouse moved events should never be swallowed
    [delegate setSessionActive:YES];
    [self setCachedHoverModeEnabled:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];

    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsHoverActive:YES];
    [mr setIsResizing:NO];
    [mr setWndPosition:NSMakePoint(100, 100)];

    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseMovedEvent:flags deltaX:10 deltaY:5];
    CGEventRef result = myCGEventCallback(NULL, kCGEventMouseMoved, event, (__bridge void *)delegate);

    XCTAssertEqual(result, event, "kCGEventMouseMoved should always return event (never NULL)");

    [mr setIsHoverActive:NO];
    [mr setTracking:0];
    CFRelease(event);
}

- (void)testMouseMovedUpdatesPositionDuringHoverMove {
    [delegate setSessionActive:YES];
    [self setCachedHoverModeEnabled:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [delegate setMoveFilterInterval:0]; // No throttle for testing

    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime() - 1]; // Started 1 sec ago
    [mr setIsHoverActive:YES];
    [mr setIsResizing:NO];
    NSPoint originalPos = NSMakePoint(100, 100);
    [mr setWndPosition:originalPos];

    CGEventFlags flags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl;
    CGEventRef event = [self createMouseMovedEvent:flags deltaX:15 deltaY:20];
    myCGEventCallback(NULL, kCGEventMouseMoved, event, (__bridge void *)delegate);

    // wndPosition should have been updated by the delta
    NSPoint newPos = [mr wndPosition];
    XCTAssertEqualWithAccuracy(newPos.x, 115.0, 0.1, "X position should increase by deltaX");
    XCTAssertEqualWithAccuracy(newPos.y, 120.0, 0.1, "Y position should increase by deltaY");

    [mr setIsHoverActive:NO];
    [mr setTracking:0];
    CFRelease(event);
}

#pragma mark - Hover mode: mouse-up during hover preserves tracking

- (void)testMouseUpDuringHoverDoesNotClearTracking {
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    MoveResize *mr = [MoveResize instance];
    CFTimeInterval startTime = CACurrentMediaTime();
    [mr setTracking:startTime];
    [mr setIsHoverActive:YES];
    [mr setIsResizing:NO];

    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseUp flags:0];
    CGEventRef result = myCGEventCallback(NULL, kCGEventLeftMouseUp, event, (__bridge void *)delegate);

    XCTAssertTrue(result == NULL, "Mouse-up during hover should still be handled (return NULL)");
    XCTAssertTrue([mr tracking] > 0, "Tracking should NOT be cleared during hover");
    XCTAssertTrue([mr isHoverActive], "isHoverActive should remain YES during mouse-up");

    // Cleanup
    [mr setIsHoverActive:NO];
    [mr setTracking:0];
    CFRelease(event);
}

#pragma mark - Popover dismissal on outside click

- (void)testPopoverDelegateIsSet {
    [delegate ensurePopoverCreated];
    NSPopover *p = [delegate valueForKey:@"popover"];
    XCTAssertNotNil(p, "Popover should be created");
    XCTAssertEqualObjects(p.delegate, delegate, "Popover delegate should be the app delegate");
}

- (void)testPopoverEventMonitorInstalledWhenShown {
    [delegate ensurePopoverCreated];
    // Simulate showing by calling the monitor installation directly
    [delegate installPopoverEventMonitor];
    id monitor = [delegate valueForKey:@"popoverEventMonitor"];
    XCTAssertNotNil(monitor, "Global event monitor should be installed when popover is shown");
    // Clean up
    [delegate removePopoverEventMonitor];
}

- (void)testPopoverEventMonitorRemovedWhenClosed {
    [delegate ensurePopoverCreated];
    [delegate installPopoverEventMonitor];
    [delegate removePopoverEventMonitor];
    id monitor = [delegate valueForKey:@"popoverEventMonitor"];
    XCTAssertNil(monitor, "Global event monitor should be removed when popover closes");
}

- (void)testMouseUpWithoutHoverClearsTracking {
    // Verify existing behavior is preserved when hover is NOT active
    [delegate setSessionActive:YES];
    [self setCachedMoveModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedResizeModifiers:kCGEventFlagMaskCommand | kCGEventFlagMaskControl];
    [self setCachedMoveButton:0 /* MouseButton.left */];
    [self setCachedResizeButton:1 /* MouseButton.right */];

    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsHoverActive:NO];
    [mr setIsResizing:YES];

    CGEventRef event = [self createMouseEvent:kCGEventLeftMouseUp flags:0];
    myCGEventCallback(NULL, kCGEventLeftMouseUp, event, (__bridge void *)delegate);

    XCTAssertEqual([mr tracking], 0, "Tracking should be cleared on mouse-up without hover");
    XCTAssertFalse([mr isResizing], "isResizing should be cleared on mouse-up without hover");
    CFRelease(event);
}

#pragma mark - Permission revocation: handlePermissionRevoked

- (void)testHandlePermissionRevokedClearsMoveResizeState {
    MoveResize *mr = [MoveResize instance];
    [mr setTracking:CACurrentMediaTime()];
    [mr setIsResizing:YES];
    [mr setIsHoverActive:YES];

    [delegate handlePermissionRevoked];

    XCTAssertEqual([mr tracking], 0, "tracking should be cleared after permission revoked");
    XCTAssertFalse([mr isResizing], "isResizing should be cleared after permission revoked");
    XCTAssertFalse([mr isHoverActive], "isHoverActive should be cleared after permission revoked");

    // Clean up onboarding bridge created by handlePermissionRevoked
    [delegate setValue:nil forKey:@"onboardingBridge"];
}

- (void)testHandlePermissionRevokedDeactivatesSession {
    [delegate setSessionActive:YES];

    [delegate handlePermissionRevoked];

    XCTAssertFalse([delegate sessionActive], "sessionActive should be NO after permission revoked");

    [delegate setValue:nil forKey:@"onboardingBridge"];
}

- (void)testHandlePermissionRevokedShowsOnboarding {
    [delegate handlePermissionRevoked];

    id bridge = [delegate valueForKey:@"onboardingBridge"];
    XCTAssertNotNil(bridge, "onboardingBridge should be created after permission revoked");

    [delegate setValue:nil forKey:@"onboardingBridge"];
}

- (void)testHandlePermissionRevokedStartsPolling {
    [delegate handlePermissionRevoked];

    if (@available(macOS 13.0, *)) {
        AccessibilityOnboardingBridge *bridge = [delegate valueForKey:@"onboardingBridge"];
        XCTAssertNotNil(bridge, "Precondition: bridge should exist");
        XCTAssertTrue([bridge isPolling], "Onboarding should be polling for permission after revocation");
        [bridge stopPolling];
    }

    [delegate setValue:nil forKey:@"onboardingBridge"];
}

- (void)testHandlePermissionRevokedSafeWithNullEventTap {
    // Should not crash when no event tap exists
    MoveResize *mr = [MoveResize instance];
    [mr setEventTap:NULL];
    [mr setRunLoopSource:NULL];

    XCTAssertNoThrow([delegate handlePermissionRevoked], "Should handle NULL event tap gracefully");

    [delegate setValue:nil forKey:@"onboardingBridge"];
}

- (void)testTogglePopoverDuringOnboardingShowsOnboardingWindow {
    // Simulate active onboarding
    [delegate showAccessibilityOnboarding];

    id bridge = [delegate valueForKey:@"onboardingBridge"];
    XCTAssertNotNil(bridge, "Precondition: onboarding bridge should exist");

    // togglePopover should re-show onboarding, not create settings popover
    [delegate togglePopover:nil];

    NSPopover *popover = [delegate valueForKey:@"popover"];
    XCTAssertNil(popover, "Settings popover should NOT be created during onboarding");

    if (@available(macOS 13.0, *)) {
        AccessibilityOnboardingBridge *onboarding = bridge;
        [onboarding stopPolling];
    }
    [delegate setValue:nil forKey:@"onboardingBridge"];
}

- (void)testHandlePermissionRevokedRemovesWorkspaceObservers {
    // Manually register workspace observers (simulating setupEventTapAndObservers)
    NSNotificationCenter *wsnc = [[NSWorkspace sharedWorkspace] notificationCenter];
    [wsnc addObserver:delegate
             selector:@selector(becameActive:)
                 name:NSWorkspaceSessionDidBecomeActiveNotification
               object:nil];
    [wsnc addObserver:delegate
             selector:@selector(becameInactive:)
                 name:NSWorkspaceSessionDidResignActiveNotification
               object:nil];

    // handlePermissionRevoked should remove those observers
    [delegate handlePermissionRevoked];

    // Reset sessionActive so we can detect whether becameInactive: fires
    [delegate setSessionActive:YES];

    // Post a resign notification — if observers were removed, sessionActive stays YES
    [wsnc postNotificationName:NSWorkspaceSessionDidResignActiveNotification object:nil];
    XCTAssertTrue([delegate sessionActive],
                  "becameInactive: should NOT fire after handlePermissionRevoked removes observers");

    if (@available(macOS 13.0, *)) {
        AccessibilityOnboardingBridge *bridge = [delegate valueForKey:@"onboardingBridge"];
        [bridge stopPolling];
    }
    [delegate setValue:nil forKey:@"onboardingBridge"];
}

- (void)testHandlePermissionRevokedTwiceDoesNotCrash {
    // Calling handlePermissionRevoked multiple times should be safe
    // (e.g. if multiple kCGEventTapDisabledByTimeout events fire before main queue processes)
    [delegate handlePermissionRevoked];
    XCTAssertNoThrow([delegate handlePermissionRevoked], "Double revocation should not crash");

    if (@available(macOS 13.0, *)) {
        AccessibilityOnboardingBridge *bridge = [delegate valueForKey:@"onboardingBridge"];
        [bridge stopPolling];
    }
    [delegate setValue:nil forKey:@"onboardingBridge"];
}

@end
