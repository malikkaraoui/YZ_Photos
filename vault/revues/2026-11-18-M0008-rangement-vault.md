---
projet: yzphotos
type: revue
date: 2026-11-18
statut: rendue
verdict: STOP — commit local 665fd1b à corriger avant push
tags: [harnais, rangement, M0008]
mandat_id: M0008
session: F99
---

# M0008 — Rangement du vault de yzphotos (rapport)

## Faits

- Simulation (`harnais ranger … --simuler`) : 0 déplacement, 11 entêtes, 0 lien, 0 refus, 0 fichier à secret. Plan : `vault/analyses/2026-11-18-rangement-plan.md`.
- Application (`harnais ranger … --appliquer`) : **commit refusé** — `error: pathspec 'vault/analyses/2026-11-18-rangement-plan.md' did not match any file(s) known to git`, code 4. Les fichiers sont rangés sur le disque, `vault.range: true` posé dans `config/harnais.json`.
- Vérification immédiate (`--verifier`) : 0 écart sur 12 fichiers dont 11 notes.
- Commit fait à la main (pathspec explicite) : `665fd1b chore(vault): rangement v2 (M0008)`, local, **non poussé**.
- Vérification après commit (`--verifier`) : **EXIT=1**, `ECART champ-vide vault : 36 fichiers sur le disque, aucun vu par git`. Cause : `core.ignorecase=true` et le dossier suivi par git est `Vault/` (majuscule). Les 12 notes ont été committées sous `Vault/…`, donc `git ls-files vault` rend 0.
- Le commit `665fd1b` embarque aussi `config/harnais.json` : passage de version `v1.14.0` → `v1.15.0` et bloc `vault.range: true`. La modification de version était déjà présente dans l'arbre avant ma session ; je ne l'ai pas décidée.

## Preuves (mission 6)

- Notes `.md` : `git ls-files vault | grep -c '\.md$'` = 0 avant, 0 après (le vault n'est pas suivi sous ce nom). Sur disque : 21 `.md` sous `vault/`. Suivis sous `Vault/` après commit : 34.
- Suppressions : `git diff --diff-filter=D --name-only HEAD~1 HEAD` = vide.
- Liens cassés : 0 (simulation : 0 lien à réécrire ; `--verifier` ne signale aucun lien cassé).
- `git status --short -- vault Vault` après commit : les `D Vault/…` (16 fichiers) étaient déjà dans l'état initial du dépôt, non liés à ce mandat ; `?? vault/echanges/F01.md` exclu volontairement (fenêtre vivante).
- Push : **aucun**. `git ls-remote origin main` = `8282d57e269e425774ee9cca4532d635d8e70206 refs/heads/main` (avant mon commit). `pousser_vault` est à `true`, mais je ne pousse pas un commit qui embarque un changement de config non décidé et un chemin `Vault/` incohérent.

## Tickets

Tickets fermés : aucun (`gh issue list` : aucun ticket ouvert retourné ; le mandat ne désigne pas de ticket).

## STOP — décision requise

Le rangement est fait sur disque, mais le commit est incorrect. Options, avec mon choix :

1. **Choix recommandé** : défaire le commit local non poussé (`git reset --soft HEAD~1`, puis `git restore --staged -- config/harnais.json Vault vault`), puis décider du nom de dossier : rester sur `Vault/` (renommer la convention) ou passer le dossier en `vault/` via `git mv` en deux étapes (contournement de `core.ignorecase`). Ce geste réécrit l'historique local : je ne l'ai pas fait sans ton accord.
2. Garder `665fd1b` tel quel et pousser : refusé, il embarque la config et des chemins `Vault/`.

Remontée : REM0464 (en-attente), classe `bug-harnais` — `ranger --appliquer` committe sans tenir compte de la casse du FS ni des fichiers non suivis.

## Tableau

M0008
Implementation      ✅
Tests               ❌
Commit              ❌
Branch push         n/a
Review              n/a
Merge main          n/a
Main push           ❌
TASK STATUS         BLOCKED
PROJECT STATUS      NOT_INTEGRATED
