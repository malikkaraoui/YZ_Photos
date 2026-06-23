import StoreKit
import SwiftUI

/// Demande d'évaluation App Store, au bon moment et **sans harceler** :
/// - jamais avant un usage réel (l'app doit avoir été ouverte plusieurs fois),
/// - au plus une fois par version de l'app,
/// - Apple plafonne de toute façon à 3 demandes / 365 jours.
enum ReviewPrompter {
    private static let launchKey = "review.activeSessions"
    private static let lastVersionKey = "review.lastPromptedVersion"
    private static let minSessions = 4

    /// À appeler quand l'utilisateur entre dans l'app avec un disque (usage réel).
    @MainActor static func registerUseAndMaybePrompt(_ requestReview: RequestReviewAction) {
        let d = UserDefaults.standard
        let sessions = d.integer(forKey: launchKey) + 1
        d.set(sessions, forKey: launchKey)

        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        guard sessions >= minSessions else { return }
        guard d.string(forKey: lastVersionKey) != version else { return }
        d.set(version, forKey: lastVersionKey)

        // Léger délai : laisser l'écran s'installer avant la pop-up système.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            requestReview()
        }
    }
}
