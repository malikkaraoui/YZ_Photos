---
verdict: GO
tip: 12249bd6d70b286c0aa46a268999036572135abb
niveau: N2
projet: yzphotos
type: revue
date: 2026-11-19
statut: clos
---

# R001 relecture N2 : M0012 (vault-unique)

Base main : 6afa25cf2863e16558ce7120944d7dcc3747c667. Worktree : `/Users/malik/Documents/yzphotos/.claude/worktrees/M0012`.

## Contrôles

1. PASS. `git ls-tree -r --name-only vault-unique -- yz | wc -l` = `0` (main en contient 16).
2. PASS. `git diff --name-status -M main vault-unique` : 16 renommages `yz/... -> vault/...` (similarité 63 à 100 %), aucun autre chemin. Liste des chemins : tous sous `vault/` (les sources `yz/` ne subsistent plus au tip).
3. PASS. Les 16 cibles existent au tip (`ls` sur chaque cible : OK). Mapping conforme au mandat, y compris `yz/Architecture/Stack.md -> vault/decisions/2026-06-22-stack-technique.md` et `yz/YZPhotos.md -> vault/analyses/yzphotos-note-maitre.md`.
4. PASS. `git diff -M main vault-unique -- yz vault` : pour chaque paire, seuls changent (a) le bloc frontmatter ajouté (projet, type, date, statut) et (b) les liens wiki renommés (`[[YZPhotos]]` -> `[[yzphotos-note-maitre]]`, `[[Bugs/Fixes]]` -> `[[correctifs]]`, `[[Architecture/Scanning]]` -> `[[scanning]]`, etc.). Aucun changement de corps hors liens. Pour `yzphotos-note-maitre.md`, le frontmatter conserve `tags`, `created`, `status` d'origine et ajoute les 4 champs.
   - `[[Features/Stats]]` -> « Stats (sans note dédiée) » : acceptable. Aucune note `Features/Stats` n'existe sur main (`git ls-tree` et `git grep` sur `yz/` : seul un fichier Swift `YZPhotos/Features/Stats/StatsDashboardView.swift` existe, hors `yz/`). La cible était donc un lien mort ; le texte le dit.
5. PASS. Sortie complète : `verifier : 0 écart(s) sur 46 fichier(s) dont 37 note(s)` (EXIT=0). Aucun `--appliquer` lancé.
6. PASS. Chaque `.md` sous `vault/analyses/`, `vault/decisions/`, `vault/_archive/` (18 fichiers, dont `analyses/2026-11-18-rangement-plan.md`) a `projet`, `type`, `date`, `statut` dans les 6 premières lignes du frontmatter (vérifié par `git show vault-unique:<f> | head -6`).

## Constats

aucun

Remarque mineure (non bloquante) : les 6 notes `analyses/` de `yz/Features` et `yz/Architecture` portent `statut: ouvert` et `date: 2026-06-22` posés en masse, sans lecture du statut réel. Ce n'est pas un écart au mandat (le mandat demande la présence des champs), mais la valeur est une convention de rangement.

## Notation des leçons injectées

Mandat relu : M0012

| leçon | verdict | raison |
|---|---|---|
| 2026-08-31-deplacer-le-pointeur-d-une-branche-ne-met-a-jour-aucun-repertoire-de-travail-qui-l-a-ouverte.md | a-aide | lu le tip par la référence de branche (`git rev-parse vault-unique`), pas par HEAD du worktree |
| 2026-08-26-une-integration-faite-dans-un-espace-detache-n-existe-pour-personne-tant-que-la-reference-partagee-ne-la-contient-pas.md | sans-objet | relecture pré-merge, la question de la référence partagée ne se pose pas encore |
| 2026-08-27-un-environnement-de-test-neuf-repond-sans-etre-le-tien.md | sans-objet | pas d'environnement de test dans ce mandat (contrôles git et fichiers) |

Sortie de `node ~/.harnais/canon/superviseur/lecons-notation.mjs /Users/malik/Documents/yzphotos` :

```
notees=0 ecartees=0 retirees=0 absentes=0 revues_lues=0 revues_comptees=0
journal=/Users/malik/Documents/yzphotos/vault/runtime
```

Le script n'a rien noté (0 notée). Les verdicts ci-dessus restent à reporter par le superviseur, le script ne les a pas enregistrés.
