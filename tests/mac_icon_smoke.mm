#import <Cocoa/Cocoa.h>
#include <cstddef>
#include <cstdio>

extern "C" void register_app_did_finish_launching_handler(void (*callback)(void));
extern "C" int set_application_icon(const unsigned char *bytes, size_t length);

static const unsigned char *icon_bytes;
static size_t icon_length;
static int icon_install_result;

extern "C" void install_icon_after_launch() {
    icon_install_result = set_application_icon(icon_bytes, icon_length);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 2) {
            std::fprintf(stderr, "Usage: mac_icon_smoke path/to/icon.icns\n");
            return 2;
        }
        if (![NSThread isMainThread]) {
            std::fprintf(stderr, "Smoke test must run on the main thread\n");
            return 1;
        }

        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data == nil || data.length == 0) {
            std::fprintf(stderr, "Could not read the supplied icon file\n");
            return 1;
        }

        NSApplication *application = [NSApplication sharedApplication];
        icon_bytes = static_cast<const unsigned char *>(data.bytes);
        icon_length = data.length;
        register_app_did_finish_launching_handler(install_icon_after_launch);
        [[NSNotificationCenter defaultCenter]
            postNotificationName:NSApplicationDidFinishLaunchingNotification
                          object:application];

        if (icon_install_result == 0) {
            std::fprintf(stderr, "The icon was not installed after application launch\n");
            return 1;
        }

        NSImage *installedImage = [application applicationIconImage];
        if (installedImage == nil || installedImage.size.width <= 0 || installedImage.size.height <= 0) {
            std::fprintf(stderr, "The application icon was not installed\n");
            return 1;
        }

        const unsigned char invalidBytes[] = {0x00, 0x01, 0x02, 0x03};
        if (set_application_icon(invalidBytes, sizeof(invalidBytes)) != 0 ||
            set_application_icon(nullptr, 0) != 0 ||
            [application applicationIconImage] != installedImage) {
            std::fprintf(stderr, "Invalid icon data changed the application icon\n");
            return 1;
        }

        std::puts("macOS application icon smoke test passed");
        return 0;
    }
}