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