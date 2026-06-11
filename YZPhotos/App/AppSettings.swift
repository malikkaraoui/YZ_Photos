import Observation
import SwiftUI

/// Réglages persistants de l'app (UserDefaults).
@MainActor
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system = "Système"
        case light = "Clair"
        case dark = "Sombre"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }

    /// Lecture automatique des vidéos au clic (aperçu et visionneuse).
    var autoPlayVideos: Bool {
        didSet { defaults.set(autoPlayVideos, forKey: "autoPlayVideos") }
    }

    /// Ordre d'affichage par défaut des grilles (l'onglet Par taille garde le sien).
    var defaultGridOrder: GridOrder {
        didSet { defaults.set(defaultGridOrder.rawValue, forKey: "defaultGridOrder") }
    }

    private let defaults = UserDefaults.standard

    init() {
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        autoPlayVideos = defaults.object(forKey: "autoPlayVideos") as? Bool ?? true
        defaultGridOrder = GridOrder(rawValue: defaults.string(forKey: "defaultGridOrder") ?? "") ?? .byFolder
    }
}
