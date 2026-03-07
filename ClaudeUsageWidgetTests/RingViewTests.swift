import XCTest
@testable import ClaudeUsageWidget

final class RingViewTests: XCTestCase {

    func test_image_returnsNonNilImage() {
        let img = RingView.image(progress: 0.5, colorState: .normal)
        XCTAssertNotNil(img)
    }

    func test_image_normalState_isTemplate() {
        let img = RingView.image(progress: 0.5, colorState: .normal)
        XCTAssertTrue(img.isTemplate, "Normal state should be a template image for menu bar adaptation")
    }

    func test_image_amberState_isNotTemplate() {
        let img = RingView.image(progress: 0.7, colorState: .amber)
        XCTAssertFalse(img.isTemplate, "Amber state should not be a template image")
    }

    func test_image_criticalState_isNotTemplate() {
        let img = RingView.image(progress: 0.9, colorState: .critical)
        XCTAssertFalse(img.isTemplate, "Critical state should not be a template image")
    }

    func test_image_hasCorrectSize() {
        let size = CGSize(width: 18, height: 18)
        let img = RingView.image(progress: 0.5, colorState: .normal, size: size)
        XCTAssertEqual(img.size.width, 18)
        XCTAssertEqual(img.size.height, 18)
    }

    func test_image_zeroProgress_doesNotCrash() {
        let img = RingView.image(progress: 0.0, colorState: .normal)
        XCTAssertNotNil(img)
    }

    func test_image_fullProgress_doesNotCrash() {
        let img = RingView.image(progress: 1.0, colorState: .critical)
        XCTAssertNotNil(img)
    }

    func test_image_clampsBeyondOne() {
        // Over-clocking shouldn't crash
        let img = RingView.image(progress: 1.5, colorState: .critical)
        XCTAssertNotNil(img)
    }
}
