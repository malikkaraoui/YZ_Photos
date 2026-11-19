---
projet: yzphotos
type: analyse
date: 2026-06-12
statut: ouvert
tags: [projet, ipad, swift, photos]
created: 2026-06-12
status: en-cours
---

# YZPhotos — Note Maître

App iPadOS native pour trier >1 To de photos/vidéos stockées sur deux SSD Samsung T5/T7 (USB-C).
Faite pour la femme de Malik. Usage quotidien sur **iPad Air M4 13"**.

## Liens rapides

- [[2026-06-22-stack-technique]] — choix techniques validés
- [[database]] — schéma SQLite GRDB
- [[scanning]] — pipeline d'analyse 2 passes
- [[duplicates]] — dHash + BK-tree + UnionFind
- [[tri]] — deck Tinder, swipe, undo
- [[grilles]] — grilles Photos/Vidéos/Captures/Par taille
- [[dossiers]] — navigation hiérarchique
- [[doublons]] — groupes, keepBest, runControlPanel
- [[corbeille]] — corbeille différée, suppression définitive
- [[analyse]] — onglet Analyse, progression par étapes
- [[reglages]] — réglages, dark mode, autoplay
- Stats (sans note dédiée) — dashboard ValueObservation
- [[correctifs]] — crashs et correctifs appliqués
- [[commits]] — les 38 commits GitHub
- [[prochaines-etapes]] — ce qui reste à faire

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
