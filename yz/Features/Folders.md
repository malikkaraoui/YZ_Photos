---
tags: [feature, dossiers, navigation, scope]
---

# Onglet Dossiers

> Retour : [[YZPhotos]]

## FolderBrowserView

Navigation hiérarchique dans l'arborescence du SSD.

```
NavigationStack (unique — MediaGridScreen passé en embedded:true)
└── FolderLevelView(prefix: "")   ← racine
    ├── Section actions
    │   ├── Stats du dossier (N fichiers, X Go)
    │   ├── [📷 Voir les fichiers] → MediaGridScreen(embedded:true, scope: prefix)
    │   └── [🃏 Trier ce dossier] → TriageDeckView(scope: prefix) en fullScreenCover
    └── Section sous-dossiers
        └── ForEach folderEntries(prefix:)
            └── NavigationLink → FolderLevelView(prefix: sous-dossier)
```

## FolderEntry (agrégats récursifs)

```swift
struct FolderEntry {
    let name: String        // nom du dossier (sans chemin parent)
    let prefix: String      // chemin relatif complet
    let fileCount: Int      // fichiers dans CE dossier et tous ses sous-dossiers
    let totalBytes: Int64   // taille totale récursive
    let hasSubfolders: Bool // pour afficher la flèche NavigationLink
}
```

## Paquets .photoslibrary

Affichés comme dossiers normaux (avec leurs stats), mais sans exposer
l'arborescence interne. Le titre affiche le nom du paquet (ex: "Photos Library").
Le scope pointe vers `<nom>.photoslibrary/originals/`.

## Piège résolu : double NavigationStack

`MediaGridScreen` crée son propre `NavigationStack` quand `embedded = false`.
Quand il est poussé depuis `FolderBrowserView`, il faut passer `embedded: true`
pour éviter qu'un stack soit imbriqué dans un autre (ce qui gelait la navigation).

```swift
// Dans FolderLevelView
MediaGridScreen(
    drive: drive,
    root: root,
    filter: filter,
    scope: prefix,
    scopeTitle: folderName,
    embedded: true          // ← CRITIQUE
)
```
