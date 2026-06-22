---
tags: [architecture, database, grdb, sqlite]
---

# Base de données — GRDB SQLite

> Retour : [[YZPhotos]]

## Configuration

- **GRDB DatabasePool** en mode WAL
- Un fichier `.sqlite` par disque, clé = UUID du volume
- Stocké dans `Application Support` sur l'iPad
- Migration unique `v1` (tout dans `AppDatabase.swift`)

## Schéma

### Table `drive`
| Colonne | Type | Description |
|---------|------|-------------|
| id | TEXT PK | UUID du volume (ou SHA-256 du chemin) |
| name | TEXT | Nom affiché |
| bookmarkData | BLOB | Security-scoped bookmark persisté |
| totalBytes | INTEGER | Capacité totale du disque |
| lastScanCompletedAt | DATETIME | Horodatage de la dernière analyse |
| scanGeneration | INTEGER | Incrément pour purge des fichiers disparus |

### Table `file`
| Colonne | Type | Description |
|---------|------|-------------|
| id | INTEGER PK | Auto-increment |
| driveId | TEXT FK | Référence drive |
| relativePath | TEXT UNIQUE | Chemin NFC normalisé depuis la racine |
| fileName | TEXT | Nom du fichier |
| ext | TEXT | Extension en minuscules |
| kind | TEXT | `photo` / `video` |
| sourceType | TEXT | `folder` / `photoslibrary` |
| sizeBytes | INTEGER | Taille en octets |
| modifiedAt | DATETIME | mtime (tolérance 2s exFAT) |
| captureDate | DATETIME | Date EXIF si disponible |
| pixelWidth / pixelHeight | INTEGER | Dimensions en pixels |
| partialHash | TEXT | SHA-256(taille\|\|head 64Ko\|\|tail 64Ko) |
| fullHash | TEXT | SHA-256 complet (confirmation doublons) |
| dHash | INTEGER | Hash perceptuel 64 bits |
| isScreenshot | BOOLEAN | Détecté par MediaClassifier |
| dupGroupId | INTEGER | Groupe de doublons (null si aucun) |
| dupKind | TEXT | `exact` / `proche` |
| status | INTEGER | 0=non-trié 1=gardé 2=corbeille 3=supprimé |
| trashName | TEXT | Nom dans .YZTrash (collision-proof) |
| scanGeneration | INTEGER | Pour purge des fichiers disparus |
| analyzedAt | DATETIME | NULL = en attente de passe 2 |

### Table `triage_action`
| Colonne | Type | Description |
|---------|------|-------------|
| id | INTEGER PK | Auto-increment |
| fileId | INTEGER FK | Fichier concerné |
| action | TEXT | `keep` / `trash` / `restore` |
| prevStatus | INTEGER | Status avant l'action (pour undo) |
| performedAt | DATETIME | Horodatage |

## Index

```sql
CREATE INDEX idx_file_drive_status_kind ON file(driveId, status, kind);
CREATE INDEX idx_file_size ON file(driveId, sizeBytes DESC);
CREATE INDEX idx_file_hash ON file(sizeBytes, partialHash);
CREATE INDEX idx_file_dupgroup ON file(dupGroupId);
```

## Requêtes clés (`Queries.swift`)

| Fonction | Description |
|----------|-------------|
| `untriagedWindow(driveId:limit:)` | Fenêtre de tri pour le deck |
| `gridRequest(driveId:filter:order:scope:)` | Grille paginée |
| `folderEntries(driveId:prefix:)` | Sous-dossiers avec agrégats |
| `duplicateGroups(db:driveId:)` | Groupes de doublons triés |
| `stats(driveId:)` | Compteurs dashboard |
| `bestOfGroup(_:)` | Fichier à garder dans un groupe |
| `reclaimableBytes(_:)` | Octets récupérables dans un groupe |
| `trashedFiles(driveId:)` | Fichiers en corbeille |

## FileStore (`FileStore.swift`)

```swift
// Upsert idempotent : skip si taille+mtime inchangés (tolérance 2s exFAT)
upsertBatch(_ metas: [FileMeta], driveId: String, generation: Int)

// Passe 2 : fichiers sans analyzedAt
pendingAnalysis(driveId: String, limit: Int) -> [FileRecord]

// Écriture des résultats d'analyse (hash, dHash, miniature)
applyAnalysisBatch(_ results: [FileAnalysis])

// Purge des fichiers absents du scan courant
pruneStale(driveId: String, generation: Int)
```
