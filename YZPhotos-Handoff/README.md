# YZPhotos — Pack de handoff

Tout le nécessaire pour produire les assets finaux et animer le teaser de l'app **YZPhotos**
(tri de photos/vidéos sur SSD externe et photothèques Apple · iOS / iPadOS 18+).

Direction visuelle : **Liquid Glass** · palette **« Optimistic Synergy »**.

---

## Contenu du pack

```
YZPhotos-Handoff/
├── README.md                     ← ce fichier
├── Teaser.storyboard.json        ← spec déterministe du teaser (pour LLM / Hyperframes)
├── source/                       ← maquettes hi-fi runnable (HTML/JSX) de TOUS les écrans
├── icon/
│   ├── AppIcon.appiconset/       ← prêt à glisser dans Xcode (iOS 18, 3 apparences)
│   │   ├── Contents.json
│   │   ├── AppIcon-1024.png         (Light / défaut)
│   │   ├── AppIcon-Dark-1024.png    (Dark)
│   │   └── AppIcon-Tinted-1024.png  (Tinted)
│   ├── dark/   AppIcon-{20,29,40,58,60,76,80,87,120,152,167,180,1024}.png
│   ├── light/  AppIcon-{120,180,1024}.png
│   └── tinted/ AppIcon-{120,180,1024}.png
└── graphics/
    ├── tokens.css                ← couleurs, verre, rayons, type (drop-in CSS)
    ├── tokens.json               ← mêmes tokens, lisibles par machine
    ├── motion.json               ← paramètres du geste de swipe + transitions UI
    ├── apple-photos-logo.svg     ← logo Photos d'Apple (vectoriel)
    └── photos/                   ← 10 photos de démo + règle de distribution
```

> **3 thèmes.** Le système se décline en `light` (neutre/Linear, accent indigo, fonds clairs/texte sombre), `dark`, et `glass` (Liquid Glass sur aurora Storm Blue — direction principale). Valeurs exactes des 3 dans `graphics/tokens.json` / `graphics/tokens.css` (`[data-theme="light|dark|glass"]`) et dans `source/proto/yz-shared.css`.

> **Layouts hi-fi.** Le dossier `source/` contient les maquettes runnable de chaque écran (Prototype, planche Écrans, UI Kit, App Store, onboarding, micro-interactions, widgets) + leur source JSX. Voir `source/README.md`.

---

## 1 · Icône

**Concept** « Faille × Aurora » : une photo déchirée en deux sur un mesh aurora — à gauche le ✕ (poubelle), à droite le ✓ (garder). Le geste de tri, devenu emblème.

- **App Store / marketing** : `icon/dark/AppIcon-1024.png` (ou la variante voulue).
- **Xcode** : glisser le dossier `icon/AppIcon.appiconset/` dans `Assets.xcassets`. Il contient les 3 apparences iOS 18 (Light / Dark / Tinted) en 1024×1024, taille unique.
- **Tailles legacy** : le dossier `icon/dark/` fournit toutes les tailles px si besoin d'un set complet.
- Coins **carrés** — iOS applique l'arrondi automatiquement. Ne pas pré-arrondir.

> ⚠️ App Store Connect refuse parfois un canal alpha. Les PNG sont **entièrement opaques** mais conservent un canal alpha. Si un upload est refusé, aplatir (Aperçu → Exporter sans alpha, ou `pngcrush -rem alpha in.png out.png`).

### Régénérer / modifier l'icône
Le rendu est paramétrique (Canvas). Voir le projet : `proto/icon-final.js` expose `drawIcon(ctx, W, H, variant)` avec `variant ∈ {dark, light, tinted}`. Studio visuel : `YZPhotos Icône.html`.

---

## 2 · Teaser — `Teaser.storyboard.json`

Spec **déterministe** et auto-suffisante pour reconstruire le teaser (9:16, ~20 s, 30 fps).
Structure clé :

- `meta` — format, résolution, fps, système de coordonnées, notes d'animation.
- `palette` / `glass_style` / `typography` — tokens exacts.
- `assets` — chemins réels + **règle de sélection des photos**.
- `background_layer` — gradient + halos avec **formule de dérive** (jamais statique).
- `easing_library` — easings nommés.
- `scenes[]` (5) — chacune : `time`, `intent`, `camera`, `elements[]` avec **keyframes** `{prop, from, to, start, end, ease}`.
  - `S3_swipe` contient le **modèle complet du deck** : `deck[]` (seed/commit/dir), phases anticipation+vol, offsets de pile, tampons, teintes.
- `transitions` + `audio` (hits calés sur les commits).

Les temps de `S3_swipe.deck[].commit_local_s` sont **locaux** à la scène : ajouter `6.6` pour le temps global.

---

## 3 · Éléments graphiques

- **`tokens.css`** — drop-in : variables `--yz-*` + classe `.yz-glass` prête à l'emploi.
- **`tokens.json`** — mêmes valeurs pour génération de code (SwiftUI, Tailwind, etc.).
- **`motion.json`** — seuils du swipe (110 px / flick), durées, easings, undo, haptique, transitions UI.
- **`apple-photos-logo.svg`** — logo Photos d'Apple reconstruit (moulinet 8 pétales, centre blanc). *Marque Apple — usage maquette.*
- **`photos/`** — 10 photos de démo + `README.md` (règle de distribution `index = (seed*3+1) mod 10`, `object-fit: cover`).

### Recette du verre (liquid glass)
```css
background: rgba(255,255,255,0.14);
backdrop-filter: blur(24px) saturate(1.65);
border: 0.5px solid rgba(255,255,255,0.45);
box-shadow: inset 0 0.5px 0.5px rgba(255,255,255,0.9),  /* reflet de bord */
            0 14px 40px rgba(8,28,38,0.4);               /* ombre portée */
```
Toujours sur un fond coloré (le `background_layer` ou une photo) — le blur a besoin de matière.
Bord **hairline 0.5px**, jamais plus épais.

### Couleurs sémantiques
| rôle | couleur |
|---|---|
| Garder (swipe →) | `#B6D84B` (Sulphur) |
| Poubelle (swipe ←) | `#F06A8C` (Confetti) |
| Action principale | `#E87B3E` (Mandarin) |
| Fond | dégradé Storm Blue `#3A5C6E → #244252 → #10242E` |

---

## 4 · Thèmes (clair / sombre / verre)

Le design system a **trois thèmes**, pilotés par `data-theme` :

| thème | usage | accent | garder/poubelle | fond | texte |
|---|---|---|---|---|---|
| `light` | neutre, sobre | `#5B5BD6` indigo | `#28B463` / `#E5484D` | blanc/gris | sombre |
| `dark` | sombre | `#8A88FF` | `#3DD27F` / `#FF5C61` | `#0C0C0E` | clair |
| `glass` | **principal** — Liquid Glass | `#E87B3E` | `#B6D84B` / `#F06A8C` | gradient Storm Blue | blanc |

En `light`/`dark`, les surfaces sont opaques (ombres douces). En `glass`, les surfaces sont translucides (`backdrop-filter`) sur le gradient aurora. Drop-in : `graphics/tokens.css`.

## 5 · Typographie
**SF Pro** (system-ui). Display en poids 800, letter-spacing −0.03em. Respecter Dynamic Type pour l'app. Aucune fonte à embarquer (police système).

---

## Notes
- Le geste de tri (« Garder / Poubelle ») est le cœur de l'app : direct, lisible, **réversible** (corbeille différée, rien n'est supprimé sans confirmation).
- Différenciateur produit : lecture des **photothèques `.photoslibrary` Apple + dossiers**, en USB-C **ou réseau** (Freebox, NAS), sans jongler entre photothèques.
- Pour le détail des écrans et composants, se référer au projet HTML source (prototype, UI Kit, planche écrans).
