---
projet: yzphotos
type: revue
date: 2026-11-19
statut: clos
tags: [revue, M0017, affichage, i18n, lot-a]
---

# Revue M0017 : feuille Analyse persistante + textes en dur, lot A

Branche `finitions-v1`, commit `0225796` (poussé, `git ls-remote` : `022579690069a835593b78461407ddfef15a2835`). Base : `94f86b0` (garde 1 OK). Worktree détaché M0017 créé puis retiré sans `--force`. Worktree M0013 non touché. Pas de merge sur `main`, pas d'iPad, pas de simulateur.

## Changements

- Feuille Analyse (symptôme A) : `ScanProgressBanner` ne possède plus `@State showDetail` ni `.sheet`, il reçoit `var onOpen: () -> Void`. `MainTabView` porte `@State showScanDetail` et le `.sheet` sur la TabView, hors du `if env.scan.isRunning` et hors de l'overlay. Le bouton Arrêter garde son `dismiss()` (voulu).
- Textes en dur (lot A, 32 emplacements) : `String(localized:)` dans les contextes `String` (ternaires, `case`, concaténations, `navigationTitle`, `Label`, `actionError`). Les `Text`/`Label` littéraux gardent leur code, seule la clé manquait.
- Catalogue `YZPhotos/Resources/Localizable.xcstrings` : 6 clés ajoutées à la main (Xcode n'a pas écrit dans le catalogue lors du build générique) : `moins d'une minute`, `Terminée le %@`, `Terminée.`, ` · sur %@`, le message « %@ n'est pas branché… », `Réglages & statistiques`. Toutes ont un `en` `translated`, mêmes spécificateurs.
- `ScanProgressView.swift` : ligne « Mémoire de l'app » enveloppée de `#if DEBUG` / `#endif`.
- `SettingsView.swift` : `.lineLimit(1)` et `.fixedSize(horizontal: true, vertical: false)` sur le `Label` « Brancher ».
- Outil copié : `scripts/verifier-textes-fr.py` (ajouté au commit).

## Preuves

Script avant : `python3 scripts/verifier-textes-fr.py .` → `75 texte(s) non traduit(s)`.
Script après : 46 au total ; lignes du périmètre lot A :

```
YZPhotos/Features/Scan/ScanProgressView.swift:340: Étape \(number) —
YZPhotos/Features/TrashTab/TrashView.swift:43: Les fichiers mis à la poubelle…
YZPhotos/Features/Triage/TriageDeckView.swift:403: Aucun fichier à trier pour ce filtre.
```

Gate « VIDE » non atteinte. Ces trois lignes sont des faux positifs du script, pas des manques : les clés existent au catalogue (`Étape %lld — ` en `translated`, et les deux autres). Le script convertit toute interpolation en `%@` (Swift génère `%lld` pour un `Int`) et prend un argument `message:` de `YZEmptyState` (`LocalizedStringKey`, `DesignSystem/YZComponents.swift:211`) pour une `String`. Ne pas modifier le code pour faire passer le contrôle. Remontée : REM0509.

Grep dismiss (`git grep -n "dismiss()" -- YZPhotos/Features/Scan/*.swift`) :

```
YZPhotos/Features/Scan/ScanProgressView.swift:165:                    Button("Fermer") { dismiss() }
YZPhotos/Features/Scan/ScanProgressView.swift:415:                if asSheet { dismiss() }
```

Seuls « Fermer » et « Arrêter l'analyse » ferment la feuille. Aucun `dismiss()` lié à `isRunning` ou à la fin de l'analyse.

Tests, iPhone (`id=00008101-001278EA36E9001E`) : `** TEST SUCCEEDED **`, `Executed 36 tests, with 0 failures (0 unexpected)`. Log : `scratchpad/test-m0017.log`. Build générique iOS (`generic/platform=iOS`, sans signature) : `BUILD SUCCEEDED`.

## Relecture (sous-agent frais, lecture seule)

Verdict : GO. Vérifications A (`.sheet` hors du `if isRunning`, `onOpen` au tap, `dismiss()` du bouton Arrêter inchangé), C (5 traductions tirées au hasard + 6 clés : sens juste, `%@`/`%lld` identiques, `state` translated) et D (aucun `String(localized:)` dans un paramètre `LocalizedStringKey`, `#if DEBUG` apparié).

Deux hunks signalés « hors mandat » par le relecteur : ils sont au mandat (item 4 : `#if DEBUG`, item 5 : `.lineLimit`/`.fixedSize` sur « Brancher »). Pas de correction.

Correction au relecteur : il a écrit « aucune leçon injectée ». L'événement `LECONS_INJECTEES` du 19/11 14:59 (UTC) en liste trois (voir la section ci-dessous).

## Notation des leçons injectées

| Leçon | Valeur | Raison |
|---|---|---|
| 2026-09-21-un-controle-dont-l-entree-est-produite-par-le-processus-verifie-ne-controle-rien.md | a-aide | Face à 3 lignes résiduelles du contrôle, la règle « ne pas modifier le contrôle pour le faire passer » a été suivie : écart documenté, pas de contournement. |
| 2026-09-19-une-fixture-privee-d-un-champ-que-la-production-pose-toujours-rend-verts-des-tests-qui-figent-un-repli.md | sans-objet | Aucune fixture ni repli modifié dans ce mandat. |
| 2026-09-21-un-mutant-tue-autrement-que-par-une-assertion-nommee-n-est-pas-tue.md | sans-objet | Aucun banc de mutations dans ce mandat. |

Mandat relu : M0017

## Remontées

- REM0509 (en-attente) : verifier-textes-fr, faux positifs `%lld` et `message:` LocalizedStringKey (classe bug-harnais, brique autre).
- REM0510 (en-attente) : bug-harnais, brique autre, même outil (sortie de la première tentative refusée : preuve non rejouable).
- REM0511 (en-attente) : friction hooks, PreToolUse Bash bloque `git grep` sans recherche qmd préalable.
- Hooks git non exécutés : `scripts/harnais-hooks/pre-commit` et `commit-msg` ignorés (non exécutables) à `git commit 0225796`. Ce fichier n'a pas été remonté séparément ; il est mentionné ici et au rapport F07.

## Points ouverts

- Trailer de commit : le mandat demandait `Co-Authored-By: Claude <noreply@anthropic.com>` ; la consigne système courante demande `Co-Authored-By: Claude Haiku 5.5` + `Claude-Session`. Le commit porte la consigne système.
- Pas de merge sur `main` (mandat). Intégration à faire par l'orchestrateur après le verdict.
- Lot B (autres fichiers) : non touché, mandat suivant.
