---
tags: [feature, reglages, dark-mode, autoplay]
---

# Onglet Réglages

> Retour : [[YZPhotos]]

## AppSettings

`@Observable`, stocké dans `UserDefaults`.

```swift
@Observable final class AppSettings {
    var appearance: Appearance = .system   // .system / .light / .dark
    var autoPlayVideos: Bool = true
    var defaultGridOrder: GridOrder = .byFolder
}
```

Injecté via `@Environment` dans toutes les vues.
`preferredColorScheme` appliqué au niveau de `RootView`.

## SettingsView — sections actuelles

### Apparence
- Picker Système / Clair / Sombre
- SF Symbol : `circle.lefthalf.filled`

### Lecture vidéo
- Toggle "Lancer automatiquement"
- SF Symbol : `play.circle`
- Utilisé par `FilePreviewPane`, `FileViewerSheet`, `TriageDeckView`

### Affichage
- Picker ordre par défaut : Par dossier / Par taille / Par date / Par type
- SF Symbol : `arrow.up.arrow.down`
- Appliqué à l'initialisation de `LibraryViewModel`

### Disques connus
- Liste des `DriveRecord` de la DB
- Indicateur ● vert si connecté (`env.driveAccess.state == .connected`)
- Stats par disque (N fichiers, X Go)
- Renommage par tap (TextField inline)
- **Éjecter / changer de disque** (juin 2026) :
  - Bouton « Éjecter » (rouge) sur le disque branché → `env.ejectDrive()`.
    Si un scan ou une recherche de doublons tourne, confirmation
    (`confirmationDialog`) avant d'interrompre — le travail est en base,
    la reprise est gratuite. Éjection → `DriveAccessManager.eject()` repasse
    en `.noDrive` → `RootView` affiche `WelcomeView`.
  - Bouton « Brancher » sur les autres disques connus → `env.switchDrive(to:)`
    (reconnect via bookmark, sans repasser par le picker). Échec → alerte.
  - Bouton « Brancher un autre disque… » → `fileImporter` → `env.attachNewDrive(pickedURL:)`.
  - Les trois passent par `AppEnvironment`, qui arrête d'abord scan +
    doublons + triage du disque courant avant de basculer.

### Stats avancées
- Toggle "Afficher plusieurs disques dans les stats"

## À faire (livrable Claude Design)

- [ ] Redesign complet selon HIG iPadOS 18
- [ ] Code SwiftUI final généré par Claude Design
