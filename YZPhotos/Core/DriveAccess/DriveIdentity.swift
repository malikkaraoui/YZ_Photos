import CryptoKit
import Foundation

/// Identité stable d'un disque : UUID du volume si disponible,
/// sinon hash de (nom + capacité) — survit aux renommages dans le premier cas.
enum DriveIdentity {
    struct Identity: Sendable {
        var id: String
        var name: String
        var totalBytes: Int64?
    }

    static func identify(url: URL) -> Identity {
        let values = try? url.resourceValues(forKeys: [
            .volumeUUIDStringKey, .volumeNameKey, .volumeTotalCapacityKey, .localizedNameKey,
        ])
        // Nom lisible : nom de volume (USB-C) → nom localisé du dossier
        // (réseau via File Provider, ex. SMB) → dernier composant. On évite le
        // `lastPathComponent` brut quand il ressemble à un identifiant opaque de
        // File Provider (ex. « U4M1+g »).
        let name = values?.volumeName
            ?? values?.localizedName
            ?? url.lastPathComponent
        let totalBytes = (values?.volumeTotalCapacity).map(Int64.init)
        if let uuid = values?.volumeUUIDString {
            return Identity(id: uuid, name: name, totalBytes: totalBytes)
        }
        // Pas d'UUID de volume (réseau SMB/NAS) : identité stable par hash du
        // nom lisible. Stable d'une session à l'autre tant que le nom ne change pas.
        let seed = "\(name)#\(totalBytes ?? 0)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        let id = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return Identity(id: "net-\(id)", name: name, totalBytes: totalBytes)
    }
}
