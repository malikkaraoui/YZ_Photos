---
tags: [feature, doublons, keepbest, runcontrolpanel]
---

# Onglet Doublons

> Retour : [[YZPhotos]] | Architecture : [[Architecture/Duplicates]]

## DuplicateGroupsView — layout

```
NavigationStack
└── MasterDetailLayout
    ├── Gauche : groupsList
    │   ├── Section runControlPanel
    │   └── Section groupes (header : N groupes · X Go récupérables)
    │       └── ForEach groupRow(group)
    └── Droite : FilePreviewPane ou SelectionSummaryPane
```

## runControlPanel — états

### En cours
```
[⏳] Étape 2/4 — Confirmation octet par octet    [⏸ Pause] [⏹ Arrêter]
Chaque groupe candidat est relu en entier...
████████░░░░░░ 234 / 891 groupes vérifiés
```

### Inactif
```
[texte état]                    [🔍 Rechercher les doublons]
La recherche compare les empreintes...
```

### Phases affichées
| Phase | Titre | Explication |
|-------|-------|-------------|
| findingCandidates | Étape 1/4 — Repérage | Taille + empreinte rapide |
| confirming | Étape 2/4 — Confirmation | Lecture octet par octet |
| comparingVisuals | Étape 3/4 — Comparaison visuelle | dHash photos |
| writing | Étape 4/4 — Enregistrement | Écriture en base |

## groupRow — layout par groupe

```
[Identiques] ou [Similaires]  ·  N fichiers · X Mo récupérables    [🗑 Tout supprimer] [⭐ Garder la meilleure]
ScrollView horizontal :
  [★ meilleure] [doublon 2] [doublon 3] ...
   ← triée par : best en premier, puis sizeBytes DESC
```

## Vignette doublon

- Tap → aperçu à droite (FilePreviewPane)
- Bouton ○/✓ (topTrailing) → toggle sélection multiple
- ★ jaune (topLeading) → meilleur fichier du groupe
- Cadre rouge si sélectionné, cadre accentColor si en aperçu

## Multi-select toolbar (si sélection active)

```
[✕ Désélectionner]  [🗑 Mettre à la poubelle (N · X Go)]
```

Bouton Rechercher désactivé si scan en cours (phase .enumerating).

## Badge onglet

Un point ● orange apparaît sur l'onglet Doublons quand `env.duplicates.isRunning`.

## Réactivité

`onChange(of: env.triage?.changeTick)` → reload après tout undo ou action de tri.
`onChange(of: env.duplicates.phase == .finished)` → reload après fin de recherche.
