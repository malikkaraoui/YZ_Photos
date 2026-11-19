---
date: 2026-11-17
tags: [build, ios, M0003]
mandat_id: M0003
statut: reponse-disponible
projet: yzphotos
type: revue
---

# M0003 — Recompiler, installer et lancer YZPhotos sur l'iPad

## Gardes

- Garde 1 : `git --no-optional-locks rev-parse main` = `a3f0745b6ed95d32f52369f9abfe512b3f98ae2e` (conforme).
- Garde 2 : aucune écriture git effectuée (ni add, commit, push, checkout, reset, stash).
- Garde 3 : `xcodegen` non lancé, aucun fichier suivi modifié par la session.
- Garde 4 : produits de build hors dépôt (`~/Library/Developer/Xcode/DerivedData/yzphotos-M0003`).

## Environnement

- `xcode-select -p` : `/Applications/Xcode.app/Contents/Developer`
- `xcodebuild -version` : Xcode 27.2, Build version 27B52
- `xcrun devicectl list devices` : iPad Air 13-inch (M4), identifiant `00008132-001219413E23401C`, `available (paired)`.

## Build

Commande : `xcodebuild ... -configuration Debug -destination 'platform=iOS,id=00008132-001219413E23401C' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/yzphotos-M0003" -allowProvisioningUpdates build`
Journal : `~/Library/Logs/yzphotos-M0003-build.log`
Résultat : `** BUILD SUCCEEDED **` (signature Apple Development, profil `iOS Team Provisioning Profile: com.karaoui.YZPhotos`).

## Installation

Commande : `xcrun devicectl device install app --device 00008132-001219413E23401C .../Debug-iphoneos/YZPhotos.app`
Sortie : `App installed:` — `bundleID: com.karaoui.YZPhotos`, `databaseSequenceNumber: 1532`.

## Lancement

Commande : `xcrun devicectl device process launch --device 00008132-001219413E23401C com.karaoui.YZPhotos`
Sortie : `Launched application with com.karaoui.YZPhotos bundle identifier.` — code de sortie `0`.
Un seul essai effectué.

## Aucune modification de code

Aucun fichier de l'application modifié. Seuls le frontmatter de `vault/echanges/F01.md` et les fichiers de rapport du vault sont écrits.

## Notation des leçons injectées

Mandat relu : M0003

| Leçon | Verdict | Raison |
|---|---|---|
| 2026-09-22-chaque-variable-d-une-commande-destructive-s-ecrit-sous-une-forme-qui-echoue-si-elle-est-vide.md | sans-objet | Aucune commande destructive (`rm`) dans M0003 ; seul `-derivedDataPath` avec `$HOME` est utilisé, hors suppression. |
| 2026-08-27-une-sequence-d-echappement-ecrite-par-un-outil-d-agent-peut-arriver-decodee-sur-le-disque.md | sans-objet | Aucune écriture de séquence d'échappement par un outil d'agent ; le journal de build est produit par `tee`, sans encodage. |

Sortie de `node ~/.harnais/canon/superviseur/lecons-notation.mjs /Users/malik/Documents/yzphotos` :

```
notees=0 ecartees=0 retirees=0 absentes=0 revues_lues=0 revues_comptees=0
journal=/Users/malik/Documents/yzphotos/vault/runtime
```
