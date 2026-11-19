---
tags: [architecture, doublons, dhash, bktree, unionfind]
---

# Détection de doublons

> Retour : [[YZPhotos]]

## Deux types de doublons

| Type | Méthode | Critère |
|------|---------|---------|
| **Exacts** | SHA-256 complet | Octet pour octet identiques |
| **Quasi-doublons** | dHash Hamming | Rafales, recompressions, redimensionnements |

## DHash — hash perceptuel 64 bits

```
Image → miniature 9×8 pixels (niveaux de gris)
     → 72 valeurs comparées horizontalement
     → 64 bits de différences
     → UInt64 stable
```

- **Invariance** : recompression JPEG, redimensionnement léger, changement de luminosité
- **Seuil** : distance de Hamming ≤ 8 bits = quasi-doublon
- **Performance** : <1 ms/image (calculé sur la miniature déjà décodée)

## BK-Tree — recherche approximative

```swift
BKTree.insert(hash: UInt64, id: Int64)
BKTree.search(hash: UInt64, radius: 8) -> [Int64]  // fileIds
```

- Métrique : distance de Hamming sur UInt64
- Construit en mémoire pour chaque recherche
- Complexité : O(log n) en pratique vs O(n) brute-force

## DuplicateFinder — pipeline complet

```
Étape 1 : candidats par (sizeBytes, partialHash)
    ↓
Étape 2 : confirmation fullHash octet par octet
          → checkpoint() entre chaque groupe (pause/annulation)
    ↓
Étape 3 : BK-tree sur dHash, rayon 8
          → comparaison par paires pour tous les photos
    ↓
Étape 4 : UnionFind clustering
          → tous les fichiers d'un même groupe → même dupGroupId
    ↓
Étape 5 : écriture en DB (dupGroupId, dupKind)
```

## DuplicateRunController — phases

```
idle → findingCandidates → confirming → comparingVisuals → writing → finished
                                                                   ↘ cancelled
                                                                   ↘ failed(message)
```

- **pause()** / **resume()** : `checkpoint()` bloque 150ms en boucle
- **cancel()** : `task.cancel()` → `CancellationError` → phase `.cancelled`
- **UIBackgroundTask** : ~30s de sursis, reprise auto au premier plan
- `lastDriveId` / `lastRoot` mémorisés pour relancer sans interaction

## Queries.bestOfGroup

La "meilleure" d'un groupe = fichier avec le plus grand nombre de pixels.
En cas d'égalité : le plus récent (captureDate ou modifiedAt).

```swift
static func bestOfGroup(_ group: [FileRecord]) -> FileRecord? {
    group.max { a, b in
        let aPixels = (a.pixelWidth ?? 0) * (a.pixelHeight ?? 0)
        let bPixels = (b.pixelWidth ?? 0) * (b.pixelHeight ?? 0)
        return aPixels < bPixels
    }
}
```
