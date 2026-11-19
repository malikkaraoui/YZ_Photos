---
projet: yzphotos
type: revue
date: 2026-11-19
mandat: M0025
session: F07
branche: finitions-v1
commit: a242e4ae9f0748ab6c4102401e49406c9aa1e65a
statut: rendue
verdict: GO
tags: [revue, release, privacy, app-store]
---

# Revue M0025 : manifeste de confidentialité, build 0.4, envoi App Store Connect

Relecture par un sous-agent frais, lecture seule. Verdict : **GO**, aucun contrôle en échec.
Base : `a256c606458701e2985b488b1f322b303e193562` (origin/finitions-v1) → commit `a242e4ae9f0748ab6c4102401e49406c9aa1e65a`.

## Contrôles

| # | Contrôle | Résultat |
|---|---|---|
| 1 | Manifeste identique à la source, et à celui de l'archive (`diff`, `cmp`) | OK |
| 2 | Commit de 3 fichiers seulement (pbxproj, PrivacyInfo, project.yml), entrées cohérentes avec `Localizable.xcstrings`, ids uniques | OK |
| 3 | Version : `CURRENT_PROJECT_VERSION = 0.4` aux deux emplacements, `"0.4"` dans project.yml | OK |
| 4 | `plutil -lint` pbxproj et PrivacyInfo | OK |
| 5 | Archive : CFBundleVersion 0.4, CFBundleShortVersionString 1.0.0 | OK |
| 6 | Envoi : `Uploaded YZPhotos`, `** EXPORT SUCCEEDED **` | OK |
| 7 | Tests iPad : 39 exécutés, 0 échec, `** TEST SUCCEEDED **` | OK |

## Points de vigilance (non bloquants)

- L'envoi est confirmé côté local (« Uploaded package is processing »). Le traitement côté App Store Connect reste à vérifier.
- Build iPhone non testé (hors mandat). Aucun test sur appareil iPhone.
- `CURRENT_PROJECT_VERSION` est la chaîne décimale `0.4` ; à surveiller à la validation ASC.
- Ordre alphabétique de PBXFileReference légèrement cassé (cosmétique, Xcode le réordonne).

## Notation des leçons injectées
| Leçon | Valeur | Raison |
|---|---|---|
| 2026-09-22-la-surface-de-production-d-un-changement-se-releve-dans-le-diff-pas-dans-la-declaration-de-l-auteur.md | a-aide | Surface relevée dans `git show --stat` et le diff du pbxproj, puis manifeste comparé à l'archive (`cmp`), sans se fier au message de commit. |
| 2026-09-01-un-deploiement-qui-ne-rejoue-qu-une-partie-de-ses-etapes-se-declare-complet.md | sans-objet | Le rejeu côté App Store Connect et sur appareil n'a pas été vérifié ; aucun contrôle n'a changé. |

Mandat relu : M0025
