#import "EMRAppDelegate.h"
#import "ResizeTypes.h"
#import "Zooom3-Swift.h"

#define ALL_MODIFIERS (kCGEventFlagMaskShift | kCGEventFlagMaskCommand | \
    kCGEventFlagMaskAlphaShift | kCGEventFlagMaskAlternate | \
    kCGEventFlagMaskControl | kCGEventFlagMaskSecondaryFn)

// Forward-declare methods used by the static helper before @implementation
@interface EMRAppDelegate (HelperForwardDecl)
- (NSDictionary *)getDisabledApps;
- (void)setMostRecentApp:(NSRunningApplication *)app;
- (BOOL)shouldBringWindowToFront;
@end

/* Capture the window at the given screen point via the Accessibility API.
 * Sets wndPosition (and optionally wndSize + resizeSection for resize) on MoveResize.
 * Returns YES if a window was captured, NO if no valid window was found (e.g. desktop,
 * disabled app, or AX failure). */
static BOOL captureWindowAtPoint(CGPoint mouseLocation, EMRAppDelegate *ourDelegate, BOOL forResize) {
    MoveResize *moveResize = [MoveResize instance];

    AXUIElementRef _systemWideElement = AXUIElementCreateSystemWide();
    AXUIElementRef _clickedWindow = NULL;

    AXUIElementRef _element;
    if ((AXUIElementCopyElementAtPosition(_systemWideElement, (float)mouseLocation.x, (float)mouseLocation.y, &_element) == kAXErrorSuccess) && _element) {
        CFTypeRef _role;
        if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityRoleAttribute, &_role) == kAXErrorSuccess) {
            if ([(__bridge NSString *)_role isEqualToString:NSAccessibilityWindowRole]) {
                _clickedWindow = _element;
            }
            if (_role != NULL) CFRelease(_role);
        }
        CFTypeRef _window;
        if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityWindowAttribute, &_window) == kAXErrorSuccess) {
            if (_element != NULL) CFRelease(_element);
            _clickedWindow = (AXUIElementRef)_window;
        }
    }
    CFRelease(_systemWideElement);

    if (_clickedWindow == NULL) return NO;

    // Disabled app check
    pid_t PID;
    NSRunningApplication *app = nil;
    if (!AXUIElementGetPid(_clickedWindow, &PID)) {
        app = [NSRunningApplication runningApplicationWithProcessIdentifier:PID];
        if ([[ourDelegate getDisabledApps] objectForKey:[app bundleIdentifier]] != nil) {
            CFRelease(_clickedWindow);
            return NO;
        }
        [ourDelegate setMostRecentApp:app];
    }

    // Bring to front
    if ([ourDelegate shouldBringWindowToFront]) {
        if (app != nil) {
            [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        }
        AXUIElementPerformAction(_clickedWindow, kAXRaiseAction);
    }

    // Capture position
    CFTypeRef _cPosition = nil;
    NSPoint cTopLeft;
    if (AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, &_cPosition) == kAXErrorSuccess) {
        if (!AXValueGetValue(_cPosition, kAXValueCGPointType, (void *)&cTopLeft)) {
            NSLog(@"ERROR: Could not decode position");
            cTopLeft = NSMakePoint(0, 0);
        }
        CFRelease(_cPosition);
    }

    cTopLeft.x = (int)cTopLeft.x;
    cTopLeft.y = (int)cTopLeft.y;

    [moveResize setWndPosition:cTopLeft];
    [moveResize setWindow:_clickedWindow];

    // Capture size and compute resize section if needed
    if (forResize) {
        struct ResizeSection resizeSection;
        CGPoint clickPoint = mouseLocation;
        clickPoint.x -= cTopLeft.x;
        clickPoint.y -= cTopLeft.y;

        CFTypeRef _cSize;
        NSSize cSize;
        if (!(AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &_cSize) == kAXErrorSuccess)
                || !AXValueGetValue(_cSize, kAXValueCGSizeType, (void *)&cSize)) {
            NSLog(@"ERROR: Could not decode size");
            CFRelease(_clickedWindow);
            [moveResize setTracking:0];
            [moveResize setIsResizing:NO];
            return NO;
        }
        CFRelease(_cSize);

        NSSize wndSize = cSize;

        if (clickPoint.x < wndSize.width / 3) {
            resizeSection.xResizeDirection = left;
        } else if (clickPoint.x > 2 * wndSize.width / 3) {
            resizeSection.xResizeDirection = right;
        } else {
            resizeSection.xResizeDirection = noX;
        }

        if (clickPoint.y < wndSize.height / 3) {
            resizeSection.yResizeDirection = bottom;
        } else if (clickPoint.y > 2 * wndSize.height / 3) {
            resizeSection.yResizeDirection = top;
        } else {
            resizeSection.yResizeDirection = noY;
        }

        [moveResize setWndSize:wndSize];
        [moveResize setResizeSection:resizeSection];
    }

    CFRelease(_clickedWindow);
    return YES;
}

/* Return the minimum refresh interval (1/refresh rate) across all screens. If the user
 * is on a version of MacOS < 12.0 then 60hz refresh rate is assumed. */
float getMinRefreshInterval(void) {
    float minInterval = 1.0 / 60;
    for (unsigned i=0; i<NSScreen.screens.count; ++i) {
        if (@available(macOS 12.0, *)) {
            minInterval = MIN(minInterval, NSScreen.screens[i].minimumRefreshInterval);
        }
    }
    return minInterval;
}

@interface EMRAppDelegate () <SettingsViewDelegate>
@end

@implementation EMRAppDelegate {
    Preferences *preferences;
    SettingsViewBridge *settingsBridge;
}

- (id) init  {
    self = [super init];
    if (self) {
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
        preferences = [[Preferences alloc] initWithUserDefaults:userDefaults];

        // Window move and resize based on minimum refresh interval across all screens
        const float refreshRate = getMinRefreshInterval();
        self.moveFilterInterval = refreshRate;
        self.resizeFilterInterval = refreshRate;
    }
    return self;
}

- (void)refreshCachedPreferences {
    keyModifierFlags = (int)[preferences modifierFlags];
    resizeKeyModifierFlags = (int)[preferences resizeModifierFlagsValue];
    cachedMoveMouseButton = (int)[preferences moveMouseButtonValue];
    cachedResizeMouseButton = (int)[preferences resizeMouseButtonValue];
    cachedHasConflict = [preferences hasConflictingConfig];
    cachedHoverModeEnabled = [preferences hoverModeEnabled];
}

- (CGEventMask)eventMaskForCurrentPreferences {
    CGEventMask eventMask = CGEventMaskBit(kCGEventLeftMouseDown)
        | CGEventMaskBit(kCGEventRightMouseDown)
        | CGEventMaskBit(kCGEventOtherMouseDown)
        | CGEventMaskBit(kCGEventLeftMouseDragged)
        | CGEventMaskBit(kCGEventRightMouseDragged)
        | CGEventMaskBit(kCGEventOtherMouseDragged)
        | CGEventMaskBit(kCGEventLeftMouseUp)
        | CGEventMaskBit(kCGEventRightMouseUp)
        | CGEventMaskBit(kCGEventOtherMouseUp);

    if (preferences.hoverModeEnabled) {
        eventMask |= CGEventMaskBit(kCGEventFlagsChanged)
                   | CGEventMaskBit(kCGEventMouseMoved);
    }

    return eventMask;
}

- (void)recreateEventTap {
    MoveResize *moveResize = [MoveResize instance];

    // Tear down existing tap
    if ([moveResize eventTap] != NULL) {
        [self disableRunLoopSource:moveResize];
    }

    // Create new tap with updated mask
    CGEventMask eventMask = [self eventMaskForCurrentPreferences];
    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              eventMask,
                                              myCGEventCallback,
                                              (__bridge void * _Nullable)self);
    if (!eventTap) {
        NSLog(@"Couldn't recreate event tap!");
        return;
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    [moveResize setEventTap:eventTap];
    [moveResize setRunLoopSource:runLoopSource];
    [self enableRunLoopSource:moveResize];
    CFRelease(runLoopSource);
}

#pragma mark - Event callback

CGEventRef myCGEventCallback(CGEventTapProxy __unused proxy, CGEventType type, CGEventRef event, void *refcon) {

    EMRAppDelegate *ourDelegate = (__bridge EMRAppDelegate*)refcon;

    // Re-enable tap if it was disabled (usually happens on a slow resizing app)
    if ((type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)) {
        if (!AXIsProcessTrusted()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [ourDelegate handlePermissionRevoked];
            });
            return event;
        }
        MoveResize* mr = [MoveResize instance];
        CGEventTapEnable([mr eventTap], true);
        return event;
    }

    if (![ourDelegate sessionActive]) {
        return event;
    }

    // Read cached preference values (ivars, not NSUserDefaults)
    int moveModifiers = ourDelegate->keyModifierFlags;
    int resizeModifiers = ourDelegate->resizeKeyModifierFlags;
    int moveBtn = ourDelegate->cachedMoveMouseButton;
    int resizeBtn = ourDelegate->cachedResizeMouseButton;
    bool resizeOnly = [ourDelegate resizeOnly];

    // Both modifier sets are zero — nothing to do
    if (moveModifiers == 0 && resizeModifiers == 0) {
        return event;
    }

    CGEventFlags flags = CGEventGetFlags(event);
    MoveResize *moveResize = [MoveResize instance];

    // Check if flags match each modifier set with no extra modifiers
    BOOL moveModifiersMatch = NO;
    BOOL resizeModifiersMatch = NO;

    if (moveModifiers != 0 && (flags & moveModifiers) == (CGEventFlags)moveModifiers) {
        int moveIgnored = ALL_MODIFIERS ^ moveModifiers;
        moveModifiersMatch = !(flags & moveIgnored);
    }
    if (resizeModifiers != 0 && (flags & resizeModifiers) == (CGEventFlags)resizeModifiers) {
        int resizeIgnored = ALL_MODIFIERS ^ resizeModifiers;
        resizeModifiersMatch = !(flags & resizeIgnored);
    }

    // --- HOVER MODE: handle modifier activation/deactivation ---
    if (type == kCGEventFlagsChanged) {
        // Determine if modifiers now match resize or move (prefer resize on conflict)
        BOOL shouldActivateResize = resizeModifiersMatch;
        BOOL shouldActivateMove = moveModifiersMatch && !resizeOnly;
        if (shouldActivateResize && shouldActivateMove) {
            shouldActivateMove = NO; // conflict resolution: prefer resize
        }

        if ((shouldActivateResize || shouldActivateMove) && ![moveResize isHoverActive]) {
            // --- HOVER ACTIVATION ---
            CGPoint mouseLocation = CGEventGetLocation(event);
            BOOL forResize = shouldActivateResize;

            [moveResize setTracking:CACurrentMediaTime()];
            [moveResize setIsResizing:forResize];

            if (!captureWindowAtPoint(mouseLocation, ourDelegate, forResize)) {
                [moveResize setTracking:0];
                [moveResize setIsResizing:NO];
                return event;
            }

            [moveResize setIsHoverActive:YES];
        }
        else if (!shouldActivateResize && !shouldActivateMove && [moveResize isHoverActive]) {
            // --- HOVER DEACTIVATION ---
            [moveResize setIsHoverActive:NO];
            [moveResize setTracking:0];
            [moveResize setIsResizing:NO];
        }

        return event; // never swallow modifier events
    }

    // --- HOVER MODE: handle mouse movement without click ---
    if (type == kCGEventMouseMoved) {
        if (![moveResize isHoverActive] || [moveResize tracking] == 0) {
            return event;
        }

        if ([moveResize isResizing]) {
            // Hover resize — same logic as drag resize
            AXUIElementRef _hoverWindow = [moveResize window];
            struct ResizeSection resizeSection = [moveResize resizeSection];
            int deltaX = (int)CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
            int deltaY = (int)CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

            NSPoint cTopLeft = [moveResize wndPosition];
            NSSize wndSize = [moveResize wndSize];

            switch (resizeSection.xResizeDirection) {
                case right: wndSize.width += deltaX; break;
                case left:  wndSize.width -= deltaX; cTopLeft.x += deltaX; break;
                case noX:   break;
                default: break;
            }
            switch (resizeSection.yResizeDirection) {
                case top:    wndSize.height += deltaY; break;
                case bottom: wndSize.height -= deltaY; cTopLeft.y += deltaY; break;
                case noY:    break;
                default: break;
            }

            [moveResize setWndPosition:cTopLeft];
            [moveResize setWndSize:wndSize];

            if (CACurrentMediaTime() - [moveResize tracking] > ourDelegate.resizeFilterInterval) {
                if (resizeSection.xResizeDirection == left || resizeSection.yResizeDirection == bottom) {
                    CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&cTopLeft));
                    AXUIElementSetAttributeValue(_hoverWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
                    CFRelease(_position);
                }
                CFTypeRef _size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&wndSize));
                AXUIElementSetAttributeValue(_hoverWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, (CFTypeRef *)_size);
                CFRelease(_size);
                [moveResize setTracking:CACurrentMediaTime()];
            }
        } else {
            // Hover move — same logic as drag move
            AXUIElementRef _hoverWindow = [moveResize window];
            double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
            double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

            NSPoint cTopLeft = [moveResize wndPosition];
            NSPoint thePoint;
            thePoint.x = cTopLeft.x + deltaX;
            thePoint.y = cTopLeft.y + deltaY;
            [moveResize setWndPosition:thePoint];

            if (CACurrentMediaTime() - [moveResize tracking] > ourDelegate.moveFilterInterval) {
                CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
                AXUIElementSetAttributeValue(_hoverWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
                if (_position != NULL) CFRelease(_position);
                [moveResize setTracking:CACurrentMediaTime()];
            }
        }

        return event; // never swallow mouse movement
    }

    // Map CGEvent type to button number and event phase
    int eventButton = -1;
    BOOL isDown = NO, isDrag = NO, isUp = NO;
    switch (type) {
        case kCGEventLeftMouseDown:     eventButton = 0; isDown = YES; break;
        case kCGEventRightMouseDown:    eventButton = 1; isDown = YES; break;
        case kCGEventOtherMouseDown:    eventButton = 2; isDown = YES; break;
        case kCGEventLeftMouseDragged:  eventButton = 0; isDrag = YES; break;
        case kCGEventRightMouseDragged: eventButton = 1; isDrag = YES; break;
        case kCGEventOtherMouseDragged: eventButton = 2; isDrag = YES; break;
        case kCGEventLeftMouseUp:       eventButton = 0; isUp = YES; break;
        case kCGEventRightMouseUp:      eventButton = 1; isUp = YES; break;
        case kCGEventOtherMouseUp:      eventButton = 2; isUp = YES; break;
        default: return event;
    }

    // Determine if this event matches move, resize, or neither
    BOOL isForMove = (eventButton == moveBtn && moveModifiersMatch && !resizeOnly);
    BOOL isForResize = (eventButton == resizeBtn && resizeModifiersMatch);

    // Conflict resolution: if both match, prefer resize
    if (isForMove && isForResize) {
        isForMove = NO;
    }

    // If neither matches and we're not in an active drag, this event isn't for us
    if (!isForMove && !isForResize && !([moveResize tracking] > 0)) {
        return event;
    }

    BOOL handled = NO;

    // --- MOUSE DOWN: capture window, set isResizing, compute resize direction ---
    if (isDown && (isForMove || isForResize)) {
        CGPoint mouseLocation = CGEventGetLocation(event);
        [moveResize setTracking:CACurrentMediaTime()];
        [moveResize setIsResizing:isForResize];

        if (!captureWindowAtPoint(mouseLocation, ourDelegate, isForResize)) {
            [moveResize setTracking:0];
            [moveResize setIsResizing:NO];
            return isForResize ? NULL : event;
        }

        handled = YES;
    }

    // --- MOUSE DRAG: move or resize based on isResizing ---
    if (isDrag && [moveResize tracking] > 0) {
        if ([moveResize isResizing]) {
            // Resize drag
            AXUIElementRef _clickedWindow = [moveResize window];
            struct ResizeSection resizeSection = [moveResize resizeSection];
            int deltaX = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
            int deltaY = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

            NSPoint cTopLeft = [moveResize wndPosition];
            NSSize wndSize = [moveResize wndSize];

            switch (resizeSection.xResizeDirection) {
                case right:
                    wndSize.width += deltaX;
                    break;
                case left:
                    wndSize.width -= deltaX;
                    cTopLeft.x += deltaX;
                    break;
                case noX:
                    break;
                default:
                    [NSException raise:@"Unknown xResizeSection" format:@"No case for %d", resizeSection.xResizeDirection];
            }

            switch (resizeSection.yResizeDirection) {
                case top:
                    wndSize.height += deltaY;
                    break;
                case bottom:
                    wndSize.height -= deltaY;
                    cTopLeft.y += deltaY;
                    break;
                case noY:
                    break;
                default:
                    [NSException raise:@"Unknown yResizeSection" format:@"No case for %d", resizeSection.yResizeDirection];
            }

            [moveResize setWndPosition:cTopLeft];
            [moveResize setWndSize:wndSize];

            if (CACurrentMediaTime() - [moveResize tracking] > ourDelegate.resizeFilterInterval) {
                if (resizeSection.xResizeDirection == left || resizeSection.yResizeDirection == bottom) {
                    CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&cTopLeft));
                    AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
                    CFRelease(_position);
                }

                CFTypeRef _size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&wndSize));
                AXUIElementSetAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, (CFTypeRef *)_size);
                CFRelease(_size);
                [moveResize setTracking:CACurrentMediaTime()];
            }
        } else {
            // Move drag
            AXUIElementRef _clickedWindow = [moveResize window];
            double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
            double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

            NSPoint cTopLeft = [moveResize wndPosition];
            NSPoint thePoint;
            thePoint.x = cTopLeft.x + deltaX;
            thePoint.y = cTopLeft.y + deltaY;
            [moveResize setWndPosition:thePoint];

            if (CACurrentMediaTime() - [moveResize tracking] > ourDelegate.moveFilterInterval) {
                CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
                AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
                if (_position != NULL) CFRelease(_position);
                [moveResize setTracking:CACurrentMediaTime()];
            }
        }
        handled = YES;
    }

    // --- MOUSE UP: clear tracking (but not during hover — let modifier release handle it) ---
    if (isUp && [moveResize tracking] > 0) {
        if (![moveResize isHoverActive]) {
            [moveResize setTracking:0];
            [moveResize setIsResizing:NO];
        }
        handled = YES;
    }

    return handled ? NULL : event;
}

#pragma mark - Application lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Skip the entire accessibility check when running under XCTest.
    if (NSClassFromString(@"XCTestCase") != nil) {
        return;
    }

    if (AXIsProcessTrusted()) {
        [self setupEventTapAndObservers];
    } else {
        [self showAccessibilityOnboarding];
    }
}

- (void)setupEventTapAndObservers {
    [self refreshCachedPreferences];

    CGEventMask eventMask = [self eventMaskForCurrentPreferences];

    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              eventMask,
                                              myCGEventCallback,
                                              (__bridge void * _Nullable)self);

    if (!eventTap) {
        NSLog(@"Couldn't create event tap!");
        exit(1);
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);

    MoveResize *moveResize = [MoveResize instance];
    [moveResize setEventTap:eventTap];
    [moveResize setRunLoopSource:runLoopSource];
    [self enableRunLoopSource:moveResize];
    CFRelease(runLoopSource);

    _sessionActive = true;
    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(becameActive:)
            name:NSWorkspaceSessionDidBecomeActiveNotification
            object:nil];

    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(becameInactive:)
            name:NSWorkspaceSessionDidResignActiveNotification
            object:nil];

    [self reconstructDisabledAppsSubmenu];
}

- (void)showAccessibilityOnboarding {
    if (@available(macOS 13.0, *)) {
        onboardingBridge = [[AccessibilityOnboardingBridge alloc] init];
        __weak typeof(self) weakSelf = self;
        [onboardingBridge setOnPermissionGranted:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf accessibilityPermissionGranted];
            });
        }];
        [onboardingBridge showWindow];
        [onboardingBridge startPolling];
    }
}

- (void)handlePermissionRevoked {
    // Remove workspace observers so setupEventTapAndObservers can re-add them cleanly
    NSNotificationCenter *wsnc = [[NSWorkspace sharedWorkspace] notificationCenter];
    [wsnc removeObserver:self name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
    [wsnc removeObserver:self name:NSWorkspaceSessionDidResignActiveNotification object:nil];

    MoveResize *moveResize = [MoveResize instance];

    // Cancel any active move/resize operation
    [moveResize setIsHoverActive:NO];
    [moveResize setTracking:0];
    [moveResize setIsResizing:NO];

    // Tear down the event tap
    if ([moveResize eventTap] != NULL) {
        [self disableRunLoopSource:moveResize];
        [moveResize setEventTap:NULL];
        [moveResize setRunLoopSource:NULL];
    }

    _sessionActive = false;

    [self showAccessibilityOnboarding];
}

- (void)accessibilityPermissionGranted {
    if (@available(macOS 13.0, *)) {
        [onboardingBridge closeWindow];
        onboardingBridge = nil;
    }
    [self setupEventTapAndObservers];
}

- (void)becameActive:(NSNotification*) notification {
    _sessionActive = true;
}

- (void)becameInactive:(NSNotification*) notification {
    _sessionActive = false;
}

-(void)awakeFromNib{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    statusItem.button.image = [NSImage imageNamed:@"MenuIcon"];
    statusItem.button.target = self;
    statusItem.button.action = @selector(togglePopover:);
}

- (void)ensurePopoverCreated {
    if (popover == nil) {
        if (@available(macOS 13.0, *)) {
            settingsBridge = [[SettingsViewBridge alloc] initWithPreferences:preferences];
            settingsBridge.delegate = self;
            popover = [[NSPopover alloc] init];
            popover.contentViewController = settingsBridge.viewController;
            popover.behavior = NSPopoverBehaviorSemitransient;
            popover.delegate = self;
        }
    }
}

- (void)togglePopover:(id)sender {
    // During onboarding, re-show the onboarding window instead of settings
    if (onboardingBridge != nil) {
        if (@available(macOS 13.0, *)) {
            [onboardingBridge showWindow];
        }
        return;
    }

    [self ensurePopoverCreated];

    if (popover.isShown) {
        [popover performClose:sender];
    } else {
        if (@available(macOS 13.0, *)) {
            [settingsBridge syncFromPreferences];
        }
        [popover showRelativeToRect:statusItem.button.bounds ofView:statusItem.button preferredEdge:NSMinYEdge];
        [self installPopoverEventMonitor];
    }
}

- (void)installPopoverEventMonitor {
    if (popoverEventMonitor != nil) return;
    popoverEventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown)
                                                                handler:^(NSEvent *event) {
        if (self->popover.isShown) {
            [self->popover performClose:nil];
        }
    }];
}

- (void)removePopoverEventMonitor {
    if (popoverEventMonitor != nil) {
        [NSEvent removeMonitor:popoverEventMonitor];
        popoverEventMonitor = nil;
    }
}

- (void)popoverDidClose:(NSNotification *)notification {
    [self removePopoverEventMonitor];
}

- (void)enableRunLoopSource:(MoveResize*)moveResize {
    CFRunLoopAddSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
    CGEventTapEnable([moveResize eventTap], true);
}

- (void)disableRunLoopSource:(MoveResize*)moveResize {
    CGEventTapEnable([moveResize eventTap], false);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
}

#pragma mark - SettingsViewDelegate

- (void)settingsDidChangeModifiers {
    [self refreshCachedPreferences];
}

- (void)settingsDidChangeMouseButton {
    [self refreshCachedPreferences];
}

- (void)settingsDidToggleHoverMode {
    if (!preferences.hoverModeEnabled) {
        MoveResize *moveResize = [MoveResize instance];
        [moveResize setIsHoverActive:NO];
        [moveResize setTracking:0];
        [moveResize setIsResizing:NO];
    }
    [self refreshCachedPreferences];
    [self recreateEventTap];
}

- (void)settingsDidReset {
    MoveResize *moveResize = [MoveResize instance];
    [moveResize setIsHoverActive:NO];
    [moveResize setTracking:0];
    [moveResize setIsResizing:NO];
    [preferences setToDefaults];
    [self enableRunLoopSource:moveResize];
    [self refreshCachedPreferences];
    [self recreateEventTap];
}

- (void)settingsDidQuit {
    [NSApp terminate:nil];
}

#pragma mark - Accessor methods

- (int)modifierFlags {
    return keyModifierFlags;
}
- (int)resizeModifierFlags {
    return resizeKeyModifierFlags;
}
- (int)moveMouseButton {
    return cachedMoveMouseButton;
}
- (int)resizeMouseButton {
    return cachedResizeMouseButton;
}
- (void) setMostRecentApp:(NSRunningApplication*)app {
    lastApp = app;
}
- (NSDictionary*) getDisabledApps {
    return [preferences getDisabledApps];
}
-(BOOL)shouldBringWindowToFront {
    return [preferences shouldBringWindowToFront];
}
-(BOOL)resizeOnly {
    return [preferences resizeOnly];
}

- (void)reconstructDisabledAppsSubmenu {
    // Disabled apps UI removed — method kept for disabled apps check in event callback
}

@end
