# YZPhotos

Application **iPadOS native** pour trier et ranger plus d'1 To de photos et vidéos
stockées sur un **SSD externe** (Samsung T5/T7 en USB-C), sans tout copier sur l'iPad.

Pensée pour un usage quotidien sur **iPad Air M4 13"**, iPadOS 18+.

---

## Principe fondamental — poubelle différée

**Rien n'est supprimé sans confirmation explicite.**

- Swipe gauche / bouton Poubelle → le fichier est **déplacé** dans `.YZTrash/`
  (même volume, donc renommage O(1), instantané même sur un gros fichier).
- La suppression réelle n'a lieu **que** via « Vider la corbeille ».
- Restauration possible à tout moment tant que la corbeille n'est pas vidée.

---

## Fonctionnalités

| Domaine | Détail |
|---------|--------|
| **Analyse** | Scan en 2 passes : métadonnées d'abord (rapide), puis hash partiel + miniature + dHash + classification. Idempotent : un crash ou un débranchage reprend là où la base s'est arrêtée. |
| **Tri** | Deck façon Tinder — swipe garder / poubelle, avec annulation (undo) globale. |
| **Doublons** | Doublons exacts + quasi-doublons via **dHash + BK-tree + Union-Find**, regroupés avec sélection du meilleur (`keepBest`). |
| **Bibliothèque** | Grilles Photos / Vidéos / Captures / Par taille, multi-sélection, zoom. |
| **Dossiers** | Navigation hiérarchique avec drill-down (scope). |
| **Corbeille** | Restauration et suppression définitive. |
| **Stats** | Tableau de bord live (GRDB `ValueObservation`). |
| **Réglages** | Thème (système / clair / sombre), lecture auto des vidéos, ordre de grille par défaut, gestion multi-disques. |
| **Multi-disques** | Chaque disque est reconnu par son **identifiant unique** (UUID du volume) : ses statistiques, son tri et sa corbeille restent sur l'iPad même débranché. On peut **éjecter** le disque courant, **basculer** entre plusieurs disques, et **supprimer** définitivement un disque connu (avec confirmation — efface ses données locales, jamais le contenu du disque). Au lancement, l'app **redemande systématiquement** quel disque brancher au lieu de reconnecter le dernier en date. |

---

## Architecture

Composition par injection unique via `AppEnvironment` (racine `@Observable`).

```
YZPhotos/
├── App/                  Composition, réglages, point d'entrée, navigation
│   ├── AppEnvironment    Racine : possède tous les services (DB, scan, doublons…)
│   ├── AppSettings       Préférences persistées (UserDefaults)
│   ├── RootView          Picker disque → reconnexion → onglets
│   └── MainTabView       Onglets (Trier, Photos, Doublons, Corbeille, Réglages…)
├── Core/
│   ├── Database/         GRDB : AppDatabase, Records, Queries, FileStore
│   ├── DriveAccess/      Bookmarks security-scoped, identité de volume, éjection
│   ├── Hashing/          dHash + BK-tree
│   ├── Scanning/         Énumération, workers de hash, classification, ScanCoordinator
│   ├── Thumbnails/       Génération + cache mémoire (NSCache borné)
│   └── Trash/            Corbeille différée, service de tri (triage)
└── Features/             Une vue/ViewModel par domaine (Library, Triage, Duplicates…)
```

### Accès au disque

`DriveAccessManager` gère le cycle de vie complet :
- sélection via le picker système (`fileImporter`),
- **bookmark security-scoped** persisté en base → bascule en un tap vers un disque connu,
- **pas de reconnexion automatique au lancement** : l'app repart de l'écran de choix et redemande le disque à chaque ouverture (le bookmark ne sert qu'à la bascule explicite),
- détection de déconnexion (disque débranché en cours d'usage),
- **éjection volontaire**, **bascule** vers un autre disque connu, et **suppression** d'un disque (efface sa fiche et ses données locales en cascade).

Toute bascule (éjecter / brancher / changer de disque) **arrête d'abord proprement**
le scan, la recherche de doublons et le tri du disque courant — le travail déjà fait
est en base, la reprise est gratuite.

### Garde-fous mémoire

Le scan traite potentiellement des centaines de milliers de fichiers. Pour éviter le
kill système (Jetsam ~5 Go) :
- `autoreleasepool` autour des décodages ImageIO,
- workers d'analyse bornés à **4** (le goulot est l'USB, pas le CPU),
- caches `NSCache` plafonnés + purge aux points de contrôle mémoire,
- interruption propre **avant** la limite dure (2,2 Go souple / 3,2 Go dure),
- gestion du passage en arrière-plan (`beginBackgroundTask`) pour éviter le watchdog.

---

## Stack technique

| Item | Valeur |
|------|--------|
| Cible | iPad Air M4 13", iPadOS 18+ |
| UI | SwiftUI |
| Persistance | SQLite via **GRDB** (dépendance unique, SPM) |
| Génération projet | **XcodeGen** (`project.yml`) |
| Build | `xcodebuild` |

---

## Build

Le projet Xcode est généré depuis `project.yml` par XcodeGen. Après tout changement
de structure (ajout/suppression de fichiers, réglages) :

```sh
# Régénérer le projet
xcodegen generate

# Ouvrir dans Xcode
open YZPhotos.xcodeproj
```

Build en ligne de commande (cible iOS) :

```sh
xcodebuild build -scheme YZPhotos -destination 'generic/platform=iOS'
```

> Nécessite l'SDK **et** le composant plateforme iOS installés
> (Xcode › Settings › Components, ou `xcodebuild -downloadPlatform iOS`).

Tests unitaires (dHash, BK-tree, HashWorker, MediaClassifier, FileStore) :

```sh
xcodebuild test -scheme YZPhotos -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```

---

## État

MVP fonctionnel. Reste à faire (voir le vault Obsidian `Vault/`) :

- [ ] Icône de l'app (1024×1024)
- [ ] Redesign de l'écran Réglages
- [ ] Soumission App Store
- [ ] Live Photos (paires HEIC + MOV), partage/export, widget
</content>
</invoke>
