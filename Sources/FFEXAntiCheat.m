// FFEX IOS - AntiCheat Bypass
// iOS 15-18+, arm64

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <netdb.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <malloc/malloc.h>
#include "FFEXCore.h"

// ptrace — declare manual, iOS SDK tiada header
extern int ptrace(int, pid_t, caddr_t, int);
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

// ─── Blocked domains ─────────────────────────────────────────
static const char *kDomains[] = {
    "antihack.garena.com","anticheat.garena.com",
    "security.garena.com","sdk-security.garena.com",
    "ac.garena.com","cheat-detect.garena.com",
    "telemetry.garena.com","ai-antihack.garena.com",
    "ml-anticheat.garena.com","behaviour.garena.com",
    "behaviour-analysis.garena.com","easyanticheat.net",
    "api.easyanticheat.net","metrics.easyanticheat.net",
    NULL
};
static BOOL domainBlocked(const char *h) {
    if (!h) return NO;
    for (int i=0; kDomains[i]; i++)
        if (strcasestr(h, kDomains[i])) return YES;
    return NO;
}

// ─── Blocked JB paths ────────────────────────────────────────
static const char *kJBPaths[] = {
    "/Applications/Cydia.app","/Applications/Sileo.app",
    "/Library/MobileSubstrate","/usr/sbin/sshd",
    "/private/var/lib/apt","/private/var/stash",
    "/var/jb","/taurine","/odyssey","/chimera",
    "/unc0ver","/checkra1n","/palera1n","/dopamine",
    NULL
};
static BOOL pathHidden(const char *p) {
    if (!p) return NO;
    for (int i=0; kJBPaths[i]; i++)
        if (strstr(p, kJBPaths[i])) return YES;
    return NO;
}

// ─── Original function pointers ──────────────────────────────
typedef int   (*t_getaddrinfo)(const char*, const char*,
                                const struct addrinfo*, struct addrinfo**);
typedef int   (*t_stat)(const char*, struct stat*);
typedef int   (*t_lstat)(const char*, struct stat*);
typedef int   (*t_access)(const char*, int);
typedef void* (*t_dlopen)(const char*, int);
typedef int   (*t_sysctl)(int*, u_int, void*, size_t*, void*, size_t);
typedef int   (*t_ptrace)(int, pid_t, caddr_t, int);

static t_getaddrinfo orig_getaddrinfo;
static t_stat        orig_stat;
static t_lstat       orig_lstat;
static t_access      orig_access;
static t_dlopen      orig_dlopen;
static t_sysctl      orig_sysctl;
static t_ptrace      orig_ptrace;

// ─── Hooks ───────────────────────────────────────────────────
static int hook_getaddrinfo(const char *h, const char *s,
                             const struct addrinfo *hints, struct addrinfo **res) {
    if (domainBlocked(h)) { if (res) *res=NULL; return EAI_NONAME; }
    return orig_getaddrinfo(h, s, hints, res);
}
static int hook_stat(const char *p, struct stat *b) {
    if (pathHidden(p)) { errno=ENOENT; return -1; }
    return orig_stat(p, b);
}
static int hook_lstat(const char *p, struct stat *b) {
    if (pathHidden(p)) { errno=ENOENT; return -1; }
    return orig_lstat(p, b);
}
static int hook_access(const char *p, int m) {
    if (pathHidden(p)) { errno=ENOENT; return -1; }
    return orig_access(p, m);
}
static const char *kBadLibs[] = {
    "antihack","anticheat","eac_","EasyAntiCheat","garena_security",NULL
};
static void *hook_dlopen(const char *p, int m) {
    if (p) for (int i=0; kBadLibs[i]; i++)
        if (strcasestr(p, kBadLibs[i])) return NULL;
    return orig_dlopen(p, m);
}
static const char *kBadProcs[] = {
    "gdb","lldb","debugserver","frida","objection","cycript",NULL
};
static int hook_sysctl(int *n, u_int nl, void *op, size_t *ol,
                        void *np, size_t nl2) {
    int r = orig_sysctl(n, nl, op, ol, np, nl2);
    if (nl>=3 && n[0]==CTL_KERN && n[1]==KERN_PROC &&
        n[2]==KERN_PROC_ALL && op && ol && r==0) {
        struct kinfo_proc *pr = (struct kinfo_proc*)op;
        int cnt=(int)(*ol/sizeof(*pr)), wi=0;
        for (int i=0; i<cnt; i++) {
            BOOL hide=NO;
            for (int j=0; kBadProcs[j]; j++)
                if (strcasestr(pr[i].kp_proc.p_comm, kBadProcs[j]))
                    { hide=YES; break; }
            if (!hide) pr[wi++]=pr[i];
        }
        *ol = wi*sizeof(*pr);
    }
    return r;
}
static int hook_ptrace(int req, pid_t pid, caddr_t addr, int data) {
    if (req == PT_DENY_ATTACH) return 0;
    return orig_ptrace(req, pid, addr, data);
}

// ─── NSFileManager swizzle ───────────────────────────────────
static IMP orig_fileExists = NULL;
static BOOL hook_fileExists(id self, SEL _cmd, NSString *path) {
    if (path && pathHidden(path.UTF8String)) return NO;
    return ((BOOL(*)(id,SEL,NSString*))orig_fileExists)(self, _cmd, path);
}

// ─── arm64 inline hook ───────────────────────────────────────
static void patchFn(const char *sym, void *hook, void **orig) {
    void *fn = dlsym(RTLD_DEFAULT, sym);
    if (!fn) return;
    *orig = fn;
    vm_address_t page = (vm_address_t)fn & ~0xFFFULL;
    vm_protect(mach_task_self(), page, 0x1000, NO,
               VM_PROT_READ|VM_PROT_WRITE|VM_PROT_EXECUTE);
    // LDR X16, #8 ; BR X16 ; <addr 8 bytes>
    uint32_t patch[4];
    patch[0] = 0x58000050;
    patch[1] = 0xD61F0200;
    memcpy(&patch[2], &hook, 8);
    memcpy(fn, patch, sizeof(patch));
    vm_protect(mach_task_self(), page, 0x1000, NO,
               VM_PROT_READ|VM_PROT_EXECUTE);
    // Flush instruction cache — arm64 manual
    __asm__ __volatile__("dsb ish" ::: "memory");
    __asm__ __volatile__("isb" ::: "memory");
}

// ─── RAM cleaner ─────────────────────────────────────────────
static NSTimer *g_ramTimer = nil;
static void startRamCleaner(void) {
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

// ─── Streamproof ─────────────────────────────────────────────
void ffex_setStreamproof(BOOL on) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        if (!w) return;
        static UITextField *sf = nil;
        if (on && !sf) {
            sf = [UITextField new];
            sf.secureTextEntry = YES;
            [w addSubview:sf];
            UIView *pv = sf.subviews.firstObject;
            if (pv) {
                pv.frame = w.bounds;
                pv.autoresizingMask = UIViewAutoresizingFlexibleWidth|
                                      UIViewAutoresizingFlexibleHeight;
                [w addSubview:pv];
            }
        } else if (!on && sf) {
            [sf removeFromSuperview]; sf = nil;
        }
    });
}

// ─── Install ─────────────────────────────────────────────────
void ffex_installAntiCheatBypass(void) {
    orig_getaddrinfo = (t_getaddrinfo)dlsym(RTLD_DEFAULT,"getaddrinfo");
    orig_stat        = (t_stat)       dlsym(RTLD_DEFAULT,"stat");
    orig_lstat       = (t_lstat)      dlsym(RTLD_DEFAULT,"lstat");
    orig_access      = (t_access)     dlsym(RTLD_DEFAULT,"access");
    orig_dlopen      = (t_dlopen)     dlsym(RTLD_DEFAULT,"dlopen");
    orig_sysctl      = (t_sysctl)     dlsym(RTLD_DEFAULT,"sysctl");
    orig_ptrace      = (t_ptrace)     dlsym(RTLD_DEFAULT,"ptrace");

    patchFn("getaddrinfo",(void*)hook_getaddrinfo,(void**)&orig_getaddrinfo);
    patchFn("stat",       (void*)hook_stat,       (void**)&orig_stat);
    patchFn("lstat",      (void*)hook_lstat,      (void**)&orig_lstat);
    patchFn("access",     (void*)hook_access,     (void**)&orig_access);
    patchFn("dlopen",     (void*)hook_dlopen,     (void**)&orig_dlopen);
    patchFn("sysctl",     (void*)hook_sysctl,     (void**)&orig_sysctl);
    patchFn("ptrace",     (void*)hook_ptrace,     (void**)&orig_ptrace);

    Method m = class_getInstanceMethod([NSFileManager class],
                                       @selector(fileExistsAtPath:));
    orig_fileExists = method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_fileExists);

    startRamCleaner();
    NSLog(@"[FFEX] AC bypass installed");
}
