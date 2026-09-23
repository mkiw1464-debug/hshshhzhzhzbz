// FFEX IOS - Core Header
// Shared declarations between all modules
#pragma once

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ─── Shared structs (defined ONCE here, used everywhere) ──────
typedef struct { float x, y, z; }    FFVec3;
typedef struct { float x, y; }       FFVec2;
typedef struct { float x, y, z, w; } FFQuat;

typedef struct FFEXFeatures {
    // ESP
    BOOL  espEnabled;
    BOOL  espBox;
    BOOL  espLine;
    BOOL  espName;
    BOOL  espHealth;
    BOOL  espDistance;
    float espMaxDistance;
    // AIM
    BOOL     aimEnabled;
    BOOL     aimbotEnabled;
    BOOL     drawFov;
    float    fovRadius;
    BOOL     aimFov;
    BOOL     aimSilent;
    NSInteger targetPart;
    // MISC
    BOOL speedRun;
    BOOL fastFire;
    BOOL fastMedkit;
    BOOL fastRevive;
    BOOL autoFire;
    BOOL fly;
    // SETTINGS
    BOOL streamproof;
} FFEXFeatures;

typedef struct FFEXPlayer {
    uintptr_t playerPtr;
    FFVec3    worldPos;
    FFVec3    headPos;
    FFVec3    chestPos;
    FFVec3    bodyPos;
    FFVec3    neckPos;
    FFVec3    legPos;
    NSString  * __unsafe_unretained nickname;
    uint32_t  curHp;
    uint32_t  maxHp;
    BOOL      isKnocked;
    BOOL      isBot;
    BOOL      isLocalPlayer;
    uint32_t  teamID;
    float     distance;
    FFVec2    screenPos;
    FFVec2    screenHead;
    FFVec2    screenFoot;
    float     screenH;
    float     screenW;
    BOOL      screenVisible;
} FFEXPlayer;

// ─── AntiCheat ────────────────────────────────────────────────
void ffex_installAntiCheatBypass(void);
void ffex_setStreamproof(BOOL enabled);

// ─── Cheat Core ───────────────────────────────────────────────
void              ffex_initCheat(void);
void              ffex_update(uintptr_t localPlayerPtr, uintptr_t entityListPtr);
FFEXFeatures     *ffex_getFeatures(void);
NSArray          *ffex_getEntityList(void);
NSInteger         ffex_getEnemyCount(void);
void              ffex_processAimbot(CGPoint crosshairScreen);
void              ffex_processAutoFire(CGPoint crosshairScreen);
void              ffex_processFly(uintptr_t localPlayerPtr, BOOL jumpPressed);

// ─── Key System ───────────────────────────────────────────────
void ffex_installLoginPage(void);

// ─── Mod Menu ─────────────────────────────────────────────────
void ffex_installModMenu(void);

// ─── Game Hooks ───────────────────────────────────────────────
void ffex_installGameHooks(void);
