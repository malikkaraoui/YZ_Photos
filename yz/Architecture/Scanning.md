---
tags: [architecture, scan, performance, memoire]
---

# Pipeline de scan

> Retour : [[YZPhotos]]

## Vue d'ensemble

```
FileEnumerator
    → AsyncStream<FileMeta>
        → Passe 1 : upsertBatch par lots 1000 (débloque l'UI immédiatement)
            → Passe 2 : TaskGroup 4 workers
                → HashWorker (partialHash → fullHash si collision)
                → ThumbnailStore.analyzePhoto / analyzeVideo
                → MediaClassifier.classify
                → applyAnalysisBatch par lots 200
```

## FileEnumerator

- `FileManager.enumerator` avec clés de ressource préchargées en une passe
- Détecte les paquets `.photoslibrary` → descend uniquement dans `originals/` et `Masters/`
- Ignore `.YZTrash` et les dossiers système
- Normalisation NFC des chemins relatifs (compatibilité exFAT / HFS+)

## HashWorker — SHA-256 étagé

```
1. partialHash = SHA-256(taille || head 64Ko || tail 64Ko)
   → élimine 99,9% des faux candidats, quasi-instantané
   → autoreleasepool sur chaque lecture pour éviter accumulation Data

2. fullHash = SHA-256 complet par blocs 1Mo
   → uniquement si deux fichiers ont le même partialHash
   → autoreleasepool par bloc (critique pour les vidéos lourdes)
```

## ThumbnailStore — cache double niveau

| Cache | Taille | Usage |
|-------|--------|-------|
| `memoryCache` (NSCache) | 250 entrées, 512px | Grilles |
| `cardCache` (NSCache) | 12 entrées, 1280px | Deck de tri |
| Disque | HEIC compressé | Persistant entre sessions |

## MediaClassifier — score captures d'écran

| Critère | Points |
|---------|--------|
| Extension PNG | +2 |
| Dimensions = écran Apple connu | +3 |
| Pas d'EXIF Make/Model | +2 |
| Nom contient "Screenshot" ou "Capture d'écran" | +3 |
| **Seuil** | **≥ 5 = capture** |

## ScanCoordinator — garde-mémoire

Utilise `task_vm_info` (phys_footprint) pour mesurer la RAM réelle :

```swift
// Limite douce : purge caches + sleep 500ms
if footprint > 2_200_000_000 { purgeMemoryCaches(); sleep }

// Limite dure : throw ScanMemoryError (arrêt propre)
if footprint > 3_200_000_000 { throw ScanMemoryError() }
```

Compteurs exposés à l'UI :
- `filesSeen`, `bytesSeen` — Passe 1
- `analyzedDone`, `analyzedTotal` — Passe 2
- `photosAnalyzed`, `videosAnalyzed`, `screenshotsFound`
- `rate` (fichiers/s), `etaSeconds`
- `memoryFootprintMB`
- `currentPath` — fichier en cours

## Lifecycle arrière-plan

```swift
// Entrée background : UIBackgroundTask (~30s de sursis)
func enteredBackground() {
    backgroundTaskID = UIApplication.shared.beginBackgroundTask { cancel() }
}

// Retour au premier plan : reprise automatique
func enteredForeground() {
    endBackgroundTask()
    if interruptedByBackground { start(drive:root:) }
}
```

## Idempotence

Le scan est reprenable : `pendingAnalysis` retourne uniquement les fichiers où `analyzedAt IS NULL`.
Si le scan est interrompu, la prochaine exécution reprend là où il s'est arrêté.
