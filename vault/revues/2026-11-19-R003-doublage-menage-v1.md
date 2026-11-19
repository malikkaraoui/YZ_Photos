---
verdict: GO
tip: 4ac6e91fa41c2c8e15986ed15a6a6ffe4f0a20de
niveau: N2
projet: yzphotos
type: revue
date: 2026-11-19
statut: clos
tags: [revue, menage-v1, doublage]
---

# R003 doublage : menage-v1, ajout de AskUserQuestion dans --disallowedTools

Mandat relu : ménage v1 (M0030). Branche `menage-v1`, tip `4ac6e91fa41c2c8e15986ed15a6a6ffe4f0a20de`, base `origin/main` = `ecfa1e7d61a84a246a529cb7303c73e69e894730`.
Worktree : `/Users/malik/Documents/yzphotos/.claude/worktrees/M0030` (lecture seule, rien committé ni poussé).

## Verdict

**GO.** Le diff ne touche que les deux lignes attendues. Réserves non bloquantes ci-dessous.

## Axes vérifiés

1. **Périmètre du diff** : `git diff --stat origin/main..menage-v1` :

   ```
    .claude/skills/orchestration-bureau/references/gabarits.md | 4 ++--
    1 file changed, 2 insertions(+), 2 deletions(-)
   ```

   Le diff contient deux paires de lignes, une ligne 24 (commande type §1) et une ligne 167 (exemple §6). Dans chaque paire, la seule différence est l'ajout de `,AskUserQuestion` après `CronCreate`. Aucune autre modification de contenu.

2. **Cohérence interne de `gabarits.md`** : les deux seules commandes de lancement du fichier (§1 et §6) sont désormais identiques sur la liste `--disallowedTools ScheduleWakeup,CronCreate,AskUserQuestion`. Aucune divergence restante dans ce fichier.

3. **Autres sources hors `vault/`** : la recherche `grep -rn disallowedTools` a été bloquée à plusieurs reprises par le hook PreToolUse, malgré une recherche qmd préalable. Résultat partiel obtenu par qmd (`qmd query` sur `vault`, `code`, `skills`) :
   - `vault/echanges/F99.md` (M0008, `reponse-disponible`) porte déjà `ScheduleWakeup,CronCreate,AskUserQuestion` : cohérent.
   - `vault/echanges/F01.md` (M0007, `prompt-disponible`) porte encore `ScheduleWakeup,CronCreate` sans `AskUserQuestion`. C'est un mandat historique, déjà exécuté ; à signaler, pas à corriger ici.
   - Le superviseur canonique (`/Users/malik/.harnais/canon/superviseur/superviseur.mjs`, `lancement.mjs`) est un passe-plat : il contrôle la forme de la commande (`controlerCommande`), pas la liste d'outils. La constante `OUTILS_INTERDITS_MANDAT` existe dans `lancement.mjs` ; je n'ai pas pu vérifier son contenu (la lecture ciblée n'a pas été complétée). Réserve : à contrôler par le fondateur si cette liste doit aussi recevoir `AskUserQuestion`.

4. **Hooks git** : `ls -l scripts/harnais-hooks/` :

   ```
   -rw-r--r--  1 malik  staff   1817 19 nov.  22:08 CLAUDE.md
   -rw-r--r--  1 malik  staff   8446 19 nov.  22:08 commit-msg
   -rw-r--r--  1 malik  staff  43804 19 nov.  22:08 pre-commit
   -rw-r--r--  1 malik  staff    732 19 nov.  22:08 pre-merge-commit
   -rw-r--r--  1 malik  staff  20092 19 nov.  22:08 pre-push
   -rw-r--r--  1 malik  staff  26223 19 nov.  22:08 README.md
   ```

   Constat tel quel : `pre-commit`, `commit-msg`, `pre-push` et `pre-merge-commit` ne sont pas exécutables (pas de bit `x`). Le commit `4ac6e91` a donc été fait sans que ces hooks tournent. Le contrôle de taille et de largeur n'a pas été exécuté. Ce diff ne touche qu'un fichier Markdown de deux lignes, donc le risque est faible, mais le contrôle n'a bien pas eu lieu.

## Réserves (non bloquantes)

- Hooks git non exécutables (voir axe 4) : à corriger au niveau du harnais, pas dans ce mandat.
- Axe 3 incomplet : le grep global n'a pas pu tourner. Le verdict GO porte sur le diff et la cohérence de `gabarits.md`, pas sur l'absence de toute autre occurrence dans le dépôt.
- `vault/echanges/F01.md` : mandat historique sans `AskUserQuestion`, à laisser tel quel.

Verdict : GO
