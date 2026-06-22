---
tags: [feature, analyse, scan, progression]
---

# Onglet Analyse

> Retour : [[YZPhotos]] | Architecture : [[Architecture/Scanning]]

## ScanTabView — layout

```
ScanTabView
├── ScanDetailView
│   ├── Carte "Étape 1/2 — Parcours du disque"
│   │   ├── ProgressView (indéterminée pendant l'énumération)
│   │   ├── "N fichiers · X Go vus"
│   │   └── currentPath (chemin en cours, tronqué)
│   ├── Carte "Étape 2/2 — Analyse"
│   │   ├── ProgressView(value: analyzedDone, total: analyzedTotal)
│   │   ├── "N / M analysés · X fichiers/s · ETA : Xm Xs"
│   │   ├── "N photos · M vidéos · K captures"
│   │   └── "RAM : X Mo"
│   └── Boutons Lancer / Pause / Arrêter / Relancer
└── Dernière analyse : "le JJ/MM/AAAA à HH:MM" (lu depuis la DB)
```

## ScanProgressBanner

Bandeau compact en bas de l'écran (overlay dans MainTabView).
- Tap → ouvre ScanTabView en sheet
- Affiche phase + progression condensée
- Visible uniquement si `env.scan.isRunning`

## Badge onglet

Point ● bleu sur l'onglet Analyse quand `env.scan.isRunning`.

## Phases du scan

```swift
enum Phase {
    case idle
    case enumerating    // Passe 1
    case analyzing      // Passe 2
    case finished
    case failed(String)
    case diskDisconnected
}
```

## Contrôles

| Bouton | Disponible | Action |
|--------|-----------|--------|
| Lancer | `.idle` ou `.finished` ou `.failed` | `ScanCoordinator.start(drive:root:)` |
| Mettre en pause | `.analyzing` | `ScanCoordinator.pause()` |
| Reprendre | `.analyzing` en pause | `ScanCoordinator.resume()` |
| Arrêter | `.enumerating` ou `.analyzing` | `ScanCoordinator.cancel()` |

## Dernière analyse

`lastScanCompletedAt` lu directement depuis la DB au chargement de la vue
(pas depuis le struct `DriveRecord` en mémoire qui peut être périmé) :

```swift
private func refreshLastCompleted() async {
    let driveId = drive.id
    lastCompleted = try? await env.database.writer.read { db in
        try DriveRecord.fetchOne(db, key: driveId)?.lastScanCompletedAt
    }
}
```
