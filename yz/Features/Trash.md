---
tags: [feature, corbeille, suppression, restauration]
---

# Corbeille (onglet Corbeille)

> Retour : [[YZPhotos]]

## Principe de la corbeille différée

```
Swipe gauche / bouton Poubelle
    → TrashManager.moveToTrash(file, driveRoot)
        → FileManager.moveItem(at: src, to: .YZTrash/<id>_<filename>)
        → rename same-volume → O(1), instantané
        → status = .trashed en DB
        → trashName stocké pour retrouver le fichier

Restauration
    → TrashManager.restoreFromTrash(file, driveRoot)
        → moveItem(at: .YZTrash/<trashName>, to: originalPath)
        → status = .untriaged en DB

Suppression définitive
    → TrashManager.deletePermanently(file, driveRoot)
        → FileManager.removeItem
        → status = .deleted en DB
```

## Structure .YZTrash

```
<racine SSD>/
└── .YZTrash/
    ├── 42_IMG_1234.HEIC
    ├── 43_VID_5678.MOV
    └── ...
```

Noms collision-proof : `<fileId>_<originalFileName>`

## TrashView — actions disponibles

### Mode normal
- Tap sur vignette → aperçu dans FilePreviewPane
- Bouton **↩** (topLeading de chaque vignette) → restaure ce fichier
- Toolbar : **🗑 Vider la corbeille (libérer X Go)** + confirmation

### Mode sélection (appui long)
- Toggle sélection par tap
- Toolbar :
  - **Annuler** + **Tout sélectionner** / **Tout désélectionner**
  - **✕** désélectionner direct (primaryAction)
  - **↩ Restaurer (N)** orange
  - **✕ Supprimer définitivement (N · X Go)** rouge + confirmation
  - **🗑 Vider la corbeille** (secondaryAction, toujours disponible)

## Alerte de confirmation post-suppression

```swift
alert("Suppression définitive") {
    Text("\(count) fichiers supprimés · \(bytes) libérés.")
}
```

## TriageService — méthodes corbeille

```swift
func trashAll(_ files: [FileRecord]) async throws
func restoreAll(_ files: [FileRecord]) async throws
func deletePermanently(_ files: [FileRecord]) async throws -> (count: Int, bytes: Int64)
func emptyTrash() async throws -> (count: Int, bytes: Int64)
func keepBest(of group: [FileRecord]) async throws
```

`changeTick` incrémenté après chaque mutation → toutes les vues se rafraîchissent automatiquement.
