---
projet: yzphotos
type: revue
date: 2026-11-19
mandat: M0022
session: F07
branche: finitions-v1
commit: e3e2015977d6d120944ee70ee312f56ecd8dabe0
statut: rendue
verdict: GO
tags: [revue, M0022]
---

# M0022 — `String(localized:)` suit la langue de l'app (`loc()`), build 0.3, install iPad

## Symptôme

Captures iPad du 19/11 17:52 (build 0.2 = `21dfe1c`, app en English, iPad en français) : « Analyse terminée », « Dernière analyse complète », « Terminée. » et « 550.4 GB · sur 1 TB » restaient en français alors que leur clé avait une valeur `en` au catalogue.

## Cause vérifiée

`LocalizationManager` change la classe de `Bundle.main` (`LocalizedBundle`) pour que `Text(LocalizedStringKey)` lise le `.lproj` choisi dans l'app. `String(localized:)` ne passe pas par cette surcharge et suit la langue de l'appareil.

## Test rouge (avant correction, sortie réelle)

```
YZPhotosTests/LocalizationTests.swift:19: error: -[YZPhotosTests.LocalizationTests testStringLocalizedSuitLangueApp] : XCTAssertEqual failed: ("Analyse terminée") is not equal to ("Analysis complete")
** TEST FAILED **
```

## Forme retenue

- `nonisolated(unsafe) static var languageBundle` dans `LocalizationManager`, mise à jour dans `applyToBundle` (`bundle ?? .main`).
- `func loc(_ value: String.LocalizationValue) -> String` = `String(localized: value, bundle: LocalizationManager.languageBundle, locale: Fmt.locale)`.
- Forme (a) et (b) du mandat non nécessaires : la forme retenue est verte du premier coup.

## Remplacement mécanique

- 18 fichiers de `YZPhotos/` : `String(localized: ` → `loc(`. Aucun appel n'avait de `table:`, `comment:`, `bundle:` ou `locale:` (grep vide).
- Après : `grep -rn "String(localized" YZPhotos` → seules les deux lignes de `loc` (une doc-comment, une ligne de corps).

## Tests

- Suite complète sur iPad Air M4 (`00008132-001219413E23401C`), Debug : `Executed 39 tests, with 0 failures`, `** TEST SUCCEEDED **`. Dont `LocalizationTests` : `testStringLocalizedSuitLangueApp`, `testInterpolation`, `testFrancaisQuandAppEnFrancais` (passed).
- Script FR `scripts/verifier-textes-fr.py` : patché pour ignorer `loc(` (comme il ignorait `String(localized:`). Résultat : 15 textes non traduits, identique à la référence `21dfe1c` (15). Pas de régression.

## Build et install

- `CURRENT_PROJECT_VERSION` : 0.2 → 0.3 (2 occurrences).
- Release iPad : `** BUILD SUCCEEDED **`, `CFBundleVersion` = `0.3`.
- `devicectl device install app` : installé (installationURL présente). `process launch com.karaoui.YZPhotos` : `Launched application`.

## Commit et push

- Commit `e3e2015` sur `finitions-v1` (22 fichiers, pathspec explicite, sans `.dd` ni logs).
- `git ls-remote origin refs/heads/finitions-v1` → `e3e2015977d6d120944ee70ee312f56ecd8dabe0`.
- Pas de merge sur `main`.

## Limites de la preuve

- Les tests prouvent le comportement du bundle `.lproj` sous XCTest sur l'iPad. Ils ne prouvent pas, à l'écran, les captures de Malik (vue « Disk analysis » en langue anglaise) : à vérifier visuellement après install.
- Les lignes `Text("…")` littérales restent dans le modèle existant (non touchées par ce mandat).
- Hooks git `scripts/harnais-hooks/pre-commit` et `commit-msg` ignorés par git : non exécutables (`hint` au commit). Le commit a donc été fait sans ces hooks. Signalé en remontée.

## Relecture

Voir `vault/revues/2026-11-19-R002-relecture-M0022.md` (sous-agent frais, lecture seule).
