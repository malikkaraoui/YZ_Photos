import XCTest
@testable import YZPhotos

final class MediaClassifierTests: XCTestCase {
    func testIPhoneScreenshotDetected() {
        // PNG, dimensions iPhone 15, pas d'EXIF appareil : capture d'écran.
        XCTAssertTrue(MediaClassifier.isScreenshot(
            ext: "png", fileName: "IMG_4521.PNG",
            pixelWidth: 1179, pixelHeight: 2556, hasCameraExif: false
        ))
    }

    func testIPadScreenshotRotatedDetected() {
        // Dimensions iPad en paysage (l'ensemble normalise l'orientation).
        XCTAssertTrue(MediaClassifier.isScreenshot(
            ext: "png", fileName: "IMG_0001.PNG",
            pixelWidth: 2732, pixelHeight: 2048, hasCameraExif: false
        ))
    }

    func testFrenchScreenshotFilenameDetected() {
        // Le motif de nom suffit avec PNG, même sans dimensions connues.
        XCTAssertTrue(MediaClassifier.isScreenshot(
            ext: "png", fileName: "Capture d'écran 2024-03-12 à 14.02.11.png",
            pixelWidth: 1512, pixelHeight: 982, hasCameraExif: false
        ))
    }

    func testCameraPhotoNotDetected() {
        // JPEG d'appareil photo avec EXIF : jamais une capture.
        XCTAssertFalse(MediaClassifier.isScreenshot(
            ext: "jpg", fileName: "IMG_2034.JPG",
            pixelWidth: 4032, pixelHeight: 3024, hasCameraExif: true
        ))
    }

    func testPNGExportNotDetected() {
        // PNG quelconque (export) sans dimensions d'écran ni nom typique.
        XCTAssertFalse(MediaClassifier.isScreenshot(
            ext: "png", fileName: "logo-final-v3.png",
            pixelWidth: 800, pixelHeight: 600, hasCameraExif: true
        ))
    }
}
