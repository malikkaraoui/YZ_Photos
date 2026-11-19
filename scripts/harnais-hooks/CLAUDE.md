## Commandes
- Contrôle de taille et de largeur, lecture seule, d'un ref : `sh "$(git config core.hooksPath)/pre-commit" --controle <ref> [--base <ref>] [--lignes]`
- Même contrôle depuis le dépôt du harnais : `sh scripts/controle-instructions.sh <ref> --base <ref>`
- Lignes trop larges d'un fichier fautif : `sh "$(git config core.hooksPath)/pre-commit" --controle <ref> --lignes`
- Relever la limite d'un seul commit (sans trace versionnée) : `ROTATION_LIMITE=<octets> git commit ...`
- Tests du hook de commit : `node --test scripts/harnais-hooks/pre-commit.test.mjs`
- Tests du hook de message : `node --test scripts/harnais-hooks/commit-msg.test.mjs`
- Tests du hook de push : `node --test scripts/harnais-hooks/pre-push.test.mjs` (`HOOK_PRE_PUSH=<chemin>` pour rejouer sur une autre version du hook)

## Pièges
- `pre-merge-commit` refuse le merge si `pre-commit` n'est pas exécutable : `chmod +x` avant.
- Une config présente sur disque mais absente de l'index n'est pas lue : `git add` d'abord, sinon ce sont les défauts (ligne sur stderr).
- `ROTATION_LIMITE` invalide (zéro en tête, non numérique, plus de 9 chiffres) : la limite par défaut s'applique, avec une ligne sur stderr.
- `INSTRUCTIONS_MAX_CARACTERES` qui relève le seuil passe, avec une ligne sur stderr : rien ne le trace dans le dépôt.
- `TRAILERS_RETIRES` défini mais vide : rien n'est retiré du message de commit.
- `commit-msg` sort toujours 0 : un trailer manquant ne bloque jamais un commit.
- `--controle` sort 2 hors d'un dépôt git ou si la ref est introuvable ; 1 signifie `BLOQUE`.
- `git push --no-verify` saute `pre-push`.
- Un merge en avance rapide ne lance aucun hook : le filet est `--controle --base`.
- Le plafond N1 de `pre-push` exige git 2.40 ou plus ; en dessous, le push est refusé avec un message.
