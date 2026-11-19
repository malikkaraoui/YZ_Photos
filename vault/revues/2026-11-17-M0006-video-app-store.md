---
date: 2026-11-17
tags: [design, marketing, video, app-store, M0006]
mandat_id: M0006
session: F01
statut: reponse-disponible
projet: yzphotos
type: revue
---

# M0006 — Vidéo d'aperçu App Store complète de YZPhotos (avec musique, sans voix off)

**Son = extrait de maquette, licence à régler par Malik avant l'envoi à Apple.**

## Gardes
- Garde 1 : `git --no-optional-locks rev-parse main` = `a3f0745b6ed95d32f52369f9abfe512b3f98ae2e` au début (23:05) et à la fin (conforme).
- Aucune écriture git ; aucun fichier du dépôt yzphotos, de `scene2-v2/` ni du dossier de photos modifié (lecture seule ; `scene2.mp4`
  est lu, jamais réécrit). Aucun `sleep`, aucune tâche de fond restante (Chrome tué par `drive.mjs` à chaque capture). Sous-agents :
  deux relecteurs FRAIS en lecture seule, aucun n'a écrit dans `vault/`.

## Résultat
Livré dans `/Users/malik/Documents/yzphotos-marketing/video-v1/` (hors dépôt) :
- `yzphotos-preview.mp4` — 1600 × 1200, 30 i/s, 872 images = 29,067 s, H.264 High 4.0 (10,3 Mb/s) balisé BT.709, AAC LC stéréo
  48 kHz 262 kb/s, −14,2 LUFS intégré, crête vraie −1,9 dB, 38,5 Mo. MD5 flux vidéo `a393631b…`, flux audio `e42c5e6b…`.
- `yzphotos-preview-sans-son.mp4` — même flux vidéo (copié), sans audio.
- `monter.sh` — refait tout le montage en une commande (~26 s) ; `--audio <fichier>`, `--audio-debut <s>`, `--capturer` ; refuse un
  audio trop court ou illisible. `work/` (≈ 1 Go d'images PNG) se régénère par `--capturer`.
- Sources des scènes : `common/` + `scene1|3|4|5|6/index.html` ; outils dans `tools/` ; `PLAN.md` écrit avant production.
- `shots/` : `scene1-le-probleme.png` … `scene6-signature.png`, `final-01…12.png` (fps=0.42), 8 planches `preuve-*.png`.

## Contraintes Apple (sources)
- App preview specifications : https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications
  15–30 s · ≤ 500 Mo · .mov/.m4v/.mp4 H.264, progressif, jusqu'à High Profile 4.0, 10–12 Mb/s visés · ≤ 30 i/s ·
  audio stéréo AAC 256 kb/s, 44,1 ou 48 kHz, pistes activées · iPad 13" paysage : 1600 × 1200 (résolution « acceptée ») ·
  affiche par défaut à 5 s. Écart avec la fiche : débit audio 256 kb/s imposé par Apple → suivi.
- App Review Guidelines 2.3.4 : https://developer.apple.com/app-store/review/guidelines/ — « previews may only use video screen
  captures of the app itself » ; narration et surimpressions autorisées. **Risque** : vidéo majoritairement illustrée.

## Musique
« All of You (Instrumental Version) » — Swif7, Vicki Vox (Epidemic, id eee8fa85-…), extrait public lq (188 s, MP3 48 kHz),
téléchargé par curl (succès). Analyse : grille 130 BPM calée à 0,455 s ; temps fort = coup de basse (k ≡ 3 mod 4).
Structure retenue 121,839 → 150,906 s : fin de partie pleine → creux (124,6–132,9) → montée (coups de basse sur les temps forts)
→ silence → **drop à 140,301 s** → partie pleine. Drop placé à 18,462 s de la vidéo (temps 40) = apparition du « +38 Go » ;
mesuré à 18,470 s dans le fichier final. Fondus 0,3 s / 0,8 s, `loudnorm` deux passes −14 LUFS / −1 dBTP, AAC 256 kb/s.

## Minutage (temps de la vidéo, 1 temps = 0,4615 s)
| Scène | Temps | Secondes | Images |
|---|---|---|---|
| 1 Le problème | 0–10 | 0–4,615 | 0–142 |
| 2 Les disques (scene2.mp4 intacte) | 10–27 | 4,615–12,462 | 134–377 (+ 4 images tenues) |
| 3 Le geste | 27–37 | 12,462–17,077 | 369–516 |
| 4 Les doublons (drop temps 40) | 37–47 | 17,077–21,692 | 508–654 |
| 5 Confidentialité | 47–55 | 21,692–25,385 | 646–765 |
| 6 Signature (+ noir 0,4 s) | 55–63 | 25,385–29,067 | 757–871 |
Raccords : fondus de 9 images centrés à ≤ 12 ms des temps 10, 27, 37, 47, 55. Scène 3 : lâchers aux temps 28, 32, 36 (premiers temps
de mesure, coups de basse de la montée), glisses 0,56 / 0,35 / 0,20 s, vol qui prolonge l'élan. Scène 5 : plaques aux temps 48, 49,
50, phrase au temps 51. Scène 6 : pulsation de l'icône au temps 60.

## Chaîne
HTML plein cadre 1600 × 1200 par scène avec `__seek(t)` déterministe (t = temps de la vidéo) → `tools/capture.mjs` →
`drive.mjs` du kit anatomy (Chrome sans tête, une capture PNG par image, comme scene2-v2) → x264 par scène (`scenes/`) →
`monter.sh` : xfade 0,3 s, scène 2 intacte (`tpad` 4 images en fin), fondu au noir, musique, deux sorties.
Scène 1 : frise en canvas 2D avec projection perspective maison (ordre du peintre en champ de hauteurs, photo plaquée par deux
triangles affines). Scène 3 : iPad en CSS 3D (14 couches de tranche alu), écran HTML reprenant `TriageDeckView`/`SwipeCardView`
(en-tête verre 66 pt r26, cartes 430 × 581 r28 pile ×0,04/16 pt, barre info, bouton pivoter, teinte overlay, tampons 26 pt
heavy, pilule 3 boutons 48/40/48, aléatoire 52, légende, barre d'onglets iPad en haut).

## Choix faits seul
- « SUPPRIMER » (fiche) au lieu de « POUBELLE » (app, `TriageDeckView.swift:293`).
- Photo `IMG_5679.jpg` exclue (voiture de marque reconnaissable) en plus des deux exclusions imposées ; 11 photos utilisées.
- Scène 2 non multiple d'un temps : jouée entière, dernière image tenue 0,13 s dans le fondu sortant.
- Passage musical : creux de 8 s (scène 2) accepté pour avoir un vrai drop sur le gain.
- Chiffres d'exemple : +38 Go, 312 groupes · 38 Go, 68 412, 1 284 à trier, tailles des doublons.
- Plaque « Je garde. Je supprime. » : texte blanc + pastilles verte/rose (le texte coloré manquait de contraste sur le fond).
- Couleurs : conversion et balises BT.709 (sans balise, un lecteur Apple suppose BT.709 en HD et décale la charte) ; scene2.mp4
  (BT.601 non balisée) convertie matrice à matrice, contenu inchangé (écart mesuré 1,7/255).
- Scène 1 : recadrage propre à chaque pavé et réseau de photos sans voisin identique.
- Scène 6 : dézoom passé d'un départ brusque (outQuint) à un départ et une arrivée amortis (smootherstep).

## Contrôles
Tableau exigence / verdict / preuve : rapport M0006 dans `vault/echanges/F01.md` (31 lignes : 29 OK, 2 KO partiels déclarés —
passage musical non énergique de 2,8 à 11,1 s, « dernier accord » non tenu). Les 12 `final-*.png` ont été lus un par un (trois
fois au fil des corrections ; la dernière fois seulement les 3 images changées, les 9 autres mesurées identiques à ≤ 0,6/255).
Tests de `monter.sh` : fichier audio absent → code 1 + message ; option inconnue → code 2 ; `--audio` sinus → audio remplacé
(−13,9 LUFS) ; retour par défaut → MD5 du flux audio identique (`e42c5e6b284eaab1c73459746233f99a`).

## Relecture
1. Sous-agent frais, lecture seule (23:35–23:44) : 27 CONFIRMÉS, 1 INFIRMÉ (gestes aux temps 30/34 = 3es temps sans basse).
   Constats : ffprobe collé périmé, couleurs non balisées, « Fusionner tout » illisible sous le cercle, répétitions S1, pas de
   contrôle de durée audio, p10 dans `assets/`, « dernier accord » non tenu, double image du fondu S2→S3. Tous corrigés sauf les
   deux derniers (écarts déclarés).
2. Contre-vérification par un second sous-agent frais (23:50–23:58) : 8/8 CONFIRMÉS. Ses constats « la carte s'arrête sur le temps »
   et « voisins identiques en S1 » ont été corrigés ensuite, puis vérifiés par mesure (vitesse par image croissante au lâcher) et
   par lecture des images changées.

## Notation des leçons injectées
Mandat relu : M0006
aucune leçon injectée

## Ce qui manque / décisions pour Malik
1. Licence de la musique (extrait de maquette) : télécharger le morceau licencié puis `./monter.sh --audio <fichier>`.
2. Risque App Review 2.3.4 : aperçu fait d'illustrations, pas de captures réelles. Options : (a) soumettre tel quel ;
   (b) garder cette vidéo pour le site et les réseaux, et faire l'aperçu App Store avec de vraies captures d'écran iPad
   + surimpressions ; (c) mixte (scène 3 remplacée par une vraie capture). Choix proposé : (b).
3. Affiche : choisir ≈ 19,6 s ou 28 s dans App Store Connect (défaut 5 s = iPad en vol).
