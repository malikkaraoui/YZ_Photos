import CryptoKit
import Foundation

/// Hash exact étagé : lire 1 To en entier est exclu, donc
/// 1. la taille discrimine déjà la plupart des fichiers ;
/// 2. partialHash = SHA-256(taille + 64 Ko de tête + 64 Ko de queue) — 128 Ko lus par fichier ;
/// 3. fullHash (SHA-256 complet) calculé uniquement sur collision partielle,
///    par DuplicateFinder.
enum HashWorker {
    static let chunkSize = 64 * 1024

    // autoreleasepool obligatoire autour des lectures : sans lui, les Data
    // temporaires s'accumulent pendant des heures de scan jusqu'à ce que le
    // système tue l'app (crash silencieux, sans message).

    static func partialHash(url: URL, sizeBytes: Int64) throws -> Data {
        var hasher = SHA256()
        withUnsafeBytes(of: sizeBytes.littleEndian) { hasher.update(bufferPointer: $0) }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        try autoreleasepool {
            if sizeBytes <= Int64(chunkSize * 2) {
                if let data = try handle.read(upToCount: Int(sizeBytes)) {
                    hasher.update(data: data)
                }
            } else {
                if let head = try handle.read(upToCount: chunkSize) {
                    hasher.update(data: head)
                }
                try handle.seek(toOffset: UInt64(sizeBytes - Int64(chunkSize)))
                if let tail = try handle.read(upToCount: chunkSize) {
                    hasher.update(data: tail)
                }
            }
        }
        return Data(hasher.finalize())
    }

    /// SHA-256 complet, lu par blocs de 1 Mo (confirmation des doublons exacts).
    static func fullHash(url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var done = false
        while !done {
            try autoreleasepool {
                if let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
                    hasher.update(data: data)
                } else {
                    done = true
                }
            }
        }
        return Data(hasher.finalize())
    }
}
