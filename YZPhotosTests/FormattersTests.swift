import XCTest
@testable import YZPhotos

/// M0013 : unités, dates et nombres suivent la langue choisie DANS l'app.
final class FormattersTests: XCTestCase {

    func testBytesEnglishUsesGB() {
        let s = Fmt.bytes(2_930_000_000, locale: Locale(identifier: "en"))
        XCTAssertTrue(s.contains("GB"), s)
        XCTAssertTrue(s.contains("2.93"), s)
        XCTAssertFalse(s.contains("Go"), s)
    }

    func testBytesFrenchUsesGo() {
        let s = Fmt.bytes(2_930_000_000, locale: Locale(identifier: "fr"))
        XCTAssertTrue(s.contains("Go"), s)
        XCTAssertTrue(s.contains("2,93"), s)
    }

    func testZeroBytesEnglishHasNoFrenchWords() {
        let s = Fmt.bytes(0, locale: Locale(identifier: "en"))
        XCTAssertFalse(s.contains("ko"), s)
        XCTAssertFalse(s.contains("Zéro"), s)
    }

    func testDateEnglishHasNoFrenchMonth() {
        let d = Date(timeIntervalSince1970: 1_795_000_000)
        let s = Fmt.date(d, locale: Locale(identifier: "en"))
        XCTAssertFalse(s.contains("nov."), s)
    }

    func testCountFollowsLocale() {
        XCTAssertEqual(Fmt.count(1234, locale: Locale(identifier: "en")).replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " "), "1,234")
        XCTAssertTrue(Fmt.count(1234, locale: Locale(identifier: "fr")).contains("1"))
    }
}
