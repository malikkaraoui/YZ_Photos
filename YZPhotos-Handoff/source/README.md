# Source — maquettes hi-fi (HTML/JSX runnable)

Les **layouts haute-fidélité de chaque écran** vivent ici. Ouvrir les `.html` dans un
navigateur (Chrome/Safari récent — le verre utilise `backdrop-filter`). Aucun build :
React + Babel sont chargés par CDN, le JSX est transpilé à la volée.

## Fichiers

| HTML | Contenu | Thèmes |
|---|---|---|
| `YZPhotos Prototype.html` | Écrans clés **interactifs** : Trier (swipe réel), Doublons, Corbeille. Bascule iPad/iPhone + **Verre / Clair / Sombre**. | 3 |
| `YZPhotos Écrans.html` | **Planche** de tous les écrans (Choix du disque, Analyse, Photothèques, Bibliothèque, Aperçu, Dossiers, Stats, Réglages, dialogues) en Verre + Clair + Sombre, iPad & iPhone. | 3 |
| `YZPhotos UI Kit.html` | Design system : couleurs, typo, rayons/ombres, 27 icônes, composants. Toggle ◈ Verre / Clair / Sombre. | 3 |
| `YZPhotos App Store.html` | 10 visuels marketing (iPhone portrait + iPad paysage). | glass |
| `YZPhotos Onboarding.html` | Flow d'accueil 4 écrans paginés. | glass |
| `YZPhotos Micro-interactions.html` | Le swipe décortiqué (états live + specs). | glass |
| `YZPhotos Widgets.html` | Widgets écran d'accueil (Lock / S / M). | glass |

## Où sont les layouts (JSX)

```
proto/
├── components.jsx     ← Icônes (SF Symbols), primitives (Btn, Badge, ProgressBar,
│                         Modal, PhotoThumb…), PhotoScene (pool photo + hash de distribution)
├── screens.jsx        ← Trier (deck swipe), Doublons, Corbeille
├── screens-extra.jsx  ← Choix disque, Analyse, Bibliothèque, Aperçu, Dossiers, Stats,
│                         Réglages, dialogue destructif, Photothèques (sources)
├── app.jsx            ← Shell prototype : device frames, tab bars, toggles thème
├── yz-shared.css      ← **Tokens des 3 thèmes** + tous les styles de composants/écrans
│                         (light/dark en haut, bloc [data-theme="glass"] en bas)
├── ui-kit.jsx         ← Documentation design system
├── app-store.jsx      ← Posters marketing
├── onboarding.jsx · micro.jsx · widgets.jsx · storyboard.jsx
├── icon-final.js      ← Rendu paramétrique de l'icône (drawIcon)
└── design-canvas.jsx · animations.jsx  ← scaffolds (canvas pan/zoom, moteur d'anim)
```

Le thème se pilote par l'attribut `data-theme` sur `.app-root` (`light` | `dark` | `glass`).
Les valeurs exactes des 3 thèmes sont dans `yz-shared.css` **et** dans `../graphics/tokens.json`.

## Dépendances incluses
- `exports/final/` — PNG de l'icône (faille×aurora) référencés par les maquettes.
- `assets/photos/` — les 10 photos de démo.
