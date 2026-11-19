---
projet: yzphotos
type: revue
date: 2026-11-19
statut: reponse-disponible
tags: [revue, doublage, R002, finitions-v1]
verdict: GO
tip: a242e4ae9f0748ab6c4102401e49406c9aa1e65a
niveau: N2
---

# Revue R002 : doublage de finitions-v1 (N2)

## Périmètre lu

- `git log --oneline origin/main..origin/finitions-v1` : 8 commits (M0013 à M0025), tip `a242e4a`.
- `git rev-parse origin/finitions-v1` : `a242e4ae9f0748ab6c4102401e49406c9aa1e65a`, conforme au mandat.
- `git diff --stat origin/main...origin/finitions-v1` : 32 fichiers, 501 insertions, 122 suppressions.
- `git diff origin/main...origin/finitions-v1` lu en entier (Swift, tests, scripts, project.yml, fastlane, PrivacyInfo, catalogue `Localizable.xcstrings`).
- Vérifications statiques via `git show a242e4a:<fichier> | grep` : appelants de `actionButton` (littéraux uniquement, compatibles avec `LocalizedStringKey`), présence au catalogue des clés `%@ photos`, `%@ photo`, `%@ vidéos`, `%@ vidéo`, `%@ à trier`, `Analyse terminée` (valeur en « Analysis complete »), `Dernière analyse complète : %@`, `📚 %@`, `Captures d'écran`, `Bibliothèque Photos` ; recherche de clés JSON dupliquées au catalogue (aucune).
- Non exécuté : aucune compilation, aucun test unitaire (`xcodebuild`, `YZPhotosTests`) et le script `scripts/verifier-textes-fr.py` n'ont été lancés, conformément au mandat (lecture seule, Read/Grep/git uniquement).

## Constats par fichier

- `LocalizationManager.swift` : `applyToBundle` fixe `Fmt.locale` et `languageBundle` ; `loc(_:)` passe le bon bundle et la bonne locale. Cohérent avec les tests `LocalizationTests`.
- `Formatters.swift` : `bytes`, `count`, `date` acceptent une locale explicite, `Fmt.locale` par défaut. Cohérent avec `FormattersTests`.
- `MainTabView.swift` / `ScanProgressView.swift` : la feuille de détail du scan remonte sur la `TabView` avec `showScanDetail`, la bannière reçoit `onOpen`. Le déplacement est logiquement correct (la feuille ne dépend plus du bandeau qui disparaît).
- `DuplicateGroupsView.swift`, `FolderBrowserView.swift`, `SMBBrowserView.swift`, `SettingsView.swift`, `StatsDashboardView.swift`, `TriageDeckView.swift`, `TrashView.swift`, `FilePreviewPane.swift`, `MediaGridView.swift` : conversions en `loc(...)` ou `Text(...)`. Les clés d'interpolation utilisées existent au catalogue (vérifié sur les cas listés ci-dessus).
- `FileViewerSheet.swift` : paramètre passé en `LocalizedStringKey`. Les trois appelants sont des littéraux, donc compile.
- `SettingsView.swift` : ajout de `lineLimit(1)` et `fixedSize` sur le bouton « Brancher ». Cosmétique, sans risque logique.
- `ScanProgressView.swift` : ligne mémoire de l'app encapsulée dans `#if DEBUG`. Intentionnel, la valeur n'apparaît plus en Release.
- `project.yml` : `CURRENT_PROJECT_VERSION` passe de `"1"` à `"0.4"`. Chaîne pointée, acceptée par la syntaxe de `project.yml`.
- `PrivacyInfo.xcprivacy` : aucune donnée collectée, aucun suivi, trois catégories d'API déclarées. Rien d'incohérent dans le fichier, mais la liste des raisons n'a pas été recoupée avec les API réellement appelées.
- `fastlane/metadata/*` : passage à « gratuite, sans publicité ». Cohérent avec le commit M0024 ; le prix réel se règle dans App Store Connect, hors dépôt.
- `YZPhotosTests/*` : tests unitaires nouveaux. Leurs attendus (« Analysis complete », « 2.93 GB », « 2,93 Go ») sont cohérents avec les valeurs du catalogue et les formats ICU. Non exécutés.

## Remarques (tickets, non bloquantes)

1. Exécuter la suite `YZPhotosTests` et le script `scripts/verifier-textes-fr.py` avant merge : seule vérification dynamique manquante. Le test `testInterpolation` dépend de la valeur anglaise complète de `Dernière analyse complète : %@`, que je n'ai pas relue en entier.
2. Une clé d'interpolation absente du catalogue retombe silencieusement sur le français en UI anglaise. Le script de vérification est le filet ; à lancer en CI ou avant chaque build.
3. `PrivacyInfo.xcprivacy` : recouper les raisons d'API (`CA92.1`, `3B52.1`, `C617.1`, `85F4.1`) avec les appels réels avant soumission.
4. Vérifier dans App Store Connect que le prix (gratuit) correspond aux métadonnées fastlane modifiées.

## Conclusion

Aucun défaut prouvé : pas d'erreur de compilation visible par lecture (signatures, appelants, types `LocalizedStringKey`/`String`), pas d'incohérence logique, pas de clé JSON dupliquée, clés d'interpolation présentes. Verdict **GO** au niveau N2, sous réserve de l'exécution des tests (remarque 1) avant merge sur la branche principale.
