import XCTest
@testable import YZPhotos

/// Vérifie la concaténation de chemins SMB (base + sous-chemin) utilisée par le
/// navigateur réseau et l'énumération.
final class SMBPathTests: XCTestCase {
    func testJoinBasics() {
        XCTAssertEqual(SMBMediaStore.join("/", "Photos"), "/Photos")
        XCTAssertEqual(SMBMediaStore.join("/Photos", "a.jpg"), "/Photos/a.jpg")
        XCTAssertEqual(SMBMediaStore.join("", "Photos"), "/Photos")
        XCTAssertEqual(SMBMediaStore.join("Photos", "x"), "/Photos/x")
    }

    func testJoinSlashes() {
        XCTAssertEqual(SMBMediaStore.join("/Photos/", "/sub"), "/Photos/sub")
        XCTAssertEqual(SMBMediaStore.join("/", "/"), "/")
        XCTAssertEqual(SMBMediaStore.join("/a", ""), "/a")
        XCTAssertEqual(SMBMediaStore.join("/a/b", "c/d"), "/a/b/c/d")
    }
}
