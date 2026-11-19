---
date: 2026-11-19
tags: [design, marketing, M0023, revue]
projet: yzphotos
type: revue
session: F01
mandat: M0023
statut: GO-avec-reserves
---

# Revue M0023 — vidéo d'aperçu App Store, version anglaise

## Livrables (dans `/Users/malik/Documents/yzphotos-marketing/`, hors dépôt)
- `scene2-v2-en/scene2.mp4` : 1600×1200, 30 i/s, 240 images, 8,000 s, H.264 High 4.0, sans son.
- `video-v1-en/yzphotos-preview-en.mp4` : avec son, 872 images, 29,067 s, AAC 256 kb/s 48 kHz stéréo.
- `video-v1-en/yzphotos-preview-en-sans-son.mp4` : même vidéo sans son.
- `video-v1-en/shots/` : `en-01…12.png` (images extraites de la vidéo anglaise), `compare-01…12.png` (FR à gauche, EN à droite, mêmes instants).
- `video-v1-en/TEXTES.md` : table FR → EN (rédigée après les modifications, écart de procédure).

## Relecture
- Sous-agent frais, lecture seule : verdict GO, planche par planche sur les 12. Aucun mot français restant, aucun débordement.
- Relecture du lead sur la planche 11 après correction : le bandeau « Everything stays between your iPad and your drive. » déborde à 62 px ; corps ramené à 50 px dans la copie. Les tuiles et le reste de la scène sont inchangés.
- Contrôle à pleine résolution de deux zones de petit texte (scène 2 et scène 3) : anglais, lisible, sans débordement. Les autres petits textes n'ont pas été relus à zoom 100 % : limite connue.

## Choix assumés
- Nombres au format US (`68,412`, `1.24 TB`, `26.3 MB`) et séparateur de milliers passé en virgule dans `common.js` (copie).
- Traductions hors `Localizable.xcstrings` : « Disques » → « Drives », « DÉBRANCHÉ » → « DISCONNECTED », « Branchez-le pour reprendre le tri » → « Plug it in to resume sorting », « recherche du partage… » → « searching for share… », « CONNEXION… » → « CONNECTING… », « Parcourir » → « Browse », « Brancher un autre disque… » → « Connect another drive… ». Le catalogue contient des formes voisines ; à relire par Malik.
- Onglets : « Duplicates » et « Screenshots » plus longs que leurs équivalents FR ; tiennent dans la barre.

## Points ouverts
- Traductions ci-dessus à valider par Malik.
- Textes d'accessibilité et commentaires de `scene2-v2-en/index.html` et `build.mjs` restent en français (aria-label de la scène 2, non affiché).
- Aucune écriture dans le dépôt yzphotos ; `video-v1/` et `scene2-v2/` intacts.

## Verdict
GO avec réserves : livrables produits et contrôlés ; réserve = validation humaine des traductions hors catalogue.
