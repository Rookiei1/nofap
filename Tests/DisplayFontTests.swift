import UIKit
import XCTest
@testable import NoFap

final class DisplayFontTests: XCTestCase {
    func testDayDisplayFontIsRegistered() {
        XCTAssertNotNil(UIFont(name: "SixCaps", size: 100), "The day counter must use its bundled condensed font.")
    }
}
