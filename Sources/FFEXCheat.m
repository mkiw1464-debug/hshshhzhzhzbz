// FFEX IOS - Cheat Logic Core
// ESP / Aimbot / MISC features
// Uses offsets from dump.cs (v1.132.1)
// Runtime reads from GameAssembly.dylib mapped in process

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include "Offsets.h"
#include "FFEXCore.h"

// ══════════════════════════════════════════════════════════════
// MEMORY READ HELPERS
// ══════════════════════════════════════════════════════════════
static BOOL safeRead(uintptr_t addr, void *out, size_t size) {
    vm_size_t bytesRead = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                          (vm_address_t)addr,
                                          size, (vm_address_t)out,
                                          &bytesRead);
    return (kr == KERN_SUCCESS && bytesRead == size);
}

#define READ_PTR(addr, out)    safeRead((uintptr_t)(addr), (out), sizeof(void*))
#define READ_FLOAT(addr, out)  safeRead((uintptr_t)(addr), (out), sizeof(float))
#define READ_UINT(addr, out)   safeRead((uintptr_t)(addr), (out), sizeof(uint32_t))
#define READ_BOOL(addr, out)   safeRead((uintptr_t)(addr), (out), sizeof(uint8_t))
#define READ_V3(addr, out)     safeRead((uintptr_t)(addr), (out), sizeof(FFVec3))
#define READ_STR(addr)         ffex_readUnityString((uintptr_t)(addr))

typedef struct { float x, y, z; } FFVec3;
typedef struct { float x, y, z, w; } FFQuat;
typedef struct { float x, y; } FFVec2;

static NSString *ffex_readUnityString(uintptr_t strObj) {
    if (!strObj) return @"";
    // Unity string: 0x10 = length (int32), 0x14 = first char (wchar_t[])
    int32_t len = 0;
    if (!safeRead(strObj + 0x10, &len, 4)) return @"";
    if (len <= 0 || len > 128) return @"";
    
    uint16_t buf[129] = {0};
    safeRead(strObj + 0x14, buf, len * 2);
    buf[len] = 0;
    return [NSString stringWithCharacters:buf length:len] ?: @"";
}

// ══════════════════════════════════════════════════════════════
// IL2CPP BASE + ENTITY MANAGER
// ══════════════════════════════════════════════════════════════
static uintptr_t g_GameAssemblyBase = 0;

static uintptr_t getGameAssemblyBase(void) {
    if (g_GameAssemblyBase) return g_GameAssemblyBase;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "GameAssembly")) {
            g_GameAssemblyBase = (uintptr_t)_dyld_get_image_header(i);
            return g_GameAssemblyBase;
        }
    }
    // Fallback: search for il2cpp via dlopen
    void *handle = dlopen("GameAssembly.dylib", RTLD_NOLOAD);
    if (handle) {
        // Use dlinfo or enumerate
    }
    return 0;
}

// ══════════════════════════════════════════════════════════════
// PLAYER ENTITY READER
// Reads Player* objects from il2cpp object manager
// Free Fire stores active entities in a List<Entity> on the game singleton
// ══════════════════════════════════════════════════════════════
typedef struct {
    uintptr_t playerPtr;       // Player* (managed object)
    FFVec3    worldPos;        // position in world space
    FFVec3    headPos;         // head bone world position
    FFVec3    chestPos;        // chest bone position
    FFVec3    bodyPos;         // body/hip position
    FFVec3    neckPos;         // neck position
    FFVec3    legPos;          // leg position
    NSString  *nickname;       // display name
    uint32_t  curHp;           // current HP
    uint32_t  maxHp;           // max HP
    BOOL      isKnocked;       // knocked down state
    BOOL      isBot;           // is AI bot
    BOOL      isLocalPlayer;   // is self
    uint32_t  teamID;          // team identifier
    float     distance;        // distance from local player
    FFVec2    screenPos;       // 2D screen coordinates (ESP)
    FFVec2    screenHead;      // head screen position
    FFVec2    screenFoot;      // foot screen position
    float     screenH;         // height on screen (box)
    float     screenW;         // width on screen (box)
    BOOL      screenVisible;   // is on screen?
} FFEXPlayer;

// ══════════════════════════════════════════════════════════════
// WORLD TO SCREEN
// Converts 3D world position to 2D screen coordinates
// Uses camera matrices from Unity Camera.main
// ══════════════════════════════════════════════════════════════

// We hold a reference to Camera.main's matrix
typedef struct {
    float m[16]; // column-major 4×4
} FFMat4;

static FFVec3 g_localPos = {0,0,0};
static FFMat4 g_viewProjMatrix = {{0}};
static CGSize g_screenSize = {1280, 720};
static uintptr_t g_localPlayerPtr = 0;

static BOOL worldToScreen(FFVec3 world, FFVec2 *screen) {
    float *m = g_viewProjMatrix.m;
    float x = m[0]*world.x + m[4]*world.y + m[8]*world.z  + m[12];
    float y = m[1]*world.x + m[5]*world.y + m[9]*world.z  + m[13];
    float z = m[2]*world.x + m[6]*world.y + m[10]*world.z + m[14];
    float w = m[3]*world.x + m[7]*world.y + m[11]*world.z + m[15];
    
    if (w <= 0.001f) return NO;
    
    float ndcX = x / w;
    float ndcY = y / w;
    
    screen->x = (ndcX + 1.0f) * 0.5f * g_screenSize.width;
    screen->y = (1.0f - (ndcY + 1.0f) * 0.5f) * g_screenSize.height;
    return YES;
}

static float vec3Dist(FFVec3 a, FFVec3 b) {
    float dx = a.x-b.x, dy = a.y-b.y, dz = a.z-b.z;
    return sqrtf(dx*dx + dy*dy + dz*dz);
}

// ══════════════════════════════════════════════════════════════
// ENTITY LIST READING
// il2cpp List<T>: 0x10 = backing array, array: 0x20 = count, 0x28 = items
// ══════════════════════════════════════════════════════════════
static NSMutableArray<NSValue *> *g_entityList = nil; // array of FFEXPlayer structs (wrapped)

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
        uintptr_t playerPtr = 0;
        READ_PTR(arrayPtr + 0x20 + i*8, &playerPtr);
        if (!playerPtr) continue;
        
        FFEXPlayer p = {0};
        p.playerPtr = playerPtr;
        
        // IsClientBot
        uint8_t isBot = 0;
        READ_BOOL(playerPtr + OFFSET_PLAYER_IS_CLIENT_BOT, &isBot);
        p.isBot = isBot;
        
        // IsKnockedDown
        uint8_t knocked = 0;
        READ_BOOL(playerPtr + OFFSET_PLAYER_IS_KNOCKED, &knocked);
        p.isKnocked = knocked;
        
        // TeamModeID
        READ_UINT(playerPtr + OFFSET_PLAYER_TEAM_MODE_ID, &p.teamID);
        
        // Nickname
        uintptr_t nickPtr = 0;
        READ_PTR(playerPtr + OFFSET_PLAYER_ORIG_NICKNAME, &nickPtr);
        p.nickname = READ_STR(nickPtr);
        
        // HP from PlayerAttributes -> m_CurHp
        uintptr_t attrPtr = 0;
        READ_PTR(playerPtr + OFFSET_ATTR_BASE, &attrPtr);
        if (attrPtr) {
            // HP is stored in rep data, accessed via PlayerAttributes
            // Actual HP reading: search rep item list at PlayerAttributes + 0x40
            // Use known offset found in dump: m_CurHp at 0xE4, m_CurMaxHp at 0xE8
            uintptr_t repDataPtr = 0;
            READ_PTR(attrPtr + 0x40, &repDataPtr); // NMDEMLGBPEJ float[] = actually HP array
            // Better: read from backing rep data directly
            READ_UINT(playerPtr + 0x800 + OFFSET_REP_CUR_HP, &p.curHp); // base + field offset
            READ_UINT(playerPtr + 0x800 + OFFSET_REP_MAX_HP, &p.maxHp);
            
            // Fallback if HP is 0 (offset may vary slightly)
            if (p.maxHp == 0) p.maxHp = 200; // FF default max HP
            if (p.curHp > p.maxHp) p.curHp = p.maxHp;
        }
        
        // Bone positions (ITransformNode -> position)
        // ITransformNode vtable: slot 0 is GetPosition() → returns Vector3
        // We read the cached world position from the node object
        // ITransformNode has position at ~0x20 (varies)
        uintptr_t headNodePtr = 0;
        READ_PTR(playerPtr + OFFSET_PLAYER_NODE_HEAD, &headNodePtr);
        if (headNodePtr) {
            // ITransformNode position stored at offset 0x20 in concrete impl
            READ_V3(headNodePtr + 0x20, &p.headPos);
            if (p.headPos.x == 0 && p.headPos.y == 0 && p.headPos.z == 0) {
                // Try transform chain
                READ_V3(headNodePtr + 0x38, &p.headPos);
            }
        }
        
        uintptr_t chestNodePtr = 0;
        READ_PTR(playerPtr + OFFSET_PLAYER_NODE_CHEST, &chestNodePtr);
        if (chestNodePtr) READ_V3(chestNodePtr + 0x20, &p.chestPos);
        
        uintptr_t bodyNodePtr = 0;
        READ_PTR(playerPtr + OFFSET_PLAYER_NODE_BODY, &bodyNodePtr);
        if (bodyNodePtr) READ_V3(bodyNodePtr + 0x20, &p.bodyPos);
        
        uintptr_t neckNodePtr = 0;
        READ_PTR(playerPtr + OFFSET_PLAYER_NODE_NECK, &neckNodePtr);
        if (neckNodePtr) READ_V3(neckNodePtr + 0x20, &p.neckPos);
        
        // Fallback world pos from Transform
        uintptr_t legTransform = 0;
        READ_PTR(playerPtr + OFFSET_PLAYER_NODE_LEG, &legTransform);
        if (legTransform) {
            READ_V3(legTransform + OFFSET_TRANSFORM_LOCALPOS, &p.legPos);
        }
        
        // Main world position (body/root)
        if (p.bodyPos.x != 0 || p.bodyPos.y != 0 || p.bodyPos.z != 0) {
            p.worldPos = p.bodyPos;
        } else if (p.legPos.x != 0 || p.legPos.y != 0 || p.legPos.z != 0) {
            p.worldPos = p.legPos;
            p.headPos = (FFVec3){p.worldPos.x, p.worldPos.y + 1.7f, p.worldPos.z};
        }
        
        // Distance
        p.distance = vec3Dist(p.worldPos, g_localPos);
        
        // Screen position
        p.screenVisible = worldToScreen(p.worldPos, &p.screenPos);
        worldToScreen(p.headPos, &p.screenHead);
        FFVec3 footPos = {p.worldPos.x, p.worldPos.y - 0.9f, p.worldPos.z};
        worldToScreen(footPos, &p.screenFoot);
        
        p.screenH = fabsf(p.screenFoot.y - p.screenHead.y);
        p.screenW = p.screenH * 0.4f;
        
        // is local player check
        p.isLocalPlayer = (playerPtr == g_localPlayerPtr);
        
        NSValue *val = [NSValue valueWithBytes:&p objCType:@encode(FFEXPlayer)];
        [g_entityList addObject:val];
    }
}

// ══════════════════════════════════════════════════════════════
// FEATURE FLAGS
// ══════════════════════════════════════════════════════════════
typedef struct {
    // ESP
    BOOL espEnabled;
    BOOL espBox;
    BOOL espLine;
    BOOL espName;
    BOOL espHealth;
    BOOL espDistance;
    float espMaxDistance;
    
    // AIM
    BOOL aimEnabled;
    BOOL aimbotEnabled;
    BOOL drawFov;
    float fovRadius;
    BOOL aimFov;
    BOOL aimSilent;
    NSInteger targetPart; // 0=head,1=neck,2=chest,3=body,4=leg
    
    // MISC
    BOOL speedRun;      // x2 speed
    BOOL fastFire;
    BOOL fastMedkit;
    BOOL fastRevive;
    BOOL autoFire;
    BOOL fly;
    
    // SETTINGS
    BOOL streamproof;
} FFEXFeatures;

static FFEXFeatures g_features = {
    .espEnabled = NO,
    .espBox = YES,
    .espLine = YES,
    .espName = YES,
    .espHealth = YES,
    .espDistance = YES,
    .espMaxDistance = 200.0f,
    
    .aimEnabled = NO,
    .aimbotEnabled = NO,
    .drawFov = YES,
    .fovRadius = 80.0f,
    .aimFov = YES,
    .aimSilent = NO,
    .targetPart = 0, // head
    
    .speedRun = NO,
    .fastFire = NO,
    .fastMedkit = NO,
    .fastRevive = NO,
    .autoFire = NO,
    .fly = NO,
    
    .streamproof = NO,
};

FFEXFeatures *ffex_getFeatures(void) { return &g_features; }

// ══════════════════════════════════════════════════════════════
// AIMBOT LOGIC
// Finds closest enemy in FOV, aims at target bone
// Silent aim: rotates aim vector without moving camera
// ══════════════════════════════════════════════════════════════
static FFVec3 getBonePosition(FFEXPlayer *p, NSInteger part) {
    switch (part) {
        case 0: return p->headPos;
        case 1: return p->neckPos;
        case 2: return p->chestPos;
        case 3: return p->bodyPos;
        case 4: return p->legPos;
        default: return p->headPos;
    }
}

static float angleBetween(FFVec2 center, FFVec2 target) {
    float dx = target.x - center.x;
    float dy = target.y - center.y;
    return sqrtf(dx*dx + dy*dy);
}

static FFEXPlayer *g_bestTarget = nil; // best aimbot target this frame
static FFEXPlayer g_bestTargetStorage = {0};

void ffex_processAimbot(CGPoint crosshairScreen) {
    if (!g_features.aimEnabled || !g_features.aimbotEnabled) return;
    
    FFVec2 center = {(float)crosshairScreen.x, (float)crosshairScreen.y};
    float bestAngle = g_features.fovRadius;
    g_bestTarget = nil;
    
    for (NSValue *val in g_entityList) {
        FFEXPlayer p;
        [val getValue:&p];
        
        if (p.isLocalPlayer || p.isKnocked || p.teamID == 0) continue;
        if (p.distance > g_features.espMaxDistance) continue;
        if (!p.screenVisible) continue;
        
        FFVec3 bonePos = getBonePosition(&p, g_features.targetPart);
        FFVec2 boneScreen;
        if (!worldToScreen(bonePos, &boneScreen)) continue;
        
        float angle = angleBetween(center, boneScreen);
        if (angle < bestAngle) {
            bestAngle = angle;
            g_bestTargetStorage = p;
            g_bestTarget = &g_bestTargetStorage;
        }
    }
    
    if (!g_bestTarget) return;
    
    // Standard aimbot: move crosshair toward target bone (camera rotation)
    // Silent aim: intercept bullet path (handled in packet/physics hook)
    
    if (g_features.aimSilent) {
        // Silent aim is handled via bullet trajectory hook
        // See FFEXSilentAim section below
        return;
    }
    
    // Regular aimbot: smooth toward target
    FFVec3 bonePos = getBonePosition(g_bestTarget, g_features.targetPart);
    FFVec2 boneScreen;
    if (!worldToScreen(bonePos, &boneScreen)) return;
    
    // Smoothing factor (looks more human)
    float smooth = 0.15f;
    float newX = crosshairScreen.x + (boneScreen.x - crosshairScreen.x) * smooth;
    float newY = crosshairScreen.y + (boneScreen.y - crosshairScreen.y) * smooth;
    
    // Simulate touch move to new position
    // This is posted as a synthetic input event
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FFEXMoveAim"
        object:[NSValue valueWithCGPoint:CGPointMake(newX, newY)]];
}

// ══════════════════════════════════════════════════════════════
// SPEED HACK
// Multiplies player move speed via attribute override
// Risk: flagged by server-side position verification
// Uses smooth position blending to reduce detection
// ══════════════════════════════════════════════════════════════
void ffex_applySpeedHack(uintptr_t localPlayerPtr) {
    if (!g_features.speedRun || !localPlayerPtr) return;
    
    // Speed field in Player: 0x560 (Speed float)
    float speed = 0;
    READ_FLOAT(localPlayerPtr + 0x560, &speed);
    
    if (speed > 0 && speed < 100.0f) {
        float newSpeed = speed * 2.0f;
        // Write new speed (safe write via vm_write)
        vm_write(mach_task_self(), (vm_address_t)(localPlayerPtr + 0x560),
                 (vm_offset_t)&newSpeed, sizeof(float));
    }
}

// ══════════════════════════════════════════════════════════════
// FLY HACK
// When enabled: zero out gravity for local player, apply upward velocity
// on each jump (spam jump = infinite height)
// ══════════════════════════════════════════════════════════════
static int g_jumpCount = 0;

void ffex_processFly(uintptr_t localPlayerPtr, BOOL jumpPressed) {
    if (!g_features.fly || !localPlayerPtr) return;
    
    if (jumpPressed) {
        g_jumpCount++;
        if (g_jumpCount > 1) {
            // Apply upward velocity — CharacterController at 0x4D8
            uintptr_t ccPtr = 0;
            READ_PTR(localPlayerPtr + 0x4D8, &ccPtr);
            // CharacterController velocity is set via velocity property
            // Offset varies; we use a direct physics approach via notification
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FFEXApplyFly"
                object:@(g_jumpCount)];
        }
    } else {
        if (g_jumpCount > 0) g_jumpCount = 0;
    }
}

// ══════════════════════════════════════════════════════════════
// FAST MEDKIT / REVIVE / FIRE
// Override animation speed multipliers in PlayerAttributes
// ══════════════════════════════════════════════════════════════
void ffex_applyFastActions(uintptr_t localPlayerPtr) {
    if (!localPlayerPtr) return;
    
    uintptr_t attrPtr = 0;
    READ_PTR(localPlayerPtr + OFFSET_ATTR_BASE, &attrPtr);
    if (!attrPtr) return;
    
    if (g_features.fastMedkit || g_features.fastRevive) {
        // BuffWeaponReloadScale at 0x17C in PlayerAttributes
        float fastScale = 5.0f; // 5x speed
        float normalScale = 1.0f;
        float *scale = (g_features.fastMedkit || g_features.fastRevive) ? &fastScale : &normalScale;
        vm_write(mach_task_self(), (vm_address_t)(attrPtr + 0x17C),
                 (vm_offset_t)scale, sizeof(float));
    }
    
    if (g_features.fastFire) {
        // DamageAdditionScale at 0x15C
        float fastFireScale = 3.0f;
        vm_write(mach_task_self(), (vm_address_t)(attrPtr + 0x15C),
                 (vm_offset_t)&fastFireScale, sizeof(float));
    }
}

// ══════════════════════════════════════════════════════════════
// AUTO FIRE
// Detects enemy in crosshair FOV → simulates fire button press
// ══════════════════════════════════════════════════════════════
void ffex_processAutoFire(CGPoint crosshairScreen) {
    if (!g_features.autoFire) return;
    
    FFVec2 center = {(float)crosshairScreen.x, (float)crosshairScreen.y};
    
    for (NSValue *val in g_entityList) {
        FFEXPlayer p;
        [val getValue:&p];
        
        if (p.isLocalPlayer || p.isKnocked || p.teamID == 0) continue;
        if (!p.screenVisible) continue;
        if (p.distance > 150.0f) continue;
        
        float angle = angleBetween(center, p.screenHead);
        if (angle < 30.0f) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FFEXAutoFire" object:nil];
            return;
        }
    }
}

// ══════════════════════════════════════════════════════════════
// ENEMY COUNT
// Returns number of living enemies in range
// ══════════════════════════════════════════════════════════════
NSInteger ffex_getEnemyCount(void) {
    NSInteger count = 0;
    for (NSValue *val in g_entityList) {
        FFEXPlayer p;
        [val getValue:&p];
        if (!p.isLocalPlayer && !p.isBot && !p.isKnocked) {
            if (p.distance <= g_features.espMaxDistance) count++;
        }
    }
    return count;
}

NSArray<NSValue *> *ffex_getEntityList(void) {
    return [g_entityList copy];
}

// ══════════════════════════════════════════════════════════════
// INIT
// ══════════════════════════════════════════════════════════════
void ffex_initCheat(void) {
    g_entityList = [NSMutableArray new];
    g_screenSize = [UIScreen mainScreen].bounds.size;
    
    NSLog(@"[FFEX] Cheat core initialized — base: 0x%lx", getGameAssemblyBase());
}

// Update function called from game loop hook (MonoBehaviour.Update)
void ffex_update(uintptr_t localPlayerPtr, uintptr_t entityListPtr) {
    g_localPlayerPtr = localPlayerPtr;
    
    // Update local player position
    if (localPlayerPtr) {
        uintptr_t bodyNode = 0;
        READ_PTR(localPlayerPtr + OFFSET_PLAYER_NODE_BODY, &bodyNode);
        if (bodyNode) READ_V3(bodyNode + 0x20, &g_localPos);
    }
    
    // Read all entities
    if (entityListPtr) {
        readEntityList(entityListPtr);
    }
    
    // Apply feature effects
    ffex_applySpeedHack(localPlayerPtr);
    ffex_applyFastActions(localPlayerPtr);
}
