---
tags: [architecture, swift, grdb, xcodegen]
---

# Stack technique

> Retour : [[YZPhotos]]

## Décisions validées (une seule option par sujet)

| Sujet | Choix | Raison |
|-------|-------|--------|
| Language | Swift 6 / SwiftUI | Natif iPadOS |
| OS min | iPadOS 18+ | Observation framework, TabView tabBarOnly |
| Build | XcodeGen (`project.yml`) | Pas de merge conflict sur `.pbxproj` |
| Accès SSD | `UIDocumentPickerViewController` | URL security-scoped + bookmark persisté |
| Persistance | GRDB (SQLite WAL) | Seule dépendance SPM — 10× plus rapide que SwiftData sur 100k+ lignes |
| Concurrence | Swift async/await + TaskGroup | 4 workers hash/miniatures |
| État UI | `@Observable` (Observation framework) | Remplace Combine |
| iPad only | `TARGETED_DEVICE_FAMILY = 2` | Pas d'iPhone |

## Fichiers clés

```
YZPhotos/
├── project.yml                        ← XcodeGen spec
├── YZPhotos/
│   ├── App/
│   │   ├── YZPhotosApp.swift          ← @main, scenePhase lifecycle
│   │   ├── AppEnvironment.swift       ← composition root
│   │   ├── AppSettings.swift          ← UserDefaults @Observable
│   │   ├── RootView.swift             ← portail disque
│   │   ├── MainTabView.swift          ← 12 onglets
│   │   └── Formatters.swift           ← Fmt.bytes/count/duration/date/eta
│   ├── Core/
│   │   ├── Database/                  ← AppDatabase, Records, Queries, FileStore
│   │   ├── DriveAccess/               ← DriveIdentity, DriveAccessManager
│   │   ├── Hashing/                   ← DHash, BKTree
│   │   ├── Scanning/                  ← FileEnumerator, HashWorker, MediaClassifier, ScanCoordinator
│   │   ├── Thumbnails/                ← ThumbnailStore
│   │   └── Trash/                     ← TrashManager, TriageService
│   └── Features/
│       ├── Triage/                    ← TriageDeckView, SwipeCardView, TriageViewModel
│       ├── Library/                   ← MediaGridView, LibraryViewModel, FilePreviewPane, FileViewerSheet
│       ├── Folders/                   ← FolderBrowserView
│       ├── Duplicates/                ← DuplicateGroupsView, DuplicateFinder, DuplicateRunController
│       ├── TrashTab/                  ← TrashView
│       ├── Scan/                      ← ScanProgressView
│       ├── Stats/                     ← StatsDashboardView
│       ├── Settings/                  ← SettingsView
│       └── Spike/                     ← DriveChecksView (Phase 0, DEBUG only)
└── YZPhotosTests/                     ← DHash, BKTree, HashWorker, MediaClassifier, FileStore
```

## Concurrence

```
FileEnumerator (mono-tâche, AsyncStream)
    ↓
upsertBatch (actor DB, lots 1000)        ← Passe 1 — débloque l'UI
    ↓
pendingAnalysis (lignes sans analyzedAt)
    ↓
TaskGroup 4 workers                      ← Passe 2 — hash + miniatures + dHash
    ↓
applyAnalysisBatch (actor DB, lots 200)
```

## Build & déploiement

```bash
# Générer le .xcodeproj depuis project.yml
xcodegen generate

# Build + install sur iPad (WiFi)
xcodebuild -scheme YZPhotos \
           -destination "platform=iOS,name=iPad Air" \
           -allowProvisioningUpdates \
           build

xcrun devicectl device install app --device <UDID> YZPhotos.app
xcrun devicectl device process launch --device <UDID> com.malik.YZPhotos
```
