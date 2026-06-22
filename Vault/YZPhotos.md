---
tags: [projet, ipad, swift, photos]
created: 2026-06-12
status: en-cours
---

# YZPhotos — Note Maître

App iPadOS native pour trier >1 To de photos/vidéos stockées sur deux SSD Samsung T5/T7 (USB-C).
Faite pour la femme de Malik. Usage quotidien sur **iPad Air M4 13"**.

## Liens rapides

- [[Architecture/Stack]] — choix techniques validés
- [[Architecture/Database]] — schéma SQLite GRDB
- [[Architecture/Scanning]] — pipeline d'analyse 2 passes
- [[Architecture/Duplicates]] — dHash + BK-tree + UnionFind
- [[Features/Triage]] — deck Tinder, swipe, undo
- [[Features/Library]] — grilles Photos/Vidéos/Captures/Par taille
- [[Features/Folders]] — navigation hiérarchique
- [[Features/Duplicates]] — groupes, keepBest, runControlPanel
- [[Features/Trash]] — corbeille différée, suppression définitive
- [[Features/Scan]] — onglet Analyse, progression par étapes
- [[Features/Settings]] — réglages, dark mode, autoplay
- [[Features/Stats]] — dashboard ValueObservation
- [[Bugs/Fixes]] — crashs et correctifs appliqués
- [[Sessions/Commits]] — les 38 commits GitHub
- [[Sessions/NextSteps]] — ce qui reste à faire

## Contexte

| Item | Valeur |
|------|--------|
| Cible | iPad Air M4 13" |
| OS | iPadOS 18+ |
| Compte | Apple dev personnel (payant) |
| Build | XcodeGen → `project.yml` → `xcodebuild` |
| Repo | https://github.com/malikkaraoui/YZ_Photos |
| Dépendance unique | GRDB (SPM) |

## Principe fondamental

**Poubelle différée** : rien n'est supprimé sans confirmation explicite.
- Swipe gauche / bouton Poubelle → fichier déplacé dans `.YZTrash/` (même volume, rename O(1))
- Suppression réelle uniquement via "Vider la corbeille"
- Restauration possible à tout moment

## État actuel (juin 2026)

- [x] Scan complet 2 passes (métadonnées + hash/miniatures/dHash)
- [x] Deck de tri Tinder avec undo global
- [x] Doublons exacts + quasi-doublons (dHash BK-tree)
- [x] Grilles Photos / Vidéos / Captures / Par taille
- [x] Navigation dossiers avec scope drill-down
- [x] Corbeille avec restauration et suppression définitive
- [x] Stats live ValueObservation
- [x] Réglages (dark mode, autoplay, ordre grille)
- [x] 38 commits sur GitHub
- [ ] Icône app (à faire via Claude Design)
- [ ] Redesign SettingsView (livrable Claude Design)
- [ ] Soumission App Store
