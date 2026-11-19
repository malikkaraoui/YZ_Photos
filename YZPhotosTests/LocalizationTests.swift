import XCTest
@testable import YZPhotos

/// M0022 : `String(localized:)` doit suivre la langue CHOISIE DANS L'APP, pas celle de l'appareil.
@MainActor
final class LocalizationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LocalizationManager.shared.set(.english)
    }

    override func tearDown() {
        LocalizationManager.shared.set(.french)
        super.tearDown()
    }

    func testStringLocalizedSuitLangueApp() {
        XCTAssertEqual(loc("Analyse terminée"), "Analysis complete")
    }

    func testInterpolation() {
        XCTAssertTrue(loc("Dernière analyse complète : \("x")").hasPrefix("Last"))
    }

    func testFrancaisQuandAppEnFrancais() {
        LocalizationManager.shared.set(.french)
        XCTAssertEqual(loc("Analyse terminée"), "Analyse terminée")
    }
}
