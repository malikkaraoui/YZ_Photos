---
tags: [todo, prochaines-etapes, roadmap]
---

# Prochaines étapes

> Retour : [[YZPhotos]]

## Priorité haute

### 1. Icône de l'app
- [ ] Générer l'icône via Claude Design (prompt fourni dans cette session)
- [ ] Exporter en 1024×1024 PNG sans canal alpha
- [ ] Ajouter dans Xcode → Assets.xcassets → AppIcon
- [ ] Vérifier le rendu sur iPad (coins arrondis Apple appliqués auto)

### 2. Redesign SettingsView
- [ ] Obtenir le code SwiftUI redesigné depuis Claude Design
- [ ] Remplacer `YZPhotos/Features/Settings/SettingsView.swift`
- [ ] Tester dark mode + Dynamic Type

### 3. Soumission App Store
- [ ] Créer l'app dans App Store Connect
- [ ] Screenshots iPad 13" (6 max, 1 obligatoire)
- [ ] Description en français
- [ ] Vérifier les entitlements (aucun spécial requis pour accès SSD via picker)
- [ ] Archive + upload via Xcode → Organizer

## Priorité moyenne

### 4. Live Photos
- [ ] Traiter les paires `.HEIC` + `.MOV` comme une unité
- [ ] Afficher l'indicateur Live Photo dans la grille

### 5. Partage / Export
- [ ] Partager un fichier depuis l'aperçu (UIActivityViewController)

### 6. Widgets / raccourcis
- [ ] Widget « N fichiers restants à trier »

## Risques résiduels connus

| Risque | Statut | Mitigation |
|--------|--------|-----------|
| Move hors .photoslibrary via URL scoped | Non testé en prod | DriveChecksView check #4 |
| Vitesse USB sur très gros SSD (>500k fichiers) | Non mesuré | Scan incrémental, pas de rescan complet |
| exFAT mtime granularité 2s | Géré | Tolérance dans FileStore.upsertBatch |
| Paires Live Photos séparées | Connu | Noté v2 |

## Sessions de développement passées

| Date | Travail |
|------|---------|
| Juin 2026 (session 1–3) | MVP complet : DB, scan, triage, corbeille |
| Juin 2026 (session 4–6) | Doublons, grilles, dossiers, stats |
| Juin 2026 (session 7–9) | Settings, dark mode, autoplay, pinch zoom, multi-select |
| Juin 11, 2026 | Fix crashs (mémoire + background), bouton désélectionner direct |
| Juin 12, 2026 | 38 commits + push GitHub + vault Obsidian |

## Comment reprendre une session

1. Ouvrir ce vault dans Obsidian
2. Partir de [[YZPhotos]] → naviguer vers la note pertinente
3. Lire [[Bugs/Fixes]] pour ne pas réintroduire des régressions
4. Le code source est sur GitHub : https://github.com/malikkaraoui/YZ_Photos
