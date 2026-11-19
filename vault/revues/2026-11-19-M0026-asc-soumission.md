---
date: 2026-11-19
tags: [release, M0026, app-store, asc-api]
projet: yzphotos
type: revue
session: F07
mandat: M0026
statut: STOP-soumission-refusee
---

# Revue M0026 : textes, captures, aperçus et soumission App Store Connect

## Résultat

Textes FR/EN, 14 captures et 2 aperçus iPad 13" envoyés via fastlane 2.242.0. La soumission de la version 1.0.0 (build 0.4) est refusée par Apple : il manque `socialMedia`, `supportUrl` et `privacyPolicyUrl`. Statut final : non soumise. « En attente de vérification » non atteint. Aucune URL, aucun contact, aucun tarif, aucune confidentialité ni âge modifié par la session.

## Sorties clés

- Garde 1 : `origin/finitions-v1` = `a242e4ae9f0748ab6c4102401e49406c9aa1e65a`. OK.
- Garde 3 : `~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8` ; `config.env` : `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` (chemin inexistant).
- Garde 4 : `fastlane 2.242.0` (brew).
- Garde 5 : 8 PNG fr-FR, 6 PNG en-US ; `yzphotos-preview.mp4` (38 Mo) et `yzphotos-preview-en.mp4` (38 Mo) présents.
- Métadonnées : « Successfully set the version to '1.0.0' » ; textes FR et EN « Uploading metadata ... localized version ... fr-FR / en-US ».
- Captures : « Successfully uploaded all screenshots » (14 fichiers).
- Aperçus : `Uploaded preview video ... for locale fr-FR (set IPAD_PRO_3GEN_129)` ; idem `en-US` ; « Successfully uploaded and sorted App Preview videos. ».
- Build : « Latest upload for version 1.0.0 on ios platform is build: 0.4 ».
- Soumission 1 : bloquée par le précheck (« Precheck cannot check In-app purchases with the App Store Connect API Key »). Relancée avec `--run_precheck_before_submit false`.
- Soumission 2 : « Selecting build 1.0.0 (0.4) » ; « Successfully updated contents rights declaration » ; refus Apple :

```
appStoreVersions with id 'd39c893f-1e1f-4e4b-969c-edb22e474742' is not in valid state. - This resource cannot be reviewed, please check associated errors to see why.
The provided entity is missing a required attribute - You must provide a value for the attribute 'socialMedia' with this request
The provided entity is missing a required attribute - You must provide a value for the attribute 'supportUrl' with this request
The provided entity is missing a required attribute - You must provide a value for the attribute 'privacyPolicyUrl' with this request
```

## Écarts avec le mandat

- Le mandat prescrit un JSON `key_filepath` : fastlane 2.242.0 refuse (« missing field(s): key »). Utilisé `key: null` + `filepath`.
- `ASC_KEY_PATH` de `config.env` ne pointe pas vers la clé réelle. Chemin réel utilisé.
- Aperçus : fastlane exige le type d'appareil dans le nom de fichier. Copies renommées dans `.dd/previews/` (pas de script maison).
- Précheck désactivé à la soumission (non prévu dans la commande du mandat ; l'intention « précheck false » de l'étape 2 est reprise).
- Le worktree `M0026` n'a pas pu être retiré (`.dd` non suivi). Non forcé.

## Points ouverts (à faire par Malik)

- Dans App Store Connect : renseigner `socialMedia`, `supportUrl` et `privacyPolicyUrl`. Malik avait indiqué l'URL de confidentialité : Apple la voit absente, à vérifier au niveau version ou fiche app.
- Ensuite : relancer la soumission (`--submit_for_review true`, build 0.4, `--automatic_release false`).
- Build 0.4 : « traité » non vérifié au-delà de `app_store_build_number`.
- Remontée harnais : REM0528 (recette de clé fastlane incorrecte dans le gabarit).

## Notation des leçons injectées

| Leçon | Notation | Raison |
|---|---|---|
| 2026-09-22-la-surface-de-production-d-un-changement-se-releve-dans-le-diff-pas-dans-la-declaration-de-l-auteur.md | sans-objet | Mandat sans diff de code (aucun commit) ; la surface réelle a été lue sur App Store Connect (refus Apple), pas déclarée. |
| 2026-09-01-un-deploiement-qui-ne-rejoue-qu-une-partie-de-ses-etapes-se-declare-complet.md | a-aide | Le rapport ne déclare pas l'envoi complet : statut « non soumise », étapes restantes listées, build « traité » non vérifié au-delà de la ligne fastlane. |

Mandat relu : M0026
