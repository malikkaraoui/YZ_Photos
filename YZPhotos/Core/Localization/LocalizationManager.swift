import Foundation
import Observation

/// Langues proposées dans Réglages.
enum AppLanguage: String, CaseIterable, Identifiable {
    case french = "fr"
    case english = "en"
    var id: String { rawValue }
    /// Libellé natif (toujours affiché dans sa propre langue).
    var nativeName: String { self == .french ? "Français" : "English" }
    var flag: String { self == .french ? "🇫🇷" : "🇬🇧" }
}

/// `Bundle` qui redirige la recherche de chaînes vers le `.lproj` de la langue
/// choisie dans l'app (et non celle du système) → bascule de langue À CHAUD.
private var languageBundleKey: UInt8 = 0
final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &languageBundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: table)
        }
        return super.localizedString(forKey: key, value: value, table: table)
    }
}

/// Choix de langue persistant + bascule instantanée (sans redémarrage).
/// On échange la classe de `Bundle.main` une fois, puis on pointe vers le `.lproj`
/// voulu ; l'app relit alors toutes les chaînes dans cette langue. La vue racine
/// observe `language` et met à jour l'environnement `\.locale` → tout se re-rend.
@MainActor
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    private static let defaultsKey = "yz.appLanguage"

    private(set) var language: AppLanguage

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey)
        // Défaut : FRANÇAIS (langue principale de l'app). Pas d'auto-détection système
        // (elle surprenait : iPad réglé en anglais → app en anglais). On passe en
        // anglais à la main via le sélecteur (écran de connexion OU Réglages).
        language = saved.flatMap(AppLanguage.init(rawValue:)) ?? .french
        applyToBundle(language)
    }

    func set(_ lang: AppLanguage) {
        guard lang != language else { return }
        UserDefaults.standard.set(lang.rawValue, forKey: Self.defaultsKey)
        applyToBundle(lang)
        language = lang   // déclenche le re-rendu (observé par la racine)
    }

    /// `Locale` à injecter dans l'environnement SwiftUI (force la re-localisation).
    var locale: Locale { Locale(identifier: language.rawValue) }

    private func applyToBundle(_ lang: AppLanguage) {
        object_setClass(Bundle.main, LocalizedBundle.self)
        let bundle = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:))
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN)
    }
}
