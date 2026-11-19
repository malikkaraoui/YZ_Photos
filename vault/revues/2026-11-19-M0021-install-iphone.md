---
projet: yzphotos
type: revue
date: 2026-11-19
statut: livre
tags: [revue, M0021, install, iphone, build-0.2]
---

# Revue M0021 : installation de la Release build 0.2 sur l'iPhone

Branche `finitions-v1`, commit `21dfe1c41ba29442c9f11a68243f5a5009af430e` (= `origin/finitions-v1`, gardes 1 et 2 OK). Worktree détaché `.claude/worktrees/M0021`. Aucun code, aucun commit de code. iPad non touché, worktrees M0013/M0018/M0019 non touchés, pas de simulateur.

## Contrôles (sorties)

- Build : `xcodebuild -project YZPhotos.xcodeproj -scheme YZPhotos -configuration Release -destination 'id=00008101-001278EA36E9001E' DEVELOPMENT_TEAM=UPES5479T5 -derivedDataPath .dd build` → `** BUILD SUCCEEDED **`.
- `CFBundleVersion` (`.dd/Build/Products/Release-iphoneos/YZPhotos.app/Info.plist`) : `0.2`.
- Install : `xcrun devicectl device install app --device 00008101-001278EA36E9001E …` → `App installed:`, `bundleID: com.karaoui.YZPhotos`.
- Launch : `xcrun devicectl device process launch --device 00008101-001278EA36E9001E com.karaoui.YZPhotos` → `Launched application with com.karaoui.YZPhotos bundle identifier.`

## Relecture

Sans code : la relecture est la vérification des sorties ci-dessus (BUILD SUCCEEDED, CFBundleVersion 0.2, install et launch OK).

## Notation des leçons injectées

Aucune leçon injectée : « aucune leçon injectée » (événement `LECONS_INJECTEES` de M0021 : `"lecons":[]`, `"taille":0`).

Mandat relu : M0021

Sortie de `node ~/.harnais/canon/superviseur/lecons-notation.mjs /Users/malik/Documents/yzphotos` :

```
notees=0 ecartees=0 retirees=0 absentes=0 revues_lues=1 revues_comptees=1
journal=/Users/malik/Documents/yzphotos/vault/runtime
```

## Installation et annulation

- Worktree M0021 : `git worktree remove` sans `--force` refusé (`contains modified or untracked files`, à cause de `.dd/`). Non retiré, `.dd/` non supprimé. À retirer à la main après suppression de `.dd/`.

## Remontée

- `REM0520 en-attente` : un hook PreToolUse refuse un appel Bash ordinaire (`Cherche d'abord avec qmd`), hors build. Classe `bug-harnais`, brique `hooks`. Même mécanisme que `REM0518` (M0020), déposé en doublon : à dédupliquer par le superviseur.
