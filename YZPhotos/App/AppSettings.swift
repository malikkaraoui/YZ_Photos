import Observation
import SwiftUI

/// Réglages persistants de l'app (UserDefaults).
@MainActor
@Observable
final class AppSettings {
    /// Univers visuel actif. Verre (aurora liquid-glass) est l'identité par défaut ;
    /// Clair et Sombre sont des replis sobres.
    var themeKind: YZThemeKind {
        didSet { defaults.set(themeKind.rawValue, forKey: "themeKind") }
    }

    /// Tokens résolus du thème courant.
    var theme: YZTheme { themeKind.theme }

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
        themeKind = Self.loadThemeKind(defaults)
        autoPlayVideos = defaults.object(forKey: "autoPlayVideos") as? Bool ?? true
        defaultGridOrder = GridOrder(rawValue: defaults.string(forKey: "defaultGridOrder") ?? "") ?? .byFolder
    }

    /// Lit le thème, en migrant l'ancienne clé `appearance` (Système/Clair/Sombre).
    private static func loadThemeKind(_ defaults: UserDefaults) -> YZThemeKind {
        if let raw = defaults.string(forKey: "themeKind"), let kind = YZThemeKind(rawValue: raw) {
            return kind
        }
        switch defaults.string(forKey: "appearance") {
        case "Clair": return .light
        case "Sombre": return .dark
        default: return .glass   // « Système » et premier lancement → Verre (identité par défaut)
        }
    }
}
