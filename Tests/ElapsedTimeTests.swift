import XCTest
@testable import NoFap

final class ElapsedTimeTests: XCTestCase {
    func testZeroAtTheStartInstant() {
        let start = Date(timeIntervalSince1970: 10_000)
        let shown = ElapsedTime.components(from: start, to: start)
        XCTAssertEqual(shown.totalSeconds, 0)
        XCTAssertEqual(shown.days, 0)
        XCTAssertEqual(shown.clockText, "00:00:00")
        XCTAssertFalse(shown.clockBehind)
        XCTAssertEqual(ElapsedTime.dayText(shown.days), "000")
    }

    func testFirstSecondAndSubsecondFraction() {
        let start = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(ElapsedTime.components(from: start, to: start.addingTimeInterval(0.999)).totalSeconds, 0)
        let first = ElapsedTime.components(from: start, to: start.addingTimeInterval(1))
        XCTAssertEqual(first.totalSeconds, 1)
        XCTAssertEqual(first.seconds, 1)
        XCTAssertEqual(first.clockText, "00:00:01")
    }

    func testRepeatedReadsDoNotDrift() {
        let start = Date(timeIntervalSince1970: 1_000)
        let now = start.addingTimeInterval(10)
        let first = ElapsedTime.components(from: start, to: now)
        let second = ElapsedTime.components(from: start, to: now)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.totalSeconds, 10)
    }

    func testApprovedExampleIsTwelveDaysAndEightHours() {
        let total = 12 * 86_400 + 8 * 3_600 + 42 * 60 + 16
        XCTAssertEqual(total, 1_068_136)
        let start = Date(timeIntervalSince1970: 0)
        let shown = ElapsedTime.components(from: start, to: start.addingTimeInterval(TimeInterval(total)))
        XCTAssertEqual(shown.days, 12)
        XCTAssertEqual(shown.hours, 8)
        XCTAssertEqual(shown.minutes, 42)
        XCTAssertEqual(shown.seconds, 16)
        XCTAssertEqual(ElapsedTime.dayText(shown.days), "012")
        XCTAssertEqual(shown.clockText, "08:42:16")
        let spine = ElapsedTime.spine(days: 12)
        XCTAssertEqual(spine.maximum, 30)
        XCTAssertEqual(spine.ticks, [0, 10, 20, 30])
        XCTAssertEqual(spine.fraction, 12.0 / 30.0, accuracy: 0.000_001)
        XCTAssertEqual(ElapsedTime.hourFraction(minutes: 42, seconds: 16), 2_536.0 / 3_600.0, accuracy: 0.000_001)
    }

    func testTwentyFourHourBoundaryIsOneDayNotCalendarMidnight() {
        let start = Date(timeIntervalSince1970: 50_000)
        let before = ElapsedTime.components(from: start, to: start.addingTimeInterval(86_399))
        XCTAssertEqual(before.days, 0)
        XCTAssertEqual(before.hours, 23)
        XCTAssertEqual(before.minutes, 59)
        XCTAssertEqual(before.seconds, 59)
        let exact = ElapsedTime.components(from: start, to: start.addingTimeInterval(86_400))
        XCTAssertEqual(exact.days, 1)
        XCTAssertEqual(exact.clockText, "00:00:00")
        XCTAssertEqual(exact.totalSeconds, 86_400)
    }

    func testCrossingMidnightDoesNotAddACalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 0, second: 0))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 1, minute: 0, second: 0))!
        let shown = ElapsedTime.components(from: start, to: now)
        XCTAssertEqual(shown.days, 0)
        XCTAssertEqual(shown.hours, 2)
        XCTAssertEqual(shown.totalSeconds, 7_200)
    }

    func testTimeZoneChangesTheLabelButNotTheElapsedSeconds() {
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let start = shanghai.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 14, minute: 18, second: 44))!
        let now = start.addingTimeInterval(7_200)
        let shown = ElapsedTime.components(from: start, to: now)
        XCTAssertEqual(shown.totalSeconds, 7_200)
        XCTAssertEqual(
            ElapsedTime.startCaption(start: start, now: now, timeZone: shanghai.timeZone),
            "开始于 11/01 14:18:44"
        )
        let newYork = TimeZone(identifier: "America/New_York")!
        XCTAssertNotEqual(
            ElapsedTime.startCaption(start: start, now: now, timeZone: newYork),
            "开始于 11/01 14:18:44"
        )
        XCTAssertTrue(ElapsedTime.startCaption(start: start, now: now, timeZone: newYork).hasSuffix(":44"))
    }

    func testAbsoluteDayIgnoresDaylightSaving() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 30, second: 0))!
        let later = start.addingTimeInterval(86_400)
        let shown = ElapsedTime.components(from: start, to: later)
        XCTAssertEqual(shown.days, 1)
        XCTAssertEqual(shown.hours, 0)
        XCTAssertEqual(shown.minutes, 0)
        XCTAssertEqual(shown.seconds, 0)
        XCTAssertEqual(shown.totalSeconds, 86_400)
    }

    func testClockRollbackDisplaysZero() {
        let start = Date(timeIntervalSince1970: 5_000)
        let shown = ElapsedTime.components(from: start, to: Date(timeIntervalSince1970: 4_999))
        XCTAssertTrue(shown.clockBehind)
        XCTAssertEqual(shown.totalSeconds, 0)
        XCTAssertEqual(shown.clockText, "00:00:00")
    }

    func testDayTextGrowsPastThreeDigits() {
        XCTAssertEqual(ElapsedTime.dayText(0), "000")
        XCTAssertEqual(ElapsedTime.dayText(12), "012")
        XCTAssertEqual(ElapsedTime.dayText(1_000), "1000")
    }

    func testStartCaptionKeepsSecondsAndAddsTheYearWhenNeeded() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let start = calendar.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 23, minute: 59, second: 58))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 3))!
        XCTAssertEqual(
            ElapsedTime.startCaption(start: start, now: now, timeZone: calendar.timeZone),
            "开始于 2025/12/31 23:59:58"
        )
        XCTAssertEqual(ElapsedTime.components(from: start, to: now).totalSeconds, 5)
    }

    func testNextDisplayDateLandsOnWholeSeconds() {
        XCTAssertEqual(
            ElapsedTime.nextDisplayDate(after: Date(timeIntervalSince1970: 10)),
            Date(timeIntervalSince1970: 11)
        )
        XCTAssertEqual(
            ElapsedTime.nextDisplayDate(after: Date(timeIntervalSince1970: 10.2)),
            Date(timeIntervalSince1970: 11)
        )
    }

    func testGlanceCopyIsNotACheckIn() {
        XCTAssertFalse(GlanceNotice.body.contains("必须"))
        XCTAssertTrue(GlanceNotice.body.contains("不是打卡"))
    }
}
