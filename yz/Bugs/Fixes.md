---
tags: [bugs, crashs, correctifs]
---

# Bugs résolus

> Retour : [[YZPhotos]]

## 1. Crash mémoire pendant l'analyse (Jetsam per-process-limit)

**Symptôme** : l'app s'arrête brutalement pendant la passe 2, surtout sur les gros SSD.

**Diagnostic** : `xcrun devicectl device copy from --domain-type systemCrashLogs`
→ JetsamEvent : `per-process-limit` à 327 686 pages (~5,2 Go).

**Causes** :
1. Pas d'`autoreleasepool` dans les boucles I/O → objets `Data` s'accumulent pendant des heures
2. 8 workers concurrents ImageIO → pics mémoire importants

**Correctifs appliqués** :
- `autoreleasepool` dans `HashWorker.partialHash` (par bloc de lecture)
- `autoreleasepool` dans `HashWorker.fullHash` (par bloc 1 Mo)
- `autoreleasepool` dans `ScanCoordinator` boucle d'analyse photo
- Workers réduits de 8 → **4**
- `NSCache` limités : `memoryCache.countLimit = 250`, `cardCache.countLimit = 12`
- `purgeMemoryCaches()` appelé au checkpoint mémoire
- Garde-mémoire `task_vm_info` : limite douce 2,2 Go + limite dure 3,2 Go

---

## 2. Crash arrière-plan (0x8BADF00D — Watchdog)

**Symptôme** : l'app est tuée ~5 secondes après être passée en arrière-plan.

**Cause** : iOS watchdog tue les apps qui ne répondent pas dans les 5s en arrière-plan.
Le scan continuait à tourner sans demander de sursis.

**Correctif** :
```swift
// ScanCoordinator.enteredBackground()
backgroundTaskID = UIApplication.shared.beginBackgroundTask { cancel() }
// → ~30s de sursis supplémentaire

// ScanCoordinator.enteredForeground()
// → reprise automatique si interrompu par le background
```
Même pattern appliqué à `DuplicateRunController`.

---

## 3. Navigation gelée dans l'onglet Dossiers

**Symptôme** : appuyer sur "Voir" dans un dossier ne faisait rien, l'UI se figeait.

**Cause** : `MediaGridScreen` crée son propre `NavigationStack`.
Quand il était poussé depuis `FolderBrowserView` (qui a déjà son propre stack),
un stack était imbriqué dans un autre → comportement indéfini SwiftUI.

**Correctif** : ajout du flag `embedded: Bool` dans `MediaGridScreen`.
Quand `embedded = true`, le `NavigationStack` interne est omis.

---

## 4. Blocage UI dans DriveChecksView (SpikeView)

**Symptôme** : toute l'UI se figeait au lancement des vérifications Phase 0.

**Cause** : `DispatchSemaphore.wait()` dans un contexte async bloque le thread
Swift Concurrency, ce qui empêche tous les workers de progresser.

**Correctif** : réécriture complète de `DriveChecksView` — toutes les vérifications
sont des fonctions `async` utilisant `for try await` directement, sans sémaphore.

---

## 5. Position de défilement perdue après suppression

**Symptôme** : après avoir mis un fichier à la poubelle, la grille remontait en haut.

**Cause** : le reload ne chargeait que `pageSize` (200) fichiers, effaçant la position.

**Correctif** dans `LibraryViewModel.reload()` :
```swift
let keepCount = max(pageSize, files.count)
// → recharge tous les fichiers déjà visibles, le scroll ne bouge pas
```

---

## 6. Erreur de compilation — switch expression sans return

**Symptôme** : build échoue sur `matchesFilter` dans `TriageViewModel`.

**Cause** : Swift 6 exige `return switch` explicite pour les switch-expressions.

**Correctif** :
```swift
// Avant
func matchesFilter(_ file: FileRecord) -> Bool {
    switch filter { case .all: true ... }
}

// Après
func matchesFilter(_ file: FileRecord) -> Bool {
    return switch filter { case .all: true ... }
}
```

---

## 7. Badge onglet — type Text? attendu

**Symptôme** : `.badge(String?)` provoquait une erreur de type.

**Correctif** :
```swift
.badge(env.duplicates.isRunning ? Text("●") : nil)
```

---

## 8. DuplicateRunController — faute de frappe paramètre

**Symptôme** : erreur de compilation dans `enteredForeground`.

**Cause** : `start(driveId:url:)` au lieu de `start(driveId:root:)`.

**Correctif** : renommage du paramètre `url:` → `root:`.
