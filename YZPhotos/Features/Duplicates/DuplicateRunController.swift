import Foundation
import Observation
import UIKit

/// Pilote la recherche de doublons : lancée à la demande depuis l'onglet
/// Doublons, avec progression visible, pause et arrêt.
@MainActor
@Observable
final class DuplicateRunController {
    enum Phase: Equatable {
        case idle               // jamais lancée
        case findingCandidates  // étape 1 : repérage par taille + empreinte
        case confirming         // étape 2 : confirmation octet par octet
        case comparingVisuals   // étape 3 : comparaison visuelle des photos
        case writing            // étape 4 : enregistrement des groupes
        case finished
        case cancelled
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var isRunning = false
    private(set) var isPaused = false

    // Progression, exposée à l'onglet Doublons.
    private(set) var candidateGroups = 0
    private(set) var groupsConfirmed = 0
    private(set) var photosTotal = 0
    private(set) var photosCompared = 0
    private(set) var groupsFound = 0
    private(set) var finishedAt: Date?
    /// Débit (unités/s) et temps restant estimé de la phase mesurée en cours
    /// (confirmation des doublons exacts, puis comparaison visuelle).
    private(set) var rate: Double = 0
    private(set) var etaSeconds: Double?
    private var phaseStartedAt: Date?

    private let database: AppDatabase
    private var task: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var interruptedByBackground = false
    private var lastDriveId: String?
    private var lastStore: MediaStore?

    init(database: AppDatabase) {
        self.database = database
    }

    /// Sursis arrière-plan (~30 s) puis arrêt propre ; reprise auto au retour.
    func enteredBackground() {
        guard isRunning else { return }
        interruptedByBackground = true
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "yzphotos-duplicates") { [weak self] in
            Task { @MainActor [weak self] in
                self?.cancel()
                self?.endBackgroundTask()
            }
        }
    }

    func enteredForeground() {
        endBackgroundTask()
        guard interruptedByBackground else { return }
        interruptedByBackground = false
        if !isRunning, let driveId = lastDriveId, let store = lastStore {
            start(driveId: driveId, store: store)
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    func start(driveId: String, store: MediaStore) {
        guard !isRunning else { return }
        lastDriveId = driveId
        lastStore = store
        isRunning = true
        isPaused = false
        phase = .findingCandidates
        candidateGroups = 0
        groupsConfirmed = 0
        photosTotal = 0
        photosCompared = 0
        rate = 0
        etaSeconds = nil
        phaseStartedAt = nil
        task = Task {
            do {
                let finder = DuplicateFinder(database: database)
                let count = try await finder.run(driveId: driveId, store: store, controller: self)
                groupsFound = count
                finishedAt = Date()
                phase = .finished
            } catch is CancellationError {
                phase = .cancelled
            } catch {
                phase = .failed(error.localizedDescription)
            }
            isRunning = false
            isPaused = false
        }
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    func cancel() {
        isPaused = false
        task?.cancel()
    }

    // MARK: - Appelé par DuplicateFinder entre chaque unité de travail

    /// Point de contrôle : bloque tant que c'est en pause, lève si arrêté.
    func checkpoint() async throws {
        while isPaused {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(150))
        }
        try Task.checkCancellation()
    }

    func reportCandidates(_ count: Int) {
        candidateGroups = count
        phase = .confirming
        startPhaseClock()
    }

    func reportGroupConfirmed() {
        groupsConfirmed += 1
        refreshThroughput(done: groupsConfirmed, total: candidateGroups)
    }

    func reportPerceptualStart(total: Int) {
        photosTotal = total
        phase = .comparingVisuals
        startPhaseClock()
    }

    func reportPerceptualProgress(_ done: Int) {
        photosCompared = done
        refreshThroughput(done: photosCompared, total: photosTotal)
    }

    func reportWriting() {
        phase = .writing
        rate = 0
        etaSeconds = nil
    }

    // MARK: - Débit + ETA (même logique que l'analyse)

    private func startPhaseClock() {
        phaseStartedAt = Date()
        rate = 0
        etaSeconds = nil
    }

    private func refreshThroughput(done: Int, total: Int) {
        guard let phaseStartedAt, done > 0 else { rate = 0; etaSeconds = nil; return }
        let elapsed = Date().timeIntervalSince(phaseStartedAt)
        guard elapsed > 1 else { rate = 0; etaSeconds = nil; return }
        rate = Double(done) / elapsed
        let remaining = max(0, total - done)
        etaSeconds = rate > 0 ? Double(remaining) / rate : nil
    }
}
