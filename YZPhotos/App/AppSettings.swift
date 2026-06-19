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

    // Dernière connexion SMB (pour pré-remplir l'écran « Disque réseau » et ne
    // pas resaisir à chaque fois). Le mot de passe, lui, est au trousseau.
    var lastSMBHost: String { didSet { defaults.set(lastSMBHost, forKey: "lastSMBHost") } }
    var lastSMBUser: String { didSet { defaults.set(lastSMBUser, forKey: "lastSMBUser") } }

    /// Compte Keychain du mot de passe de la dernière connexion SMB.
    static let lastSMBAccount = "smb.last"

    private let defaults = UserDefaults.standard

    init() {
        themeKind = Self.loadThemeKind(defaults)
        autoPlayVideos = defaults.object(forKey: "autoPlayVideos") as? Bool ?? true
        defaultGridOrder = GridOrder(rawValue: defaults.string(forKey: "defaultGridOrder") ?? "") ?? .byFolder
        lastSMBHost = defaults.string(forKey: "lastSMBHost") ?? ""
        lastSMBUser = defaults.string(forKey: "lastSMBUser") ?? ""
    }

    /// Mémorise la dernière connexion SMB réussie (mot de passe au trousseau).
    func rememberSMB(host: String, user: String, password: String) {
        lastSMBHost = host
        lastSMBUser = user
        Keychain.set(password, account: Self.lastSMBAccount)
    }

    var lastSMBPassword: String? { Keychain.get(account: Self.lastSMBAccount) }

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
