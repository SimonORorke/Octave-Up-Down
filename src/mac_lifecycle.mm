#import <Cocoa/Cocoa.h>
#include <cstddef>

typedef void (*TerminationCallback)(void);

extern "C" void register_app_did_finish_launching_handler(TerminationCallback callback) {
    NSApplication *application = [NSApplication sharedApplication];
    if ([application isRunning]) {
        if (callback) {
            callback();
        }
        return;
    }

    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSApplicationDidFinishLaunchingNotification
                    object:application
                     queue:nil
                usingBlock:^(NSNotification * _Nonnull note) {
                    (void)note;
                    if (callback) {
                        callback();
                    }
                }];
}

extern "C" void register_app_will_terminate_handler(TerminationCallback callback) {
    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSApplicationWillTerminateNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification * _Nonnull note) {
                    (void)note;
                    if (callback) {
                        callback();
                    }
                }];
}

// Target object that forwards the native "About <AppName>" menu item action (normally
// -orderFrontStandardAboutPanel:, which shows the generic macOS About panel) to the Rust
// callback registered via register_app_about_handler.
@interface AboutMenuHandler : NSObject
@end

@implementation AboutMenuHandler {
@public
    TerminationCallback callback;
}

- (void)showCustomAboutPanel:(id)sender {
    (void)sender;
    if (callback) {
        callback();
    }
}

@end

static AboutMenuHandler *gAboutMenuHandler = nil;

// Renames "<Verb> <ProcessName>" app-menu items (About/Hide/Quit) to use appName instead, since
// Slint's default macOS menu bar (built via the muda crate) derives these titles from
// NSProcessInfo's processName - the raw executable name (e.g. "octave-up-down") - rather than the
// app's intended display name, because this app is not launched from a proper .app bundle with an
// Info.plist/CFBundleName (that only happens when built via `cargo bundle`).
static void retitle_app_menu_items(NSMenu *appMenu, NSString *appName) {
    if (appName == nil) {
        return;
    }
    NSArray<NSString *> *prefixes = @[@"About ", @"Hide ", @"Quit "];
    for (NSMenuItem *item in [appMenu itemArray]) {
        NSString *title = [item title];
        for (NSString *prefix in prefixes) {
            if ([title hasPrefix:prefix] && ![title isEqualToString:@"Hide Others"]) {
                [item setTitle:[prefix stringByAppendingString:appName]];
                break;
            }
        }
    }
}

// Attempts to retarget the native "About <AppName>" item once the application menu bar exists.
// Returns YES on success, NO if the menu bar (specifically its application submenu) does not
// exist yet - which must not be treated as an error, since Slint (via the muda crate) only builds
// its default macOS menu bar lazily, the first time a window becomes active/key, not while the
// app is merely finishing launching. See the retry observer in register_app_about_handler below.
static BOOL try_register_app_about_handler(NSString *appName) {
    NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
    if (mainMenu == nil || [mainMenu numberOfItems] == 0) {
        return NO;
    }
    // The application submenu (showing "About <AppName>", "Quit <AppName>", etc.) is always the
    // submenu of the first top-level menu item.
    NSMenu *appMenu = [[mainMenu itemAtIndex:0] submenu];
    if (appMenu == nil || [appMenu numberOfItems] == 0) {
        return NO;
    }
    retitle_app_menu_items(appMenu, appName);
    // The "About <AppName>" item is always the first item of the application submenu. We match by
    // position rather than by action: Slint's default macOS menu bar (built via the muda crate)
    // wires the About item's action to muda's own internal selector (fireMenuItemAction:), not to
    // the standard -orderFrontStandardAboutPanel: selector, so matching on action would never find it.
    NSMenuItem *aboutItem = [appMenu itemAtIndex:0];
    [aboutItem setTarget:gAboutMenuHandler];
    [aboutItem setAction:@selector(showCustomAboutPanel:)];
    return YES;
}

// Retained app name, re-used by the retry observers below.
static NSString *gAboutAppName = nil;
static id gAboutActivationObserver = nil;
static id gAboutMenuTrackingObserver = nil;

extern "C" void register_app_about_handler(TerminationCallback callback, const char *app_name) {
    if (![NSThread isMainThread]) {
        return;
    }

    if (gAboutMenuHandler == nil) {
        gAboutMenuHandler = [[AboutMenuHandler alloc] init];
    }
    gAboutMenuHandler->callback = callback;
    // This file is compiled without ARC (see the manual [data release]/[image release] calls
    // below in set_application_icon), so autoreleased objects - such as the NSString returned by
    // +stringWithUTF8String: and the observer token returned by
    // +addObserverForName:object:queue:usingBlock: - must be explicitly retained before being
    // stored in a static global. Without this, they would be deallocated as soon as the
    // enclosing autorelease pool drains (e.g. at the end of the current run-loop iteration),
    // leaving gAboutAppName/gAboutActivationObserver dangling; using them afterwards (from the
    // retry block below, or from a later call to this function) is a use-after-free and crashes
    // the app, which matches the "closed unexpectedly" crash seen when launching the app.
    [gAboutAppName release];
    gAboutAppName = (app_name != nullptr)
        ? [[NSString stringWithUTF8String:app_name] retain]
        : nil;

    try_register_app_about_handler(gAboutAppName);
    // The application menu bar may not exist yet right now (e.g. Slint/muda only builds its
    // default macOS menu bar lazily, the first time a window becomes active/key, which happens
    // after NSApplicationDidFinishLaunchingNotification), and even once it exists, Slint rebuilds
    // a fresh default app menu (with un-retitled "About <process name>" etc. items) on every
    // subsequent window activation (see MenuBar::window_activation_changed in i-slint-backend-winit,
    // which calls muda's Menu::init_for_nsapp() again on each activation). Because of this, a
    // one-shot retry is not enough: the very first time the user opens the top menu - right after
    // launch, before any such rebuild/retry has had a chance to run again - it can still show the
    // untouched defaults, with only later opens showing the corrected titles. Keep re-applying the
    // retitling (idempotent and cheap) on every window activation for the lifetime of the app,
    // instead of stopping after the first success.
    if (gAboutActivationObserver == nil) {
        gAboutActivationObserver = [[[NSNotificationCenter defaultCenter]
            addObserverForName:NSWindowDidBecomeKeyNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification * _Nonnull note) {
                        (void)note;
                        try_register_app_about_handler(gAboutAppName);
                    }] retain];
    }
    // Also re-apply right before any native menu is about to be shown/tracked (e.g. the user
    // clicking into the top menu bar), so that even the very first open - which may happen before
    // any window-activation retry above has run again - already shows the corrected titles.
    if (gAboutMenuTrackingObserver == nil) {
        gAboutMenuTrackingObserver = [[[NSNotificationCenter defaultCenter]
            addObserverForName:NSMenuDidBeginTrackingNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification * _Nonnull note) {
                        (void)note;
                        try_register_app_about_handler(gAboutAppName);
                    }] retain];
    }
}

extern "C" int set_application_icon(const unsigned char *bytes, size_t length) {
    if (![NSThread isMainThread] || bytes == nullptr || length == 0) {
        return 0;
    }

    NSData *data = [[NSData alloc] initWithBytes:bytes length:length];
    if (data == nil) {
        return 0;
    }

    NSImage *image = [[NSImage alloc] initWithData:data];
    [data release];
    if (image == nil) {
        return 0;
    }

    [[NSApplication sharedApplication] setApplicationIconImage:image];
    [image release];
    return 1;
}