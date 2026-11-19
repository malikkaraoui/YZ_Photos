---
projet: harnais
type: convention
date: 2026-11-07
statut: actif
tags: [documentation, source-de-verite]
---

# Convention du vault (v2)

Une note = un fait daté, typé, rattaché à un projet. Ce qui n'est pas une note (copie, journal brut,
binaire, archive close) reste hors de la recherche. Cette page vaut pour **toutes** les notes, anciennes
comprises : le rétro-remplissage est obligatoire (décision de Malik du 07/11/2026, M0548 ; la règle « pas de
rétro-remplissage » de la version du 05/11 est révoquée). Le geste qui range : `harnais ranger` (§8).

Un vault est **rangé** quand `harnais ranger <dossier-projet> --verifier` rend 0 écart.

## 1. Arborescence

| Dossier | Contenu | Indexé |
|---|---|---|
| `README.md` | cette convention (copie posée par `harnais equiper`) | oui |
| `echanges/` | mandats et rapports en cours (`Fxx.md`) | oui |
| `echanges/archive/` | fiches closes | **non** |
| `reprise/` | point de reprise par fenêtre, carnet de bord, état technique | oui |
| `reprise/archive/` | reprises closes | **non** |
| `revues/` | `AAAA-MM-JJ-<Mxxxx\|Rxxx>-slug.md`, une revue ou un rapport complet par fichier | oui |
| `decisions/` | `AAAA-MM-JJ-slug.md`, une décision par fichier | oui |
| `lecons/<projet>/`, `lecons/transverse/` | `AAAA-MM-JJ-<la-lecon-en-une-phrase>.md`, une leçon par fichier | oui |
| `hypotheses/`, `analyses/` | une hypothèse ou une analyse par fichier | oui |
| `runtime/` | `state.json`, `events.jsonl`, verrous : registres des outils, jamais touchés | **non** |
| `_archive/` | tout contenu clos ou brut : copies, journaux, sauvegardes, `*mailbox*`, dossiers hors convention | **non** |
| `_assets/` | captures et binaires ; les pièces d'une revue : `_assets/revues/captures-<id>/` | **non** |

Aucun autre dossier ni fichier au premier niveau. Les sous-dossiers des dossiers ci-dessus sont libres.
Une capture d'écran ou un journal joint à une revue va dans `_assets/revues/captures-<id>/`, jamais sous `revues/`.

## 2. Cinq champs de frontmatter

```
---
projet: <projet.nom de config/harnais.json>
type: <une valeur ci-dessous>
date: AAAA-MM-JJ
statut: <une valeur permise pour ce type>
tags: [<1 à 4 clés de templates/vocabulaire-tags.json>]
---
```

| `type` | `statut` permis |
|---|---|
| `echange` | `en-pose`, `pret-a-lancer`, `prompt-disponible`, `en-cours`, `reponse-disponible`, `annule` |
| `revue` | `en-cours`, `rendue` (le verdict va dans `verdict:`, jamais dans `statut:`) |
| `decision` | `acte`, `revoque` |
| `lecon` | `candidate à la remontée`, `actée`, `retirée` |
| `reprise` | `courant`, `perime` |
| `analyse`, `hypothese` | `ouvert`, `clos` |
| `convention` | `actif`, `remplace` |
| `archive` (notes de `_archive/`) | `clos` |

D'autres clés peuvent s'ajouter (`mandat_id`, `session`, `verdict`, `base`…) ; les cinq sont obligatoires,
sauf sous `_archive/` (brut, hors index : ni le hook ni `--verifier` ne les y exigent ; le rangement les y pose).
Un champ compte s'il a une valeur sur sa ligne ou une liste YAML dessous (indentée ou non) ; `tags:` seul est un
champ manquant.
Une décision révoquée garde son fichier : `statut: revoque` et un lien vers celle qui la remplace.
Les contrôles portent sur la **présence** des cinq champs : une valeur ancienne hors de ces listes est
gardée telle quelle (rien ne réécrit une valeur existante).

## 3. Taille

30 Ko de texte au plus par note, une idée par note. Au-delà, découper en notes liées. Aucun binaire hors
de `_assets/` (ou hors du vault, avec un lien). La taille n'est pas contrôlée par `--verifier`.

## 4. Bruit

Ce qui est clos ou brut est rangé dans `_archive/` (copies `.bak`, `(n)`, « copie », « copy » ; journaux
`.log`, `.jsonl` hors `runtime/`) ou `_assets/` (binaires), exclu de la recherche et du cerveau. Rien n'est
jamais supprimé : l'exclure suffit, l'historique git remplace les copies.

## 5. Liens

Une décision ou une leçon cite le mandat ou la revue qui l'a produite : `[[AAAA-MM-JJ-Rxxx-slug]]` ou le
chemin `vault/revues/…`. Un lien vise un fichier qui existe : lien Markdown relatif résolu depuis la note,
depuis le vault ou depuis la racine du dépôt ; lien wiki par nom résolu dans le vault, la mémoire centrale
(`~/.harnais/core-memory`) ou les vaults des projets du registre. Un lien dans du code (bloc ou `en ligne`)
n'est pas un lien.

## 6. Recherche qmd

Une collection par vault, sur son chemin **réel** (jamais à travers un lien symbolique), motif `**/*.md`,
et ces exclusions exactes (clé `ignore:` de la collection dans `~/.config/qmd/index.yml`) :

```
**/archive/**
_archive/**
_assets/**
runtime/**
archive-worktrees-logs/**
```

Création : `qmd collection add <racine>/vault --name <projet>-vault --mask '**/*.md'`, puis ajouter les
exclusions ci-dessus, puis `qmd update`.

## 7. Cerveau (`~/Malik VAULT/projets/`)

Le cerveau ne contient que des **liens**, jamais de copie. Un vault y est relié seulement quand il est
rangé (0 écart à `--verifier`) et que sa collection qmd existe, sur le chemin réel, avec les exclusions du §6.

```
ln -s "<racine du projet>/vault" "$HOME/Malik VAULT/projets/<projet>"
```

Obsidian ne surveille pas les écritures faites hors de lui : recharger le coffre après le travail des
sessions. Jamais de lien de fichier, jamais de lien sous `.obsidian/`.

## 8. Ranger, vérifier, tenir

- `harnais ranger <dossier-projet> --simuler` (défaut) : écrit `vault/analyses/AAAA-MM-JJ-rangement-plan.md`
  (chaque déplacement, entête ajouté, lien réécrit, fichier refusé), rien d'autre.
- `harnais ranger <dossier-projet> --appliquer` : `git mv` (historique gardé), entêtes, liens, puis UN commit
  `chore(vault): rangement v2` ; pose `vault.range: true` dans `config/harnais.json` si `--verifier` rend 0.
- `harnais ranger <dossier-projet> --verifier` : liste les écarts, code 0 si aucun, 1 sinon.
- Vault : `chemins.vault` de `config/harnais.json` (défaut `vault`), lu sans `./` ni `/` final (`./vault/` = `vault`).
- Champ : les fichiers que git voit sous le vault (suivis, et non suivis non ignorés). Jamais touchés :
  `runtime/`, `echanges/Fxx.md` (fenêtres vivantes), fichiers ignorés par git, liens symboliques.
- Entêtes : seuls les champs manquants sont ajoutés. `projet` = `projet.nom` ; `type` par dossier ;
  `date` = date du nom, sinon du premier commit du fichier, sinon de sa modification ; `statut` par défaut :
  echange `annule`, revue `rendue`, decision `acte`, lecon `actée`, reprise `courant` (`reprise/Fxx.md`,
  carnet) ou `perime`, analyse et hypothese `clos` au-delà de 30 jours, sinon `ouvert` ; `tags` = une clé par
  type (`scripts/ranger-vault.mjs`, `TAG_PAR_TYPE`).
- Déplacements : `archives/` → `_archive/`, `archive-worktrees-logs/` → `_archive/archive-worktrees-logs/`,
  `retro/` → `analyses/` ; autre dossier → `_archive/<nom>/` ; fichier de premier niveau → `_archive/`.
  Une cible déjà occupée : le fichier est refusé, jamais écrasé.
- Secrets : un fichier qui porte un motif de secret (clé AWS, OpenAI, GitHub, Slack, clé privée, `api_key`)
  n'est ni déplacé ni réécrit ; le plan le liste (chemin et motif, jamais la valeur) et finit par
  « BLOQUÉ : secrets » ; `--appliquer` refuse.
- Barrière : dans un vault rangé, le hook `pre-commit` refuse un `.md` ajouté ou modifié sous le vault (hors
  `runtime/`, `_archive/`, `_assets/`, `echanges/Fxx.md`) sans ses cinq champs ou posé hors des dossiers du §1 ;
  le message donne le champ et la ligne à ajouter. Vault non rangé : avertissement seul.
- Dérive : une fois par jour, le superviseur lance `--verifier` sur chaque projet rangé ; un écart lève une
  alerte dans la tour (`VAULT_DERIVE`), levée au premier passage à 0 écart.
