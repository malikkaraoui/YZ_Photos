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

    private let database: AppDatabase
    private var task: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var interruptedByBackground = false
    private var lastDriveId: String?
    private var lastRoot: URL?

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
        if !isRunning, let driveId = lastDriveId, let root = lastRoot {
            start(driveId: driveId, root: root)
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    func start(driveId: String, root: URL) {
        guard !isRunning else { return }
        lastDriveId = driveId
        lastRoot = root
        isRunning = true
        isPaused = false
        phase = .findingCandidates
        candidateGroups = 0
        groupsConfirmed = 0
        photosTotal = 0
        photosCompared = 0
        task = Task {
            do {
                let finder = DuplicateFinder(database: database)
                let count = try await finder.run(driveId: driveId, root: root, controller: self)
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
    }

    func reportGroupConfirmed() {
        groupsConfirmed += 1
    }

    func reportPerceptualStart(total: Int) {
        photosTotal = total
        phase = .comparingVisuals
    }

    func reportPerceptualProgress(_ done: Int) {
        photosCompared = done
    }

    func reportWriting() {
        phase = .writing
    }
}
