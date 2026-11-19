---
projet: yzphotos
type: decision
date: 2026-11-19
statut: acte
tags: [release, app-store, soumission, v1]
---

# Soumission de la v1 (19/11/2026)

- **Version** : 1.0.0, build 0.4, soumise à App Store Connect le 19/11/2026. En attente de vérification chez Apple.
- **Publication** : manuelle, après accord d'Apple.
- **Modèle** : app gratuite (sans achat, sans publicité).
- **Langues** : fr (par défaut) + en.
- **Chaîne de livraison** : fastlane, avec la clé API App Store Connect lue dans `~/.appstoreconnect` (nom du fichier seulement, contenu jamais affiché ni versionné).
- **Code soumis** : `origin/finitions-v1` (`a242e4ae9f0748ab6c4102401e49406c9aa1e65a`), intégré dans `main` par le merge `7503a9a` (doublage R002 : GO).

## Tickets ouverts à la soumission

- #2 : analyse et doublons en arrière-plan (BGContinuedProcessingTask), ouvert antérieurement.
- #3 : libellé « photothèque Apple » absent sur la carte de tri (`SwipeCardView.swift`).
- #4 : iOS affiche « Autre » en français en mode anglais (ajouter `en` à `CFBundleLocalizations`).
- #5 : `NSLocalNetworkUsageDescription` sans traduction anglaise.
- #6 : écran « Les 7 vérifications » se réinitialise au redimensionnement de la fenêtre.
- #7 : visuels App Store anglais (panoramas, en-tête, résultats de recherche) à exporter et envoyer par l'API.
- #8 : `scripts/verifier-textes-fr.py` ne voit pas les littéraux sans accent renvoyés par un `switch`.
