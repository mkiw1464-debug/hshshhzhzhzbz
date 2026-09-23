// FFEX IOS - Core Header
// Shared declarations between all modules

#pragma once
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ─── Forward declarations ─────────────────────────────────────
typedef struct FFEXFeatures FFEXFeatures;
typedef struct FFEXPlayer FFEXPlayer;
typedef struct {float x,y,z;} FFVec3;
typedef struct {float x,y;} FFVec2;

// ─── AntiCheat ────────────────────────────────────────────────
void ffex_installAntiCheatBypass(void);
void ffex_setStreamproof(BOOL enabled);

// ─── Cheat Core ───────────────────────────────────────────────
void ffex_initCheat(void);
void ffex_update(uintptr_t localPlayerPtr, uintptr_t entityListPtr);
FFEXFeatures *ffex_getFeatures(void);
NSArray<NSValue *> *ffex_getEntityList(void);
NSInteger ffex_getEnemyCount(void);
void ffex_processAimbot(CGPoint crosshairScreen);
void ffex_processAutoFire(CGPoint crosshairScreen);
void ffex_processFly(uintptr_t localPlayerPtr, BOOL jumpPressed);

// ─── Key System ───────────────────────────────────────────────
void ffex_installLoginPage(void);

// ─── Mod Menu ─────────────────────────────────────────────────
void ffex_installModMenu(void);
