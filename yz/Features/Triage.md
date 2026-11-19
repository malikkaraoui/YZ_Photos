---
tags: [feature, triage, swipe, deck, undo]
---

# Deck de tri (onglet Trier)

> Retour : [[YZPhotos]]

## Principe

ZStack des 3 cartes du haut. DragGesture sur la carte visible.
Alternative aux swipes : 3 gros boutons en bas.

## Swipe

| Direction | Action |
|-----------|--------|
| Droite (> 120pt) | **Garder** (status = 1, badge vert) |
| Gauche (> 120pt) | **Poubelle** (status = 2, badge rouge, déplacé dans .YZTrash) |

Rotation proportionnelle au déplacement. Retour élastique si seuil non atteint.

## Boutons

- **✓ Garder** (vert) — même effet que swipe droite
- **🗑 Poubelle** (rouge) — même effet que swipe gauche
- **↩ Undo** — annule la dernière action (restaurant depuis .YZTrash si besoin)

## Undo global

Le bouton Undo est également disponible **en overlay flottant (bottomTrailing) dans tous les onglets** via MainTabView.
Il réagit à `env.triage?.undoCount` via `onChange` — quand undoCount change, le deck se rafraîchit.

## Filtres et scope

Le deck peut être filtré depuis n'importe quel onglet :
```swift
TriageDeckView(
    drive: drive,
    root: root,
    filter: .screenshots,   // ou .photos, .videos, .all
    scope: "/Vacances 2023", // nil = tout le disque
    scopeTitle: "Vacances 2023",
    isModal: true            // présenté en fullScreenCover
)
```

## TriageViewModel

- `untriagedWindow(limit: 20)` — fenêtre glissante, rechargée après chaque action
- `matchesFilter` vérifie kind + préfixe de chemin si scope défini
- Préchargement des 8 images suivantes à 1280px (`cardCache`)

## Lecture vidéo

- Miniature + badge durée sur la carte
- Lecture inline AVPlayer
- Autoplay selon `env.settings.autoPlayVideos`
- Bouton ⤢ pour plein écran (`FullScreenPlayerView`)

## Compteur

```
"3 412 restantes" — calculé par untriagedCount(driveId:filter:scope:)
```
