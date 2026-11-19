---
projet: yzphotos
type: revue
date: 2026-11-19
statut: reponse-disponible
tags: [release, nettoyage, M0029, integration]
---

# M0029 — Intégration de finitions-v1 dans main, nettoyage

## Garde-fous

- `origin/finitions-v1` = `a242e4ae9f0748ab6c4102401e49406c9aa1e65a` : OK.
- `origin/main` a bougé de `65783e0` à `2a160c1`. `git diff --name-only 65783e0 origin/main` ne montre que `vault/reprise/F07.md` et `vault/revues/2026-11-19-M0028-asc-visuels.md` : OK, poursuite.
- F07 : `statut: reponse-disponible` dès la première lecture : OK.

## Doublage

- R002 (sous-agent frais, lecture seule, N2) : **GO**, `tip: a242e4ae9f0748ab6c4102401e49406c9aa1e65a`. Fichier `vault/revues/2026-11-19-R002-doublage-finitions-v1.md`, commit `576905a`.
- Le doublage n'a pas lancé les tests. Reste à faire : `YZPhotosTests` et `scripts/verifier-textes-fr.py` (non exécutés dans M0029 ; 39/39 en M0025).

## Merge et push

- Worktree scratch `.claude/worktrees/M0029`, `merge --no-ff origin/finitions-v1` → `7503a9a` (32 fichiers, 501 insertions, 122 suppressions). `merge-tree` préalable : sans conflit.
- Le merge a ignoré les hooks `pre-merge-commit` et `commit-msg` (non exécutables dans le checkout, voir remontée).
- Rapport R002 commité dans le scratch → `576905a`, puis `git merge --ff-only` à la racine : fast-forward `2a160c1..576905a`.
- Push : `2a160c1..576905a  main -> main`, pre-push passé (hooks exécutables côté racine).
- `git ls-remote origin refs/heads/main` → `576905a947f7e20d906367f77df938ca023ddc6d refs/heads/main`.
- Racine : `git status --short` avant le ff-only ne montrait que des fichiers non touchés par le merge (`gabarits.md`, `F02.md`, `F07.md`, `notations.json`, `reprise/F01.md`, suppressions de `YZPhotos-Handoff/*screenshot1.png`, non suivis `vault/echanges/F0x.md` et `archive/`).

## Worktrees

- Supprimés avec `worktree remove --force` : M0013, M0018, M0019, M0021, M0022, M0025, M0026, M0027, M0029. `.dd/` (M0026 et autres) disparu avec eux.
- `git worktree prune` puis `git worktree list` :

```
/Users/malik/Documents/yzphotos 576905a [main]
```

- `ls .claude/worktrees/` : vide.

## Branches

- `finitions-v1` : supprimée localement (`was 94f86b0`) et sur origin.
- `vault-unique` : `origin/vault-unique` est ancêtre de `origin/main` → supprimée localement (`was 12249bd`) et sur origin.
- Non touchées, à titre informatif :
  - `copilot/photo-cleaner-ipad-app` : dernier commit `6ce2f79`, 2026-06-11, « docs: define photo cleaner product vision ».
  - `feat/liquid-glass-smb` : dernier commit `0acd63c`, 2026-06-19, « chore: config projet XcodeGen (icône, iPhone, AMSMB2, réseau local) ».

## Brouillons Cowork

- Supprimés : `_pose-cowork/M0009.md`, `_pose-cowork/M0025/`, `_pose-cowork/metadata-M0024/`, `_pose-cowork/verifier-textes-fr.py`.
- **Écart de procédure** : `verifier-textes-fr.py` a été supprimé avant la comparaison avec la copie dans le dépôt. Le `cmp` a échoué (la copie n'existe que dans `origin/finitions-v1`, pas à la racine). Une fois la comparaison faite : la copie du dépôt fait 2324 octets, le brouillon supprimé faisait 2296 octets. Ce ne sont donc pas le même fichier. Le brouillon n'est pas récupérable (hors Git).

## Tickets GitHub

- `gh issue list --state open` avant création : seul #2 existait.
- Créés :
  - #3 : libellé « photothèque Apple » sur la carte de tri (`SwipeCardView.swift`).
  - #4 : « Autre »/« More » en français en mode anglais (ajouter `en` à `CFBundleLocalizations`).
  - #5 : `NSLocalNetworkUsageDescription` sans traduction anglaise.
  - #6 : « Les 7 vérifications » se réinitialisent au redimensionnement.
  - #7 : visuels App Store anglais à exporter et envoyer par l'API.
  - #8 : `scripts/verifier-textes-fr.py` ne voit pas les littéraux sans accent renvoyés par un `switch`.
- Remarques du doublage R002 (non bloquantes, non ouvertes en issue dans ce mandat) : exécuter les tests et le script avant release ; faire tourner le script de vérification en CI ; recouper les raisons de `PrivacyInfo.xcprivacy` avec les API réellement appelées ; vérifier le prix gratuit dans App Store Connect.

## Vault

- `vault/decisions/2026-11-19-soumission-v1.md` écrit (5 champs).
- `~/.harnais/canon/bin/harnais ranger /Users/malik/Documents/yzphotos --verifier` : **2 écarts** sur 94 fichiers, attendu 0.
  - `ECART champ-manquant vault/echanges/archive/F01-M0007.md : projet, type`
  - `ECART champ-manquant vault/echanges/archive/F02-M0011.md : projet, type`
  - Non corrigés : ces fichiers ne sont pas de ce mandat et `--appliquer` est interdit.

## Problème du harnais

- Les hooks `scripts/harnais-hooks/*` sont suivis en `100644`. Dans tout checkout frais, ils sont inopérants : le merge a affiché « hook was ignored because it's not set as executable ».
- Remontée `REM0529` (classe `bug-harnais`, brique `hooks`), statut `en-attente`.

## Notation des leçons injectées

Mandat relu : M0029

| Leçon | Verdict | Raison |
|---|---|---|
| 2026-09-22-la-surface-de-production-d-un-changement-se-releve-dans-le-diff-pas-dans-la-declaration-de-l-auteur.md | a-aide | Garde-fou appliqué avant poursuite : `git diff --name-only 65783e0 origin/main` relevé dans le diff, pas dans la déclaration. Lien causal non prouvé, jugement sur le rapport. |
| 2026-09-01-un-deploiement-qui-ne-rejoue-qu-une-partie-de-ses-etapes-se-declare-complet.md | a-aide | Le rapport déclare les étapes non rejouées (hooks `pre-merge-commit`/`commit-msg` ignorés, tests non lancés) au lieu de se dire complet. Lien causal non prouvé, jugement sur le rapport. |

Source : `vault/runtime/events.jsonl`, événement `LECONS_INJECTEES` du 2026-11-19T19:13:39Z (f=F02, mandat=M0029, niveau=N2).

## Relecture

Relecture indépendante (sous-agent frais, lecture seule, brief Tâche 1). Aucune commande modifiant git lancée.

- **Refs main** : OK. `git rev-parse main origin/main` → `576905a947f7e20d906367f77df938ca023ddc6d` (deux lignes identiques).
- **Remote main** : OK. `git ls-remote origin refs/heads/main` → `576905a947f7e20d906367f77df938ca023ddc6d refs/heads/main`.
- **Merge 7503a9a présent dans origin/main** : OK. `git merge-base --is-ancestor 7503a9a origin/main` → `OK`.
- **Worktrees** : OK. `git worktree list` → `/Users/malik/Documents/yzphotos 576905a [main]` (une seule ligne). `ls .claude/worktrees/` → vide.
- **Branches** : OK. `git branch -a` ne liste plus `finitions-v1` ni `vault-unique` ; `git ls-remote --heads origin finitions-v1 vault-unique` → aucune sortie. `copilot/photo-cleaner-ipad-app` (`6ce2f79`) et `feat/liquid-glass-smb` (`0acd63c`) présentes sur origin.
- **Issues ouvertes** : OK. `gh issue list --state open --limit 50` → #2 à #8, toutes OPEN.
- **Fichiers** : OK. `vault/revues/2026-11-19-M0029-integration-nettoyage.md`, `vault/reprise/F02.md` et `vault/decisions/2026-11-19-soumission-v1.md` existent.
- **Leçons injectées** : OK. `grep LECONS_INJECTEES vault/runtime/events.jsonl` : 21 événements au total, 1 seul pour M0029 (deux leçons, voir section ci-dessus).
- **Écart de fond relevé dans le rapport, hors Tâche 1** : aucun écart sur les sorties. Le rapport dit « 2 écarts harnais ranger » sur `archive/F01-M0007.md` et `archive/F02-M0011.md` : non vérifié, hors périmètre de ce brief.
