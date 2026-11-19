import Foundation

/// Formatage des valeurs affichées. La langue suit le choix de l'app
/// (`LocalizationManager.applyToBundle`), pas celle de l'appareil.
enum Fmt {
    nonisolated(unsafe) static var locale: Locale = Locale(identifier: "fr")

    static func bytes(_ value: Int64, locale: Locale = Fmt.locale) -> String {
        value.formatted(.byteCount(style: .file).locale(locale))
    }

    static func count(_ value: Int, locale: Locale = Fmt.locale) -> String {
        value.formatted(.number.locale(locale))
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        if m >= 60 {
            return String(format: "%d:%02d:%02d", m / 60, m % 60, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    static func date(_ date: Date, locale: Locale = Fmt.locale) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    static func eta(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "moins d'une minute" }
        let minutes = total / 60
        if minutes < 60 { return "~\(minutes) min" }
        return "~\(minutes / 60) h \(String(format: "%02d", minutes % 60)) min"
    }
}
