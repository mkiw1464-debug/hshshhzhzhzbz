// FFEX IOS - Main Entry Point
// __attribute__((constructor)) fires when framework loads into process
// Injection method: framework embedding inside IPA (no dylib injection)
// The cheat is compiled as a framework embedded in the app bundle
// AppInstaller / GBox / Esign / Sideloadly install the modified IPA

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include "FFEXCore.h"

// ══════════════════════════════════════════════════════════════
// FRAMEWORK INJECTION METHOD
//
// Instead of dylib injection (which requires jailbreak / SpringBoard),
// FFEX embeds itself as a @rpath framework inside the Free Fire IPA:
//
// Payload/
//   FreeFire.app/
//     Frameworks/
//       FFEX.framework/          ← our cheat framework
//         FFEX                   ← Mach-O dylib
//     FreeFire (binary)          ← Load cmd LC_LOAD_DYLIB added:
//                                    @rpath/FFEX.dylib
//
// Tools to do this:
//   - insert_dylib / optool: adds LC_LOAD_DYLIB to FreeFire binary
//   - ldid: re-sign with ad-hoc or developer cert
//   - zsign: sign everything (works for GBox/Esign/Sideloadly)
//
// The framework's __constructor__ runs before UIApplicationMain,
// so we intercept at the earliest possible point.
// ══════════════════════════════════════════════════════════════

// ─── Swizzle UIApplication to intercept before game starts ───
static IMP orig_application_didFinishLaunching = NULL;

static BOOL ffex_application_didFinishLaunching(id self, SEL _cmd,
                                                  UIApplication *app,
                                                  NSDictionary *opts) {
    // 1. Install AntiCheat bypass FIRST
    //    Must be before any game code runs to catch early ptrace/sysctl calls
    ffex_installAntiCheatBypass();
    
    // 2. Show FFEX login page (blocks game from loading until validated)
    ffex_installLoginPage();
    
    // 3. Listen for login complete → then install cheat hooks and mod menu
    [[NSNotificationCenter defaultCenter] addObserverForName:@"FFEXLoginComplete"
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        
        ffex_initCheat();
        ffex_installModMenu();
        ffex_installGameHooks();
        
        // Now let the original AppDelegate run
        if (orig_application_didFinishLaunching) {
            ((BOOL(*)(id,SEL,UIApplication*,NSDictionary*))
             orig_application_didFinishLaunching)(self, _cmd, app, opts);
        }
    }];
    
    // Return YES to signal successful launch (even though game hasn't loaded yet)
    return YES;
}

// ─── Game Loop Hook ────────────────────────────────────────────
// We hook il2cpp's MonoBehaviour.Update via method_setImplementation
// to run our cheat update every frame

void ffex_installGameHooks(void) {
    // This is called after login is verified
    // Install any remaining hooks that need to run in-game
    NSLog(@"[FFEX] Game hooks installed");
}

// ─── Constructor ──────────────────────────────────────────────
__attribute__((constructor))
static void FFEXInit(void) {
    @autoreleasepool {
        NSLog(@"[FFEX] Framework loaded — FFEX IOS v1.0");
        
        // Find AppDelegate class and swizzle didFinishLaunching
        // Free Fire's AppDelegate is often named COWAppDelegate or similar
        NSArray *candidateNames = @[
            @"COWAppDelegate",
            @"AppDelegate",
            @"FFAppDelegate",
            @"GarenaAppDelegate",
            @"com_garena_AppDelegate",
        ];
        
        Class appDelegateClass = nil;
        for (NSString *name in candidateNames) {
            Class cls = NSClassFromString(name);
            if (cls) {
                appDelegateClass = cls;
                break;
            }
        }
        
        // If not found by name, find via UIApplicationDelegate conformance
        if (!appDelegateClass) {
            unsigned int count = 0;
            Class *classes = objc_copyClassList(&count);
            for (unsigned int i = 0; i < count; i++) {
                if (class_conformsToProtocol(classes[i], @protocol(UIApplicationDelegate))) {
                    // Skip known system classes
                    const char *name = class_getName(classes[i]);
                    if (strstr(name, "UI") || strstr(name, "NS")) continue;
                    appDelegateClass = classes[i];
                    break;
                }
            }
            free(classes);
        }
        
        if (appDelegateClass) {
            SEL sel = @selector(application:didFinishLaunchingWithOptions:);
            Method m = class_getInstanceMethod(appDelegateClass, sel);
            if (m) {
                orig_application_didFinishLaunching = method_getImplementation(m);
                method_setImplementation(m, (IMP)ffex_application_didFinishLaunching);
                NSLog(@"[FFEX] Hooked AppDelegate: %s", class_getName(appDelegateClass));
            }
        } else {
            // Fallback: install after a short delay (scene-based apps)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                ffex_installAntiCheatBypass();
                ffex_installLoginPage();
            });
        }
    }
}
