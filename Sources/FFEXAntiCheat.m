// FFEX IOS - AntiCheat Bypass
// iOS 15-18+, arm64
// Guna rebind_symbols tanpa fishhook.h external â
// implement sendiri menggunakan dyld API terus

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/ptrace.h>
#include <netdb.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <mach-o/loader.h>
#include <malloc/malloc.h>
#include "FFEXCore.h"

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// MINI FISHHOOK â guna dyld_stub_binder table terus
// Tanpa bergantung pada fishhook.h luaran
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
static void *ffex_find_symbol(const char *name) {
    return dlsym(RTLD_DEFAULT, name);
}

// Simpan pointer original functions
typedef int  (*t_getaddrinfo)(const char *, const char *, const struct addrinfo *, struct addrinfo **);
typedef int  (*t_stat)(const char *, struct stat *);
typedef int  (*t_lstat)(const char *, struct stat *);
typedef int  (*t_access)(const char *, int);
typedef void*(*t_dlopen)(const char *, int);
typedef int  (*t_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
typedef int  (*t_ptrace)(int, pid_t, caddr_t, int);

static t_getaddrinfo orig_getaddrinfo;
static t_stat        orig_stat;
static t_lstat       orig_lstat;
static t_access      orig_access;
static t_dlopen      orig_dlopen;
static t_sysctl      orig_sysctl;
static t_ptrace      orig_ptrace;

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// BLOCKED DOMAINS
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
static const char *kBlockedDomains[] = {
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
    "telemetry.garena.com",
    "analytics-security.garena.com",
    "cheat-detect.garena.com",
    "easyanticheat.net",
    "api.easyanticheat.net",
    "metrics.easyanticheat.net",
    "ai-antihack.garena.com",
    "ml-anticheat.garena.com",
    "behaviour.garena.com",
    "behaviour-analysis.garena.com",
    NULL
};

static BOOL isDomainBlocked(const char *h) {
    if (!h) return NO;
    for (int i = 0; kBlockedDomains[i]; i++)
        if (strcasestr(h, kBlockedDomains[i])) return YES;
    return NO;
}

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// BLOCKED JB PATHS
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
static const char *kJBPaths[] = {
    "/Applications/Cydia.app",  "/Applications/Sileo.app",
    "/Applications/Zebra.app",  "/Library/MobileSubstrate",
    "/usr/sbin/sshd",           "/private/var/lib/apt",
    "/private/var/stash",       "/var/jb",
    "/var/LIB",                 "/private/preboot/jb",
    "/taurine",                 "/odyssey",
    "/chimera",                 "/unc0ver",
    "/checkra1n",               "/palera1n",
    "/dopamine",                "/private/etc/apt",
    "/.bootstrapped_electra",   NULL
};

static BOOL shouldHidePath(const char *p) {
    if (!p) return NO;
    for (int i = 0; kJBPaths[i]; i++)
        if (strstr(p, kJBPaths[i])) return YES;
    return NO;
}

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// HOOK IMPLEMENTATIONS
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
static int hook_getaddrinfo(const char *host, const char *serv,
                             const struct addrinfo *hints, struct addrinfo **res) {
    if (isDomainBlocked(host)) { if (res) *res=NULL; return EAI_NONAME; }
    return orig_getaddrinfo(host, serv, hints, res);
}

static int hook_stat(const char *path, struct stat *buf) {
    if (shouldHidePath(path)) { errno=ENOENT; return -1; }
    return orig_stat(path, buf);
}

static int hook_lstat(const char *path, struct stat *buf) {
    if (shouldHidePath(path)) { errno=ENOENT; return -1; }
    return orig_lstat(path, buf);
}

static int hook_access(const char *path, int mode) {
    if (shouldHidePath(path)) { errno=ENOENT; return -1; }
    return orig_access(path, mode);
}

static const char *kBlockedLibs[] = {
    "antihack","anticheat","eac_","EasyAntiCheat","garena_security", NULL
};
static void *hook_dlopen(const char *path, int mode) {
    if (path) for (int i=0; kBlockedLibs[i]; i++)
        if (strcasestr(path, kBlockedLibs[i])) return NULL;
    return orig_dlopen(path, mode);
}

static const char *kSuspectProcs[] = {
    "gdb","lldb","debugserver","frida","objection","cycript",NULL
};
static int hook_sysctl(int *name, u_int nlen, void *oldp, size_t *olen,
                        void *newp, size_t nlen2) {
    int r = orig_sysctl(name, nlen, oldp, olen, newp, nlen2);
    if (nlen>=3 && name[0]==CTL_KERN && name[1]==KERN_PROC &&
        name[2]==KERN_PROC_ALL && oldp && olen && r==0) {
        struct kinfo_proc *procs = (struct kinfo_proc *)oldp;
        int cnt = (int)(*olen / sizeof(struct kinfo_proc));
        int wi  = 0;
        for (int i=0; i<cnt; i++) {
            BOOL hide=NO;
            for (int j=0; kSuspectProcs[j]; j++)
                if (strcasestr(procs[i].kp_proc.p_comm, kSuspectProcs[j]))
                    { hide=YES; break; }
            if (!hide) procs[wi++] = procs[i];
        }
        *olen = wi * sizeof(struct kinfo_proc);
    }
    return r;
}

static int hook_ptrace(int req, pid_t pid, caddr_t addr, int data) {
    if (req == PT_DENY_ATTACH) return 0;
    return orig_ptrace(req, pid, addr, data);
}

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// ObjC SWIZZLE â NSFileManager
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
static IMP orig_fileExists = NULL;
static BOOL hook_fileExists(id self, SEL _cmd, NSString *path) {
    if (path && shouldHidePath(path.UTF8String)) return NO;
    return ((BOOL(*)(id,SEL,NSString*))orig_fileExists)(self, _cmd, path);
}

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// STREAMPROOF
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
void ffex_setStreamproof(BOOL enabled) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        if (!w) return;
        static UITextField *secField = nil;
        if (enabled && !secField) {
            secField = [UITextField new];
            secField.secureTextEntry = YES;
            [w addSubview:secField];
            UIView *prot = secField.subviews.firstObject;
            if (prot) {
                prot.frame = w.bounds;
                prot.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
                [w addSubview:prot];
            }
        } else if (!enabled && secField) {
            [secField removeFromSuperview];
            secField = nil;
        }
    });
}

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// RAM CLEANER
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
static NSTimer *g_ramTimer = nil;
static void ffex_startRamCleaner(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        g_ramTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
            target:[NSBlockOperation blockOperationWithBlock:^{
                @autoreleasepool {
                    malloc_zone_t *z = malloc_default_zone();
                    if (z) malloc_zone_pressure_relief(z, 0);
                }
            }]
            selector:@selector(main) userInfo:nil repeats:YES];
    });
}

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// HOOK INSTALLER â guna MSHookFunction jika ada,
// atau method pointer replacement terus
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
static void hookFunc(const char *sym, void *hook, void **orig) {
    void *fn = dlsym(RTLD_DEFAULT, sym);
    if (!fn) return;
    *orig = fn;
    // Tukar page protection â writable â tulis branch instruction â restore
    vm_address_t page = (vm_address_t)fn & ~0xFFF;
    vm_protect(mach_task_self(), page, 0x1000, NO,
               VM_PROT_READ|VM_PROT_WRITE|VM_PROT_EXECUTE);
    // arm64 branch patch: LDR X16, #8; BR X16; <hook addr>
    uint32_t patch[4];
    patch[0] = 0x58000050; // LDR X16, #8
    patch[1] = 0xD61F0200; // BR X16
    memcpy(&patch[2], &hook, 8);
    memcpy(fn, patch, sizeof(patch));
    vm_protect(mach_task_self(), page, 0x1000, NO,
               VM_PROT_READ|VM_PROT_EXECUTE);
    __builtin___clear_cache(fn, (char*)fn + sizeof(patch));
}

// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
// INSTALL
// ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
void ffex_installAntiCheatBypass(void) {
    // Save originals dulu
    orig_getaddrinfo = (t_getaddrinfo)dlsym(RTLD_DEFAULT, "getaddrinfo");
    orig_stat        = (t_stat)       dlsym(RTLD_DEFAULT, "stat");
    orig_lstat       = (t_lstat)      dlsym(RTLD_DEFAULT, "lstat");
    orig_access      = (t_access)     dlsym(RTLD_DEFAULT, "access");
    orig_dlopen      = (t_dlopen)     dlsym(RTLD_DEFAULT, "dlopen");
    orig_sysctl      = (t_sysctl)     dlsym(RTLD_DEFAULT, "sysctl");
    orig_ptrace      = (t_ptrace)     dlsym(RTLD_DEFAULT, "ptrace");

    // Patch functions
    hookFunc("getaddrinfo", (void*)hook_getaddrinfo, (void**)&orig_getaddrinfo);
    hookFunc("stat",        (void*)hook_stat,        (void**)&orig_stat);
    hookFunc("lstat",       (void*)hook_lstat,       (void**)&orig_lstat);
    hookFunc("access",      (void*)hook_access,      (void**)&orig_access);
    hookFunc("dlopen",      (void*)hook_dlopen,      (void**)&orig_dlopen);
    hookFunc("sysctl",      (void*)hook_sysctl,      (void**)&orig_sysctl);
    hookFunc("ptrace",      (void*)hook_ptrace,      (void**)&orig_ptrace);

    // NSFileManager swizzle
    Method m = class_getInstanceMethod([NSFileManager class],
                                       @selector(fileExistsAtPath:));
    orig_fileExists = method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_fileExists);

    ffex_startRamCleaner();
    NSLog(@"[FFEX] AntiCheat bypass installed");
}
