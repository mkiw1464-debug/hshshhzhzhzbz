// FFEX IOS - Free Fire External Cheat for iOS
// Target: Free Fire v1.132.1 (GameAssembly.dylib)
// Dumped from: Free_Fire-1_132_1.ipa
// Dump source: dump.cs (Il2Cpp)
// Platform: iOS 15-18+
// Architecture: ARM64

#pragma once
#include <stdint.h>

// =============================================================
// CLASS OFFSETS (from dump.cs)
// =============================================================

// Player class : AttackableEntity (TypeDefIndex: 31767)
// Player -> IODLOCEJIOK (PlayerAttributes) at 0x768
// Player -> KGMHJLLMHJG (PropertyData) at 0x788

// Bone nodes (ITransformNode) in Player:
#define OFFSET_PLAYER_NODE_HEAD         0x6D0  // EPDCPFACIPG (head transform node)
#define OFFSET_PLAYER_NODE_CHEST        0x6D8  // GBKFHDFCPMD
#define OFFSET_PLAYER_NODE_BODY         0x6E0  // COBFGNOIPMF
#define OFFSET_PLAYER_NODE_NECK         0x6E8  // FFFPCADFFGA
#define OFFSET_PLAYER_NODE_LEFTSHOULDER 0x6F0  // CBHHCCNKOND
#define OFFSET_PLAYER_NODE_RIGHTSHOULDER 0x6F8 // CFMDINAGALM
#define OFFSET_PLAYER_NODE_LEG          0x700  // BDMMCNJOHNI (Transform)

// Player state/flags
#define OFFSET_PLAYER_IS_KNOCKED        0x1258 // IsKnockedDownBleed (bool)
#define OFFSET_PLAYER_IS_KNOCKED2       0x1259 // IsKnockDownBleedingFromGS (bool)
#define OFFSET_PLAYER_GET_IN_VEHICLE    0x4F8  // m_GetInVehicle (bool)
#define OFFSET_PLAYER_IS_IN_ZEPPELIN    0x2EC  // isInZeppelin (bool)
#define OFFSET_PLAYER_SPEED             0x560  // Speed (float)
#define OFFSET_PLAYER_IS_CADET          0x400  // IsCadet (bool)
#define OFFSET_PLAYER_IS_CLIENT_BOT     0x4A0  // IsClientBot (bool)
#define OFFSET_PLAYER_FROZEN_KNOCKDOWN  0xB0   // IsFrozenKnockDown (bool)
#define OFFSET_PLAYER_TEAM_MAP_MARK     0x52C  // TeamMapMark (Vector3)

// Player identity
#define OFFSET_PLAYER_ORIG_NICKNAME     0x498  // OriginalNickName (string)
#define OFFSET_PLAYER_TEAM_MODE_ID      0x434  // TeamModeID (uint)

// PlayerAttributes at 0x768 from Player
#define OFFSET_ATTR_BASE                0x768  // PlayerAttributes* in Player
// PlayerAttributes.BDOEGBMMEOK = owner Player at 0x20 (unused)
#define OFFSET_ATTR_EFFECTOWNER         0x1A8  // EffectOwner (BEADLMGGGGL = PlayerID)

// HP / Health system via rep data
// m_CurHp: found at offset 0xE4 (uint) in line 360291
// m_CurMaxHp: found at offset 0xE8 (uint) in line 360292
#define OFFSET_REP_CUR_HP               0xE4   // m_CurHp (uint) — RepData
#define OFFSET_REP_MAX_HP               0xE8   // m_CurMaxHp (uint) — RepData

// =============================================================
// AimAssist / Bone Helper
// =============================================================
// ITransformNode -> position accessed via vtable
// Transform offset in ITransformNode vtable slot 0
#define OFFSET_TRANSFORM_POSITION       0x90   // UnityEngine.Transform local position

// BEADLMGGGGL = PlayerID struct (size 0x18, ulong at 0x0)
#define OFFSET_PLAYERID_ULONG           0x0

// =============================================================
// GAMEOBJECT / ENTITY
// =============================================================
// UnityEngine internals (ARM64 iOS, Unity 2019.x base)
#define OFFSET_GO_TRANSFORM             0x10   // GameObject -> Transform*
#define OFFSET_TRANSFORM_LOCALPOS       0x58   // Transform localPosition (Vector3)
#define OFFSET_TRANSFORM_LOCALROT       0x64   // Transform localRotation (Quaternion)
#define OFFSET_COMPONENT_GO             0x10   // Component -> GameObject*

// =============================================================
// NETWORKING / REPLICATION
// =============================================================
// COWReplicationEntity (parent chain)
// ReplicationEntity has entity list manager

// =============================================================
// ESP DISTANCES
// =============================================================
#define ESP_MAX_DISTANCE_DEFAULT        200.0f // metres
#define ESP_MAX_DISTANCE_MAX            300.0f

// =============================================================
// OFFSETS SUMMARY TABLE
// Verified from dump.cs Free Fire 1.132.1
// =============================================================
/*
  Player class starts at runtime base + il2cpp class pointer
  
  Key fields:
  +0xB0   IsFrozenKnockDown     bool
  +0x400  IsCadet               bool
  +0x4A0  IsClientBot           bool
  +0x498  OriginalNickName      System.String*
  +0x434  TeamModeID            uint32
  +0x560  Speed                 float
  +0x768  IODLOCEJIOK           PlayerAttributes*
  +0x788  KGMHJLLMHJG           PropertyData*
  +0x6D0  EPDCPFACIPG           ITransformNode* (head)
  +0x6D8  GBKFHDFCPMD           ITransformNode* (chest/neck)
  +0x1258 IsKnockedDownBleed    bool
  +0x2EC  isInZeppelin          bool
  +0x4F8  m_GetInVehicle        bool

  PlayerAttributes (from ATTR_BASE):
  +0x1A8  EffectOwner           BEADLMGGGGL (PlayerID, 0x18 bytes)

  HP (RepData, separate class):
  +0xE4   m_CurHp               uint32
  +0xE8   m_CurMaxHp            uint32
*/
