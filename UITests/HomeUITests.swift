import XCTest

final class HomeUITests: XCTestCase {
    func testRestartButtonOpensConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["-NoFapOffsetSeconds", "1068136"]
        app.launch()

        let restart = app.buttons["restart-button"]
        XCTAssertTrue(restart.waitForExistence(timeout: 8))
        restart.tap()

        let alert = app.alerts["重新开始"]
        XCTAssertTrue(alert.waitForExistence(timeout: 4))
        alert.buttons["取消"].tap()
        XCTAssertTrue(restart.waitForExistence(timeout: 4))
    }
}
