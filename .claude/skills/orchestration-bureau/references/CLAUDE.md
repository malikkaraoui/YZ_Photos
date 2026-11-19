# SKILL-orchestration-maison/references/ -- commandes et pièges

## Commandes
- Horodatage `derniere_maj` d'un mandat : `TZ=<projet.timezone> date +%Y-%m-%dT%H:%M:%S%z`
- Passer un mandat à `pret-a-lancer` (macOS) : `sed -i '' 's/^statut: en-pose$/statut: pret-a-lancer/' <echanges>/Fxx.md`
- Effet d'un rapport, depuis la racine après `git fetch origin` : `node scripts/verifier-rendu.mjs effet --rapport <echanges>/Fxx.md`
- Contrôle de taille et de largeur, lecture seule : `sh "$(git config core.hooksPath)/pre-commit" --controle <tip> --base "$(git merge-base origin/<principale> <tip>)"`

## Pièges
- Sous macOS, `sed -i` exige l'argument `''` ; sous Linux, il s'omet.
- Les guillemets de la ligne de lancement manuel doivent être droits : un guillemet typographique casse le trigger.
- Libérer un mandat SUSPECT : statut `reponse-disponible` d'abord, puis suppression du verrou ; l'inverse relance le mandat aussitôt.
- Un réveil existant ne se modifie pas : le supprimer puis le reprogrammer.
- Le `ff-only` est refusé si des commits du vault restent locaux : les pousser avant le merge.
- Le `ff-only` est refusé si un fichier modifié localement est touché par le merge : le committer d'abord, en pathspec explicite.
- Deux mandats à preuve d'écran ne tournent pas en parallèle si l'outil de capture est unique.
