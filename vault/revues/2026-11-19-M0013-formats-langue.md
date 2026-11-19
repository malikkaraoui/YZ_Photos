---
projet: yzphotos
type: revue
date: 2026-11-19
statut: bloque
tags: [revue, M0013, formats, langue, test]
---

# M0013 : unités, dates et nombres selon la langue de l'app

## Résultat

Code écrit dans le worktree `.claude/worktrees/M0013` (branche `finitions-v1`, base `de875bf`), non committé. Compilation app + tests OK sur destination générique simulateur. Exécution des tests impossible ici : aucun runtime simulateur utilisable (`xcrun simctl list devices` : iOS 26.5 indisponible, « runtime profile not found »). Le mandat interdit tout build ou install sur appareil réel. Pas de commit, donc pas de push ni de merge.

## Gardes

1. `main` = `origin/main` = `de875bf76c3c874a801640fe6bdd63429ca35113` : OK.
2. `YZPhotos/Resources/Localizable.xcstrings` : diff sauvegardé dans `/private/tmp/claude-501/-Users-malik-Documents-yzphotos/7927a8a4-8f05-4eb6-a159-e78159407d4b/scratchpad/Localizable.xcstrings.pre-M0013.diff` (5702 lignes), puis `git restore`. Diff ensuite vide.
3. Worktree `.claude/worktrees/M0013` créé sur `finitions-v1` depuis `origin/main` : OK.
4. Aucun build ni install sur appareil.

## Fichiers touchés

- `YZPhotos/App/Formatters.swift` : `Fmt.locale` (défaut `fr`), `bytes`/`count`/`date` prennent `locale: Locale = Fmt.locale`. `duration` et `eta` inchangés.
- `YZPhotos/Core/Localization/LocalizationManager.swift:58` : `Fmt.locale = Locale(identifier: lang.rawValue)` en tête de `applyToBundle`.
- `YZPhotosTests/FormattersTests.swift` (nouveau) : 5 tests (bytes en/fr, zéro en, date en, count).
- `YZPhotos.xcodeproj/project.pbxproj` : +4 lignes seulement (ajout de `FormattersTests.swift`). `xcodegen generate` avait aussi ajouté des changements hors sujet (DevelopmentTeam, nom GRDB, lastKnownFileType) : annulés à la main.

## Tests

- Rouge : `xcodebuild test` sur les tests seuls avant le correctif → « TEST BUILD FAILED », `extra argument 'locale' in call` (6 erreurs). Rouge par compilation, pas par assertion.
- Vert : non prouvé. `xcodebuild build-for-testing -destination 'generic/platform=iOS Simulator'` → `TEST BUILD SUCCEEDED` après correctif. `xcodebuild test` sur destination générique → « Tests must be run on a concrete device ».
- Non couvert : le comportement réel de `.byteCount(style:).locale(…)` et de `Date.FormatStyle.locale(…)` (sorties « GB », « nov. »). À confirmer sur un simulateur installé.

## Ce qui reste (STOP)

- Installer un runtime iOS simulateur (`xcodebuild -downloadPlatform iOS` ou Xcode › Réglages › Plateformes), puis relancer `FormattersTests` et la suite complète.
- Après vert : commit ciblé (pathspec des 4 fichiers), push `finitions-v1`, relecture indépendante.

## Limite d'environnement (pas un fait sur le code)

Aucun runtime simulateur installé sur ce Mac. Ce n'est pas un problème du harnais : pas de remontée.
