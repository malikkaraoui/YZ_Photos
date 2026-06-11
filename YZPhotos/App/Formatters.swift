import Foundation

/// Formatage des valeurs affichées (localisé français par le système).
enum Fmt {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func count(_ value: Int) -> String {
        value.formatted()
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

    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func eta(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "moins d'une minute" }
        let minutes = total / 60
        if minutes < 60 { return "~\(minutes) min" }
        return "~\(minutes / 60) h \(String(format: "%02d", minutes % 60)) min"
    }
}
