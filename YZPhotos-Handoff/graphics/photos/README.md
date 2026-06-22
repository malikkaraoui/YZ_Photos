# Photos — placeholders exploitables

10 photos réelles utilisées comme contenu de démo dans toutes les maquettes
(deck de tri, bibliothèque, doublons, corbeille, aperçu, App Store, teaser).

| fichier | sujet |
|---|---|
| p1.jpg | portrait (chapeau léopard) |
| p2.jpg | illustration |
| p3.jpg | phare / paysage |
| p4.jpg | scène extérieure |
| p5.jpg | portrait |
| p6.png | illustration |
| p8.jpg | Ferrari (rouge mat) |
| p9.jpg | palmier au coucher de soleil |
| p10.jpg | lac d'Annecy (vue panoramique) |
| screenshot1.png | capture d'écran |

## Règle de distribution (anti-répétition)
Pour répartir les photos sans répétition adjacente ni alignement de colonnes
dans les grilles, on indexe par un hash modulaire :

```
index = (seed * 3 + 1) mod 10
```

où `seed` est l'indice de la cellule (grille) ou un identifiant stable de l'élément.
Multiplicateur 3 premier avec 10 → cycle complet, distribution variée.

`object-fit: cover` partout. Coins arrondis selon le contexte (voir tokens.css).
