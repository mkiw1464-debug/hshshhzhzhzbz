# FFEX IOS — Free Fire External Cheat (iOS)

**Target:** Free Fire v1.132.1  
**Platform:** iOS 15 / 16 / 17 / 18 / 26 / 27  
**Install:** GBox / Esign / Sideloadly / AppInstaller (no jailbreak)  
**Channel:** [t.me/ffexternal](https://t.me/ffexternal)

---

## Struktur Fail

```
FFEX_IOS/
├── Sources/
│   ├── Offsets.h          — Semua offset dari dump.cs v1.132.1
│   ├── FFEXCore.h         — Header kongsi semua modul
│   ├── FFEXMain.m         — Entry point (constructor + AppDelegate hook)
│   ├── FFEXKeySystem.m    — Login page, key validation, language support
│   ├── FFEXAntiCheat.m    — DNS block, jailbreak hide, ptrace bypass
│   ├── FFEXCheat.m        — ESP, Aimbot, Speed, Fly, AutoFire logic
│   └── FFEXModMenu.m      — Glass UI mod menu + ESP overlay
├── Scripts/
│   └── build_ffex.sh      — Build + IPA patch pipeline
├── .github/workflows/
│   └── build.yml          — GitHub Actions CI/CD
├── FFEX.xcconfig          — Xcode build settings
└── README.md              — (ini)
```

---

## Injection Method

**Framework Embedding** (bukan dylib inject):

1. Compile `FFEX.framework` (Mach-O dylib, arm64)
2. Copy ke `FreeFire.app/Frameworks/FFEX.framework/`
3. Tambah `LC_LOAD_DYLIB` ke binary FreeFire via **optool**
4. Sign semula dengan **ldid / zsign**
5. Repack sebagai `.ipa`

Hasilnya boleh install tanpa jailbreak melalui app sideloader.

---

## Flow Pertama Kali

```
IPA dibuka → App launch → FFEX.framework loaded
    → AC bypass dipasang (ptrace/stat/DNS hooks)
    → Skrin game TIDAK load
    → LOGIN PAGE FFEX muncul (Portrait mode)
        → Header: FFEX IOS
        → Device model + iOS version
        → STATUS: ONLINE / OFFLINE
        → Pilih bahasa: EN / ID / VI / PT / CN / AR
        → Masukkan license key
        → Tekan LOGIN
        → [Jika betul] "KEY VERIFIED ✓" → Loading:
            ├── INSTALLING ASSETS...     [progress bar]
            ├── INSTALLING ANTICHEAT...  [progress bar]
            └── LOADING FREE FIRE...    [progress bar]
        → Game load dalam mode Landscape biasa
        → [FFEX cheat aktif di background]

    → 3 jari × 3 ketuk = Pop up mod menu
```

---

## Ciri-Ciri

### ESP
| Ciri | Status |
|---|---|
| ESP ON/OFF | ✅ |
| ESP LINE (merah=knock, hijau=hidup) | ✅ |
| ESP BOX (corner style) | ✅ |
| ESP NAME (background merah/hijau) | ✅ |
| ESP HEALTH (bar + nombor) | ✅ |
| ESP DISTANCE | ✅ |
| ENEMY COUNT (atas skrin) | ✅ |
| ESP DISTANCE slider 0-300m | ✅ |

### AIM
| Ciri | Status |
|---|---|
| AIM ON/OFF | ✅ |
| AIMBOT ON/OFF | ✅ |
| SELECT TARGET PART (Head/Neck/Chest/Body/Leg) | ✅ |
| DRAW FOV circle | ✅ |
| FOV RADIUS slider 0-500 | ✅ |
| AIM FOV ON/OFF | ✅ |
| AIM SILENT (silent aim dalam FOV) | ✅ |

### MISC
| Ciri | Status |
|---|---|
| SPEED RUN X2 ⚠️RISK | ✅ |
| FAST FIRE ⚠️RISK | ✅ |
| FAST MEDKIT ⚠️RISK | ✅ |
| FAST REVIVE ⚠️RISK | ✅ |
| AUTO FIRE ⚠️RISK | ✅ |
| FLY (spam jump = naik) ⚠️RISK | ✅ |

### SETTINGS
| Ciri | Status |
|---|---|
| Key expiry countdown | ✅ |
| Key day created | ✅ |
| Channel info: t.me/ffexternal | ✅ |
| STREAMPROOF (block screenshot/record) | ✅ |
| AUTO LOGOUT bila key expired | ✅ |

---

## AntiCheat Bypass

| Bypass | Method |
|---|---|
| Jailbreak detection | `stat`/`lstat`/`access` hooks — hide JB paths |
| ptrace(PT_DENY_ATTACH) | Hook `ptrace` → noop |
| Process scan (sysctl) | Filter debug proc names |
| DNS anticheat domains | `getaddrinfo` hook → NXDOMAIN |
| HTTP anticheat calls | NSURLSession filter |
| Module enum | `dlopen` hook — block AC libs |
| File integrity | `NSFileManager` swizzle |
| RAM auto-clean | 10s timer `malloc_zone_pressure_relief` |

---

## Build

```bash
# Prerequisite: macOS + Xcode CLI + optool + ldid/zsign
brew install ldid zsign
brew install optool

# Build dan patch IPA
./Scripts/build_ffex.sh /path/to/FreeFire-1_132_1.ipa

# Output: FFEX_FreeFire_YYYYMMDD.ipa (~1GB+)
```

### GitHub Actions

Push ke `main` → auto build framework  
`workflow_dispatch` dengan `ipa_url` → full IPA patch + upload artifact

---

## Offsets (v1.132.1)

Semua offset dalam `Sources/Offsets.h`, diperolehi dari `dump.cs`:

```
Player class (TypeDefIndex: 31767)
  +0x4A0  IsClientBot (bool)
  +0x1258 IsKnockedDownBleed (bool)
  +0x434  TeamModeID (uint)
  +0x498  OriginalNickName (string)
  +0x560  Speed (float)
  +0x768  PlayerAttributes*
  +0x6D0  Head ITransformNode*
  +0x6D8  Chest ITransformNode*
  +0x6E0  Body ITransformNode*
  +0x6E8  Neck ITransformNode*

RepData (HP)
  +0xE4   m_CurHp (uint)
  +0xE8   m_CurMaxHp (uint)
```

---

## Key System

API: `https://ffexxxx.vercel.app/app/api/licenses/validate`

- POST `{"key": "XXXXX"}`  
- Response: `{"valid": true, "expires_at": "...", "created_at": "..."}`
- Key disimpan secara tempatan (offline login selepas verify pertama)
- Auto logout bila key expired

---

## Nota Keselamatan

Ciri bertanda **⚠️RISK** dikesan server-side oleh Garena AI Antihack.  
Gunakan dengan berhati-hati. Channel Telegram untuk update bypass terbaru.
