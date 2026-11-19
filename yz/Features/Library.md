---
tags: [feature, grille, photos, videos, captures, taille]
---

# Grilles média (Photos / Vidéos / Captures / Par taille)

> Retour : [[YZPhotos]]

## MediaGridScreen

Vue générique partagée par les 4 onglets.

```swift
MediaGridScreen(
    drive: drive,
    root: root,
    filter: .photos,        // .photos / .videos / .screenshots / .bySize
    scope: nil,             // dossier optionnel
    scopeTitle: nil,
    embedded: false         // true si dans FolderBrowserView (évite double NavigationStack)
)
```

## ThumbnailCell

Vignette carrée avec overlays :
- **Voile coloré** si `dupGroupId != nil` (même couleur pour tout le groupe)
- **Cadre épais** de la couleur du groupe
- **Ponts latéraux** `joinsPrevious` / `joinsNext` si deux membres adjacents
- **Badge durée** pour les vidéos
- **Badge taille** si `showSize` ou vidéo
- **✓ vert** si `status == .kept`
- **Icône square.on.square** si doublon

Palette de couleurs doublons (8 couleurs, stable par `groupId % 8`) :
`.orange, .pink, .cyan, .yellow, .mint, .indigo, .red, .teal`

## Interactions

| Geste | Mode normal | Mode sélection |
|-------|-------------|----------------|
| Tap | Aperçu dans FilePreviewPane | Toggle sélection |
| Appui long | Entre en mode sélection | — |
| Pinch | Resize cellules (80–400pt) | Resize cellules |

## Mode sélection multiple

Activé par appui long. Toolbar :
- **Annuler** (cancellationAction)
- **Tout sélectionner** / **Tout désélectionner** (secondaryAction)
- **✕** désélectionner direct (primaryAction)
- **✓ Garder (N)** vert (primaryAction)
- **🗑 Poubelle (N · X Go)** rouge (primaryAction)

## Tri (GridOrder)

```swift
enum GridOrder: String, CaseIterable, Identifiable {
    case byFolder   = "Par dossier"     // chemin relatif
    case bySizeDesc = "Par taille"      // sizeBytes DESC
    case byDateDesc = "Par date"        // captureDate DESC
    case byKind     = "Par type"        // kind, sizeBytes DESC
}
```

Menu « ⇅ Ranger » dans la toolbar (mode non-sélection).

## FilePreviewPane — MasterDetailLayout

- Colonne gauche : grille
- Colonne droite : aperçu du fichier sélectionné **ou** SelectionSummaryPane
- `SelectionSummaryPane` : N fichiers, taille totale, décompte photos/vidéos
- Zoom pinch jusqu'à ×6, double-tap reset

## Pagination

`LibraryViewModel` charge par pages de 200. `loadMoreIfNeeded(current:)` déclenché
par `.onAppear` sur chaque cellule. Reload avec `keepCount = max(200, files.count)`
pour préserver la position de défilement.
