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

    func testNavigationAndSettingsActions() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["tab-history"].tap()
        XCTAssertTrue(app.otherElements["current-round"].exists || app.staticTexts["这一轮 · 正在继续"].exists)
        app.buttons["tab-settings"].tap()
        let edit = app.buttons["修改开始时间"]
        XCTAssertTrue(edit.waitForExistence(timeout: 4))
        edit.tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 4))
        app.buttons["取消"].tap()
        let footer = app.staticTexts["local-records-footer"]
        for _ in 0..<4 {
            if footer.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(footer.isHittable)
        XCTAssertLessThanOrEqual(footer.frame.maxY, app.buttons["tab-settings"].frame.minY)
        app.buttons["tab-timer"].tap()
        XCTAssertTrue(app.buttons["restart-button"].exists)
    }
}
