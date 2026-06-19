# YZPhotos

Application **iOS / iPadOS native (iPhone + iPad)** pour trier et ranger plus d'1 To de
photos et vidéos stockées sur un **SSD externe** (USB-C, ex. Samsung T5/T7) **ou un
disque réseau SMB** (Freebox / NAS), sans tout copier sur l'appareil.

Pensée pour un usage quotidien sur **iPad Air M4 13"** et **iPhone**, iOS/iPadOS 18+.

> **Version 1.0.0** (versioning sémantique). La version est affichée dans
> **Réglages → À propos**, et bumpée à chaque livraison de code.

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
| **Analyse** | Scan en 2 passes : métadonnées (rapide), puis empreinte / miniature / classification. **En réseau (SMB), scan « léger » : on n'ouvre que les fichiers de taille partagée** (seuls candidats aux doublons exacts), miniatures à la demande — évite d'ouvrir des dizaines de milliers de fichiers (T7 : 93 k fichiers scannés en ~18 min au lieu de ~3 h). Idempotent : un crash/débranchage reprend où la base s'est arrêtée. |
| **Tri** | Deck façon Tinder — swipe garder / poubelle, animations + haptique, annulation (undo) globale. |
| **Doublons** | Doublons **exacts** (taille → empreinte → hash complet sur collision). Quasi-doublons visuels (dHash + BK-tree + Union-Find) : **passe « Analyse approfondie » à la demande**, lourde et optionnelle — *mise de côté* tant qu'elle n'apporte pas un gain décisif. |
| **Bibliothèque** | Grilles Photos / Vidéos / Captures / Par taille, multi-sélection, zoom. |
| **Dossiers** | Navigation hiérarchique avec drill-down (scope). |
| **Corbeille** | Restauration et suppression définitive. |
| **Stats** | Tableau de bord live (GRDB `ValueObservation`). |
| **Design** | 3 thèmes : **Verre** (aurora translucide, défaut), **Clair**, **Sombre**. Icône d'app (Light/Dark/Tinted). |
| **Réglages** | Thème (Verre / Clair / Sombre), lecture auto des vidéos, ordre de grille par défaut, gestion multi-disques, **version de l'app**. |
| **Disque réseau (SMB)** | Client SMB2/3 **natif** (AMSMB2/libsmb2), indépendant de l'app Fichiers : connexion directe (serveur + identifiants **mémorisés**), navigateur de partages/dossiers, scan/tri/corbeille en réseau, reconnexion auto en cas de coupure de session. |
| **Multi-disques** | Chaque disque (USB **ou** réseau) est reconnu par un **identifiant unique** : statistiques, tri et corbeille restent sur l'appareil même débranché. **Éjecter** / **basculer** / **supprimer** un disque connu (efface ses données locales, jamais le contenu du disque). Au lancement, l'app **redemande** quel disque brancher. |

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
├── DesignSystem/         Thème 3 univers (Verre/Clair/Sombre), composants, fond aurora
├── Core/
│   ├── Database/         GRDB : AppDatabase, Records, Queries, FileStore
│   ├── DriveAccess/      USB (bookmarks security-scoped) + disque réseau (SMB), identité, éjection
│   ├── Network/          Client SMB natif (SMBStore, AMSMB2) + Keychain (mots de passe)
│   ├── Storage/          MediaStore : couche d'accès unifiée — Local (USB) / SMB (réseau)
│   ├── Hashing/          dHash + BK-tree
│   ├── Scanning/         Énumération, analyse (ScanCoordinator), HashWorker, classification
│   ├── Thumbnails/       Génération + cache mémoire (NSCache borné)
│   └── Trash/            Corbeille différée, service de tri (triage)
└── Features/             Une vue/ViewModel par domaine (Library, Triage, Duplicates, Network…)
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

**Disque réseau (SMB).** En plus de l'USB, on branche un partage SMB via un **client
natif** (`Core/Network/SMBStore`, AMSMB2/libsmb2) : connexion directe avec identifiants
(mémorisés ; mot de passe au **trousseau**), **sans** passer par l'app Fichiers d'iOS
(dont l'accès s'est révélé inutilisable pour scanner). Tout l'accès fichier (scan,
empreintes, miniatures, corbeille) passe par la couche unifiée **`MediaStore`**
(`LocalMediaStore` pour l'USB, `SMBMediaStore` pour le réseau), qui **se reconnecte
automatiquement** en cas de coupure de session. L'énumération saute les dossiers
cachés / système / dev (node_modules, .git…).

### Garde-fous mémoire

Le scan traite potentiellement des centaines de milliers de fichiers. Pour éviter le
kill système (Jetsam ~5 Go) :
- `autoreleasepool` autour des décodages ImageIO,
- workers d'analyse bornés : **4 en USB**, **1 en réseau** (1 fichier à la fois → la
  mémoire se vide entre chaque ; le scan léger n'ouvre de toute façon qu'une fraction),
- caches `NSCache` plafonnés + purge aux points de contrôle mémoire,
- **arrêt propre et reprenable** si la limite dure est atteinte (jamais de kill système),
- gestion du passage en arrière-plan (`beginBackgroundTask`) pour éviter le watchdog.

---

## Stack technique

| Item | Valeur |
|------|--------|
| Cible | iPhone + iPad (iOS/iPadOS 18+), pensé pour iPad Air M4 13" |
| UI | SwiftUI |
| Persistance | SQLite via **GRDB** (SPM) |
| Réseau | **AMSMB2** (client SMB2/3, SPM) ; mots de passe au trousseau (Keychain) |
| Génération projet | **XcodeGen** (`project.yml`) |
| Build | `xcodebuild` |
| Version | **1.0.0** (SemVer) — affichée dans Réglages |

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

**Version 1.0.0.** Fonctionnelle sur USB-C **et** réseau SMB (iPhone + iPad).

Fait : icône d'app, refonte visuelle (3 thèmes Verre/Clair/Sombre), **client SMB natif**
+ scan réseau léger (taille d'abord), mémorisation des identifiants, version dans Réglages.

Reste à faire :
- [ ] **Analyse approfondie** (quasi-doublons visuels) à la demande — *mise de côté*
      tant qu'elle n'apporte pas un bénéfice décisif.
- [ ] **Lecture vidéo en réseau** (le tri des vidéos marche ; aperçu/lecture SMB à venir).
- [ ] Soumission App Store ; Live Photos, partage/export, widget.

## Versioning

Versioning sémantique, démarré à **1.0.0**. **Règle : aucun push de code sans bump de
`MARKETING_VERSION`** (`project.yml`) — patch pour un correctif, mineur pour une
fonctionnalité, majeur pour une rupture — puis `xcodegen generate`. La version est
**affichée dans Réglages → À propos** (lue depuis le bundle, donc toujours synchro).
</content>
</invoke>
