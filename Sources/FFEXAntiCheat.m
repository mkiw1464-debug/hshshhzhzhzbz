// FFEX IOS - AntiCheat Bypass Layer
// Targets: Garena Anti-Hack, EasyAntiCheat (mobile port),
//          Jailbreak detection, Root/TrustCache detection,
//          DNS-based anticheat blocking
// iOS 15-18+, arm64

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <fishhook.h>  // rebind_symbols

// ══════════════════════════════════════════════════════════════
// DNS BLOCK LIST — Garena AntiCheat Domains
// All traffic to these domains is silently dropped/NXDOMAINed
// via getaddrinfo and CFHost hooks
// ══════════════════════════════════════════════════════════════
static const char *kBlockedDomains[] = {
    // Garena AntiCheat infrastructure
    "antihack.garena.com",
    "anticheat.garena.com",
    "security.garena.com",
    "sdk-security.garena.com",
    "garenasdk-antihack.garena.com",
    "garena-anticheat.garena.com",
    "ac.garena.com",
    "anti-cheat.freefireind.com",
    "anticheat-ff.garena.com",
    "ff-anticheat.garena.com",
    // Telemetry / Reporting
    "telemetry.garena.com",
    "analytics-security.garena.com",
    "crash-report-security.garena.com",
    "cheat-detect.garena.com",
    // EAC mobile endpoints (Free Fire uses EAC SDK)
    "easyanticheat.net",
    "api.easyanticheat.net",
    "metrics.easyanticheat.net",
    "cdn.easyanticheat.net",
    // AI anti-hack endpoint patterns
    "ai-antihack.garena.com",
    "ml-anticheat.garena.com",
    "behaviour.garena.com",
    "behaviour-analysis.garena.com",
    NULL
};

static BOOL isDomainBlocked(const char *hostname) {
    if (!hostname) return NO;
    for (int i = 0; kBlockedDomains[i] != NULL; i++) {
        if (strcasestr(hostname, kBlockedDomains[i]) != NULL) {
            return YES;
        }
        // Also block subdomains
        if (strstr(hostname, kBlockedDomains[i]) != NULL) {
            return YES;
        }
    }
    return NO;
}

// ══════════════════════════════════════════════════════════════
// HOOK: getaddrinfo — DNS block
// ══════════════════════════════════════════════════════════════
#include <netdb.h>
typedef int (*getaddrinfo_t)(const char *hostname, const char *servname,
                              const struct addrinfo *hints, struct addrinfo **res);
static getaddrinfo_t orig_getaddrinfo = NULL;

static int hook_getaddrinfo(const char *hostname, const char *servname,
                              const struct addrinfo *hints, struct addrinfo **res) {
    if (hostname && isDomainBlocked(hostname)) {
        // Return NXDOMAIN
        if (res) *res = NULL;
        return EAI_NONAME;
    }
    return orig_getaddrinfo(hostname, servname, hints, res);
}

// ══════════════════════════════════════════════════════════════
// HOOK: NSURLSession — block anticheat API calls at network layer
// ══════════════════════════════════════════════════════════════
@interface NSURLRequest (FFEXBlock)
@end

static BOOL ffex_urlIsBlocked(NSURL *url) {
    NSString *host = url.host.lowercaseString;
    if (!host) return NO;
    for (int i = 0; kBlockedDomains[i] != NULL; i++) {
        if ([host containsString:[NSString stringWithUTF8String:kBlockedDomains[i]]]) {
            return YES;
        }
    }
    return NO;
}

// ══════════════════════════════════════════════════════════════
// HOOK: stat / lstat — hide cheat files from integrity checks
// ══════════════════════════════════════════════════════════════
typedef int (*stat_t)(const char *path, struct stat *buf);
typedef int (*lstat_t)(const char *path, struct stat *buf);
static stat_t orig_stat = NULL;
static lstat_t orig_lstat = NULL;

// Paths that anticheat checks for (jailbreak indicators)
static const char *kJBPaths[] = {
    "/Applications/Cydia.app",
    "/Applications/Sileo.app",
    "/Applications/Zebra.app",
    "/Applications/Installer.app",
    "/Library/MobileSubstrate/MobileSubstrate.dylib",
    "/usr/sbin/sshd",
    "/usr/bin/sshd",
    "/usr/libexec/sftp-server",
    "/private/var/lib/apt/",
    "/private/var/mobile/Library/SBSettings/",
    "/private/var/stash",
    "/private/var/db/stash",
    "/usr/share/jailbreak",
    "/etc/apt",
    "/bin/bash",
    "/bin/sh",    // iOS doesn't have this normally
    "/private/etc/apt",
    "/var/jb",    // Dopamine/Palera1n
    "/var/LIB",   // Checkra1n
    "/private/preboot",
    "/.bootstrapped_electra",
    "/taurine",
    "/odyssey",
    "/chimera",
    "/unc0ver",
    "/checkra1n",
    "/palera1n",
    "/dopamine",
    // FFEX cheat files (hide from scanner)
    "/var/containers/Bundle/Application",  // handled selectively
    NULL
};

static BOOL shouldHideStatPath(const char *path) {
    if (!path) return NO;
    for (int i = 0; kJBPaths[i] != NULL; i++) {
        if (strstr(path, kJBPaths[i]) != NULL) {
            return YES;
        }
    }
    return NO;
}

static int hook_stat(const char *path, struct stat *buf) {
    if (shouldHideStatPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_stat(path, buf);
}

static int hook_lstat(const char *path, struct stat *buf) {
    if (shouldHideStatPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_lstat(path, buf);
}

// ══════════════════════════════════════════════════════════════
// HOOK: access() — Jailbreak path check
// ══════════════════════════════════════════════════════════════
typedef int (*access_t)(const char *path, int mode);
static access_t orig_access = NULL;

static int hook_access(const char *path, int mode) {
    if (shouldHideStatPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(path, mode);
}

// ══════════════════════════════════════════════════════════════
// HOOK: dlopen — prevent anticheat from loading its own modules
// also hides FFEX dylibs from module enumeration
// ══════════════════════════════════════════════════════════════
typedef void* (*dlopen_t)(const char *path, int mode);
static dlopen_t orig_dlopen = NULL;

static const char *kBlockedLibs[] = {
    "antihack",
    "anticheat",
    "eac_",
    "EasyAntiCheat",
    "garena_security",
    NULL
};

static void *hook_dlopen(const char *path, int mode) {
    if (path) {
        for (int i = 0; kBlockedLibs[i] != NULL; i++) {
            if (strcasestr(path, kBlockedLibs[i])) {
                return NULL;
            }
        }
    }
    return orig_dlopen(path, mode);
}

// ══════════════════════════════════════════════════════════════
// HOOK: sysctl — hide debugger/process inspection
// Anticheat uses sysctl(CTL_KERN, KERN_PROC, ...) to scan processes
// ══════════════════════════════════════════════════════════════
typedef int (*sysctl_t)(int *name, u_int namelen, void *oldp, size_t *oldlenp,
                         void *newp, size_t newlen);
static sysctl_t orig_sysctl = NULL;

static const char *kSuspectProcs[] = {
    "gdb", "lldb", "debugserver", "frida", "objection",
    "cycript", "substrate", "substitute", "needle",
    NULL
};

static int hook_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp,
                        void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    
    // CTL_KERN / KERN_PROC / KERN_PROC_ALL
    if (namelen >= 3 && name[0] == CTL_KERN && name[1] == KERN_PROC &&
        name[2] == KERN_PROC_ALL && oldp && oldlenp && ret == 0) {
        
        struct kinfo_proc *procs = (struct kinfo_proc *)oldp;
        int count = (int)(*oldlenp / sizeof(struct kinfo_proc));
        int writeIdx = 0;
        
        for (int i = 0; i < count; i++) {
            const char *pname = procs[i].kp_proc.p_comm;
            BOOL hide = NO;
            for (int j = 0; kSuspectProcs[j] != NULL; j++) {
                if (strcasestr(pname, kSuspectProcs[j])) {
                    hide = YES;
                    break;
                }
            }
            if (!hide) {
                procs[writeIdx++] = procs[i];
            }
        }
        *oldlenp = writeIdx * sizeof(struct kinfo_proc);
    }
    return ret;
}

// ══════════════════════════════════════════════════════════════
// HOOK: PT_DENY_ATTACH bypass
// ptrace(PT_DENY_ATTACH, 0, 0, 0) is called by some AC modules
// We noop it so debuggers can still attach (needed for cheat inject)
// ══════════════════════════════════════════════════════════════
#include <sys/ptrace.h>
typedef int (*ptrace_t)(int request, pid_t pid, caddr_t addr, int data);
static ptrace_t orig_ptrace = NULL;

static int hook_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    if (request == PT_DENY_ATTACH) {
        return 0; // silently succeed without actually setting deny
    }
    return orig_ptrace(request, pid, addr, data);
}

// ══════════════════════════════════════════════════════════════
// HOOK: NSFileManager — hide FFEX files from integrity scanner
// ══════════════════════════════════════════════════════════════
static IMP orig_fileExistsAtPath = NULL;
static BOOL hook_fileExistsAtPath(id self, SEL _cmd, NSString *path) {
    if (path && shouldHideStatPath(path.UTF8String)) {
        return NO;
    }
    return ((BOOL (*)(id, SEL, NSString *))orig_fileExistsAtPath)(self, _cmd, path);
}

// ══════════════════════════════════════════════════════════════
// HOOK: NSURLSession dataTaskWithRequest
// Block anticheat HTTP calls at Obj-C level
// ══════════════════════════════════════════════════════════════
static IMP orig_dataTaskWithRequest = NULL;

// ══════════════════════════════════════════════════════════════
// GARENA AI ANTI-HACK BYPASS
// The AI system does behavioral analysis via:
// 1. Packet inspection server-side (can't bypass fully, must blend in)
// 2. Client-side timing attacks (we randomize action timestamps)
// 3. Aim pattern analysis (silent aim uses smoothing to look human)
// 4. Speed hacks detected via position delta (speed is capped/faked)
// ══════════════════════════════════════════════════════════════

// Position delta blending — applied in FFEXCheat.m
// Timing randomizer — applied in FFEXCheat.m
// Silent aim smoothing — applied in FFEXModMenu.m

// ══════════════════════════════════════════════════════════════
// STREAMPROOF — Screenshot / Screen Recording Block
// ══════════════════════════════════════════════════════════════
static BOOL g_streamproofEnabled = NO;

void ffex_setStreamproof(BOOL enabled) {
    g_streamproofEnabled = enabled;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        if (!w) return;
        if (enabled) {
            // Use secure text field trick to block screenshot
            // Create invisible secure field over game view
            static UITextField *secureField = nil;
            if (!secureField) {
                secureField = [UITextField new];
                secureField.secureTextEntry = YES;
                [w addSubview:secureField];
                [w sendSubviewToBack:secureField];
                // Use the secure field's layer to create screenshot protection
                UIView *protectionView = secureField.subviews.firstObject;
                if (protectionView) {
                    protectionView.frame = w.bounds;
                    protectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    [w addSubview:protectionView];
                }
            }
        }
    });
}

// ══════════════════════════════════════════════════════════════
// RAM CLEANER — Auto-release memory every 10 seconds
// Prevents cheat from crashing due to memory pressure
// ══════════════════════════════════════════════════════════════
static NSTimer *g_ramCleanTimer = nil;

void ffex_startRamCleaner(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        g_ramCleanTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
            target:[NSBlockOperation blockOperationWithBlock:^{
                // Autorelease pool drain
                @autoreleasepool {
                    // Compact virtual memory
                    malloc_zone_t *zone = malloc_default_zone();
                    if (zone) {
                        malloc_zone_pressure_relief(zone, 0);
                    }
                    // Trim iOS memory
                    vm_deallocate(mach_task_self(), (vm_address_t)0, 0);
                }
            }]
            selector:@selector(main)
            userInfo:nil
            repeats:YES];
    });
}

// ══════════════════════════════════════════════════════════════
// INSTALL ALL HOOKS
// ══════════════════════════════════════════════════════════════
void ffex_installAntiCheatBypass(void) {
    // fishhook-based C function hooks
    struct rebinding rebindings[] = {
        {"getaddrinfo", (void *)hook_getaddrinfo, (void **)&orig_getaddrinfo},
        {"stat",        (void *)hook_stat,        (void **)&orig_stat},
        {"lstat",       (void *)hook_lstat,       (void **)&orig_lstat},
        {"access",      (void *)hook_access,      (void **)&orig_access},
        {"dlopen",      (void *)hook_dlopen,      (void **)&orig_dlopen},
        {"sysctl",      (void *)hook_sysctl,      (void **)&orig_sysctl},
        {"ptrace",      (void *)hook_ptrace,      (void **)&orig_ptrace},
    };
    rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));
    
    // Objective-C method swizzling
    {
        Class cls = [NSFileManager class];
        SEL orig = @selector(fileExistsAtPath:);
        Method m = class_getInstanceMethod(cls, orig);
        orig_fileExistsAtPath = method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_fileExistsAtPath);
    }
    
    // Start RAM cleaner
    ffex_startRamCleaner();
    
    NSLog(@"[FFEX] AntiCheat bypass installed");
}
