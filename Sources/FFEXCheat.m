// FFEX IOS - Cheat Logic Core
// ESP / Aimbot / MISC features
// Offsets from dump.cs v1.132.1

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include <math.h>
#include "FFEXCore.h"   // structs defined here — no redefine
#include "Offsets.h"

// ══════════════════════════════════════════════════════════════
// MEMORY READ HELPERS
// ══════════════════════════════════════════════════════════════
static BOOL safeRead(uintptr_t addr, void *out, size_t size) {
    if (!addr || !out) return NO;
    vm_size_t bytesRead = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                          (vm_address_t)addr,
                                          size,
                                          (vm_address_t)out,
                                          &bytesRead);
    return (kr == KERN_SUCCESS && bytesRead == size);
}

#define READ_PTR(addr, out)   safeRead((uintptr_t)(addr), (out), sizeof(void*))
#define READ_FLOAT(addr, out) safeRead((uintptr_t)(addr), (out), sizeof(float))
#define READ_UINT(addr, out)  safeRead((uintptr_t)(addr), (out), sizeof(uint32_t))
#define READ_BOOL(addr, out)  safeRead((uintptr_t)(addr), (out), sizeof(uint8_t))
#define READ_V3(addr, out)    safeRead((uintptr_t)(addr), (out), sizeof(FFVec3))

static NSString *ffex_readUnityString(uintptr_t strObj) {
    if (!strObj) return @"";
    int32_t len = 0;
    if (!safeRead(strObj + 0x10, &len, 4)) return @"";
    if (len <= 0 || len > 128) return @"";
    uint16_t buf[129] = {0};
    safeRead(strObj + 0x14, buf, (size_t)len * 2);
    buf[len] = 0;
    return [NSString stringWithCharacters:buf length:(NSUInteger)len] ?: @"";
}

// ══════════════════════════════════════════════════════════════
// GLOBALS
// ══════════════════════════════════════════════════════════════
static FFVec3  g_localPos        = {0,0,0};
static CGSize  g_screenSize      = {1280, 720};
static uintptr_t g_localPlayerPtr = 0;

typedef struct { float m[16]; } FFMat4;
static FFMat4 g_viewProjMatrix   = {{0}};

static NSMutableArray *g_entityList = nil;

// ══════════════════════════════════════════════════════════════
// WORLD TO SCREEN
// ══════════════════════════════════════════════════════════════
static BOOL worldToScreen(FFVec3 world, FFVec2 *screen) {
    float *m = g_viewProjMatrix.m;
    float x = m[0]*world.x + m[4]*world.y + m[8]*world.z  + m[12];
    float y = m[1]*world.x + m[5]*world.y + m[9]*world.z  + m[13];
    float w = m[3]*world.x + m[7]*world.y + m[11]*world.z + m[15];
    if (w <= 0.001f) return NO;
    screen->x = (x/w + 1.0f) * 0.5f * (float)g_screenSize.width;
    screen->y = (1.0f - (y/w + 1.0f) * 0.5f) * (float)g_screenSize.height;
    return YES;
}

static float vec3Dist(FFVec3 a, FFVec3 b) {
    float dx=a.x-b.x, dy=a.y-b.y, dz=a.z-b.z;
    return sqrtf(dx*dx + dy*dy + dz*dz);
}

// ══════════════════════════════════════════════════════════════
// ENTITY LIST
// ══════════════════════════════════════════════════════════════
static void readEntityList(uintptr_t listPtr) {
    if (!listPtr) return;
    uintptr_t arrayPtr = 0;
    READ_PTR(listPtr + 0x10, &arrayPtr);
    if (!arrayPtr) return;
    uint32_t count = 0;
    READ_UINT(arrayPtr + 0x18, &count);
    if (count == 0 || count > 512) return;

    [g_entityList removeAllObjects];

    for (uint32_t i = 0; i < count; i++) {
        uintptr_t ptr = 0;
        READ_PTR(arrayPtr + 0x20 + i*8, &ptr);
        if (!ptr) continue;

        FFEXPlayer p;
        memset(&p, 0, sizeof(p));
        p.playerPtr = ptr;

        uint8_t isBot = 0;  READ_BOOL(ptr + OFFSET_PLAYER_IS_CLIENT_BOT, &isBot);
        p.isBot = (BOOL)isBot;

        uint8_t knocked = 0; READ_BOOL(ptr + OFFSET_PLAYER_IS_KNOCKED, &knocked);
        p.isKnocked = (BOOL)knocked;

        READ_UINT(ptr + OFFSET_PLAYER_TEAM_MODE_ID, &p.teamID);

        uintptr_t nickPtr = 0;
        READ_PTR(ptr + OFFSET_PLAYER_ORIG_NICKNAME, &nickPtr);
        p.nickname = ffex_readUnityString(nickPtr);

        // HP
        READ_UINT(ptr + 0x800 + OFFSET_REP_CUR_HP, &p.curHp);
        READ_UINT(ptr + 0x800 + OFFSET_REP_MAX_HP, &p.maxHp);
        if (p.maxHp == 0) p.maxHp = 200;
        if (p.curHp > p.maxHp) p.curHp = p.maxHp;

        // Bone positions
        uintptr_t node = 0;
        READ_PTR(ptr + OFFSET_PLAYER_NODE_HEAD,  &node); if (node) READ_V3(node + 0x20, &p.headPos);
        READ_PTR(ptr + OFFSET_PLAYER_NODE_CHEST, &node); if (node) READ_V3(node + 0x20, &p.chestPos);
        READ_PTR(ptr + OFFSET_PLAYER_NODE_BODY,  &node); if (node) READ_V3(node + 0x20, &p.bodyPos);
        READ_PTR(ptr + OFFSET_PLAYER_NODE_NECK,  &node); if (node) READ_V3(node + 0x20, &p.neckPos);

        uintptr_t legT = 0;
        READ_PTR(ptr + OFFSET_PLAYER_NODE_LEG, &legT);
        if (legT) READ_V3(legT + OFFSET_TRANSFORM_LOCALPOS, &p.legPos);

        p.worldPos = (p.bodyPos.x||p.bodyPos.y||p.bodyPos.z) ? p.bodyPos : p.legPos;
        if (!p.headPos.x && !p.headPos.y && !p.headPos.z)
            p.headPos = (FFVec3){p.worldPos.x, p.worldPos.y+1.7f, p.worldPos.z};

        p.distance     = vec3Dist(p.worldPos, g_localPos);
        p.isLocalPlayer = (ptr == g_localPlayerPtr);
        p.screenVisible = worldToScreen(p.worldPos, &p.screenPos);
        worldToScreen(p.headPos, &p.screenHead);
        FFVec3 foot = {p.worldPos.x, p.worldPos.y-0.9f, p.worldPos.z};
        worldToScreen(foot, &p.screenFoot);
        p.screenH = fabsf(p.screenFoot.y - p.screenHead.y);
        p.screenW = p.screenH * 0.4f;

        NSValue *val = [NSValue valueWithBytes:&p objCType:@encode(FFEXPlayer)];
        [g_entityList addObject:val];
    }
}

// ══════════════════════════════════════════════════════════════
// FEATURE FLAGS
// ══════════════════════════════════════════════════════════════
static FFEXFeatures g_features = {
    .espEnabled      = NO,
    .espBox          = YES,
    .espLine         = YES,
    .espName         = YES,
    .espHealth       = YES,
    .espDistance     = YES,
    .espMaxDistance  = 200.0f,
    .aimEnabled      = NO,
    .aimbotEnabled   = NO,
    .drawFov         = YES,
    .fovRadius       = 80.0f,
    .aimFov          = YES,
    .aimSilent       = NO,
    .targetPart      = 0,
    .speedRun        = NO,
    .fastFire        = NO,
    .fastMedkit      = NO,
    .fastRevive      = NO,
    .autoFire        = NO,
    .fly             = NO,
    .streamproof     = NO,
};

FFEXFeatures *ffex_getFeatures(void) { return &g_features; }

// ══════════════════════════════════════════════════════════════
// AIMBOT
// ══════════════════════════════════════════════════════════════
static FFEXPlayer g_bestTargetStorage;
static FFEXPlayer *g_bestTarget = NULL;

static FFVec3 getBonePos(const FFEXPlayer *p, NSInteger part) {
    switch (part) {
        case 0: return p->headPos;
        case 1: return p->neckPos;
        case 2: return p->chestPos;
        case 3: return p->bodyPos;
        case 4: return p->legPos;
        default: return p->headPos;
    }
}

static float screenDist(FFVec2 a, FFVec2 b) {
    float dx=a.x-b.x, dy=a.y-b.y;
    return sqrtf(dx*dx+dy*dy);
}

void ffex_processAimbot(CGPoint crosshair) {
    if (!g_features.aimEnabled || !g_features.aimbotEnabled) return;
    FFVec2 center = {(float)crosshair.x, (float)crosshair.y};
    float best = g_features.fovRadius;
    g_bestTarget = NULL;

    for (NSValue *val in g_entityList) {
        FFEXPlayer p;
        [val getValue:&p];
        if (p.isLocalPlayer || p.isKnocked || p.teamID==0) continue;
        if (p.distance > g_features.espMaxDistance || !p.screenVisible) continue;
        FFVec3 bone = getBonePos(&p, g_features.targetPart);
        FFVec2 bScreen;
        if (!worldToScreen(bone, &bScreen)) continue;
        float ang = screenDist(center, bScreen);
        if (ang < best) {
            best = ang;
            g_bestTargetStorage = p;
            g_bestTarget = &g_bestTargetStorage;
        }
    }
    if (!g_bestTarget || g_features.aimSilent) return;

    FFVec3 bone = getBonePos(g_bestTarget, g_features.targetPart);
    FFVec2 bScreen;
    if (!worldToScreen(bone, &bScreen)) return;
    float smooth = 0.15f;
    float nx = crosshair.x + (bScreen.x - crosshair.x) * smooth;
    float ny = crosshair.y + (bScreen.y - crosshair.y) * smooth;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"FFEXMoveAim"
        object:[NSValue valueWithCGPoint:CGPointMake(nx, ny)]];
}

// ══════════════════════════════════════════════════════════════
// MISC
// ══════════════════════════════════════════════════════════════
void ffex_applySpeedHack(uintptr_t lp) {
    if (!g_features.speedRun || !lp) return;
    float spd = 0;
    READ_FLOAT(lp + 0x560, &spd);
    if (spd > 0 && spd < 100.0f) {
        float ns = spd * 2.0f;
        vm_write(mach_task_self(), (vm_address_t)(lp+0x560), (vm_offset_t)&ns, sizeof(float));
    }
}

void ffex_applyFastActions(uintptr_t lp) {
    if (!lp) return;
    uintptr_t attr = 0;
    READ_PTR(lp + OFFSET_ATTR_BASE, &attr);
    if (!attr) return;
    if (g_features.fastMedkit || g_features.fastRevive) {
        float s = 5.0f;
        vm_write(mach_task_self(), (vm_address_t)(attr+0x17C), (vm_offset_t)&s, sizeof(float));
    }
    if (g_features.fastFire) {
        float s = 3.0f;
        vm_write(mach_task_self(), (vm_address_t)(attr+0x15C), (vm_offset_t)&s, sizeof(float));
    }
}

static int g_jumpCount = 0;
void ffex_processFly(uintptr_t lp, BOOL jump) {
    if (!g_features.fly || !lp) return;
    if (jump) {
        g_jumpCount++;
        if (g_jumpCount > 1)
            [[NSNotificationCenter defaultCenter]
                postNotificationName:@"FFEXApplyFly" object:@(g_jumpCount)];
    } else {
        g_jumpCount = 0;
    }
}

void ffex_processAutoFire(CGPoint crosshair) {
    if (!g_features.autoFire) return;
    FFVec2 center = {(float)crosshair.x, (float)crosshair.y};
    for (NSValue *val in g_entityList) {
        FFEXPlayer p;
        [val getValue:&p];
        if (p.isLocalPlayer || p.isKnocked || p.teamID==0 || !p.screenVisible) continue;
        if (p.distance > 150.0f) continue;
        if (screenDist(center, p.screenHead) < 30.0f) {
            [[NSNotificationCenter defaultCenter]
                postNotificationName:@"FFEXAutoFire" object:nil];
            return;
        }
    }
}

NSInteger ffex_getEnemyCount(void) {
    NSInteger c = 0;
    for (NSValue *val in g_entityList) {
        FFEXPlayer p; [val getValue:&p];
        if (!p.isLocalPlayer && !p.isBot && !p.isKnocked && p.distance<=g_features.espMaxDistance)
            c++;
    }
    return c;
}

NSArray *ffex_getEntityList(void) { return [g_entityList copy]; }

// ══════════════════════════════════════════════════════════════
// INIT / UPDATE
// ══════════════════════════════════════════════════════════════
void ffex_initCheat(void) {
    g_entityList = [NSMutableArray new];
    g_screenSize = [UIScreen mainScreen].bounds.size;
    memset(&g_bestTargetStorage, 0, sizeof(g_bestTargetStorage));
    NSLog(@"[FFEX] Cheat core initialized");
}

void ffex_update(uintptr_t lp, uintptr_t entityListPtr) {
    g_localPlayerPtr = lp;
    if (lp) {
        uintptr_t node = 0;
        READ_PTR(lp + OFFSET_PLAYER_NODE_BODY, &node);
        if (node) READ_V3(node + 0x20, &g_localPos);
    }
    if (entityListPtr) readEntityList(entityListPtr);
    ffex_applySpeedHack(lp);
    ffex_applyFastActions(lp);
}
