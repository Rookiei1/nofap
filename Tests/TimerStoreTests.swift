import XCTest
@testable import NoFap

final class TimerStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("nofap-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testFirstLaunchStoresTheSeedInstant() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(store.archive.isEmpty)
        XCTAssertNil(store.undo)
        XCTAssertFalse(store.reminderEnabled)
        XCTAssertFalse(store.lastSaveFailed)
    }

    func testRestartZerosAndArchivesTheRealInterval() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        let confirm = start.addingTimeInterval(10.9)
        XCTAssertEqual(store.restart(at: confirm), .success)
        XCTAssertEqual(store.archive.count, 1)
        XCTAssertEqual(store.archive[0].startedAt.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(store.archive[0].endedAt.timeIntervalSince1970, confirm.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(store.archive[0].durationSeconds, 10)
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, confirm.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(store.components(at: confirm).totalSeconds, 0)
        XCTAssertEqual(store.components(at: confirm).clockText, "00:00:00")
        XCTAssertEqual(store.components(at: confirm.addingTimeInterval(1)).totalSeconds, 1)
    }

    func testUndoRestoresThePreviousStartIncludingTheGap() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        let confirm = start.addingTimeInterval(125)
        XCTAssertEqual(store.restart(at: confirm), .success)
        XCTAssertEqual(store.undoRestart(), .success)
        XCTAssertTrue(store.archive.isEmpty)
        XCTAssertNil(store.undo)
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(store.components(at: confirm.addingTimeInterval(10)).totalSeconds, 135)
    }

    func testSecondRestartUndoRemovesOnlyTheLatestRound() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        let first = start.addingTimeInterval(50)
        let second = start.addingTimeInterval(80)
        XCTAssertEqual(store.restart(at: first), .success)
        XCTAssertEqual(store.restart(at: second), .success)
        XCTAssertEqual(store.undoRestart(), .success)
        XCTAssertEqual(store.archive.count, 1)
        XCTAssertEqual(store.archive[0].durationSeconds, 50)
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, first.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(store.undoRestart(), .refused(.nothingToUndo))
    }

    func testReloadRecomputesFromTheSavedTimestamp() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        XCTAssertEqual(store.restart(at: start.addingTimeInterval(40)), .success)
        let reloaded = TimerStore(directory: directory)
        let later = start.addingTimeInterval(4_000)
        XCTAssertEqual(reloaded.archive.count, 1)
        XCTAssertEqual(reloaded.archive[0].durationSeconds, 40)
        XCTAssertEqual(reloaded.components(at: later).totalSeconds, 3_960)
        XCTAssertEqual(reloaded.components(at: later).totalSeconds, reloaded.components(at: later).totalSeconds)
        XCTAssertEqual(reloaded.statistics(at: later).rounds, 2)
        XCTAssertEqual(reloaded.statistics(at: later).longestSeconds, 3_960)
    }

    func testClockRollbackRefusesRestartAndKeepsTheStart() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        XCTAssertEqual(store.restart(at: start.addingTimeInterval(-3)), .refused(.clockBehind))
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(store.archive.isEmpty)
        XCTAssertTrue(store.components(at: start.addingTimeInterval(-3)).clockBehind)
    }

    func testFutureStartIsRejectedAndAdjustmentClearsUndo() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        XCTAssertEqual(store.adjustStart(to: start.addingTimeInterval(60), now: start), .refused(.futureStart))
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        let restarted = start.addingTimeInterval(30)
        XCTAssertEqual(store.restart(at: restarted), .success)
        XCTAssertEqual(store.adjustStart(to: start, now: restarted), .success)
        XCTAssertNil(store.undo)
        XCTAssertEqual(store.undoRestart(), .refused(.nothingToUndo))
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(store.adjustments.count, 1)
    }

    func testEraseStartsANewRoundAndDisablesTheReminder() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        store.setReminder(enabled: true, hour: 9, minute: 30)
        XCTAssertEqual(store.restart(at: start.addingTimeInterval(15)), .success)
        let cleared = start.addingTimeInterval(90)
        store.eraseAll(at: cleared)
        XCTAssertTrue(store.archive.isEmpty)
        XCTAssertNil(store.undo)
        XCTAssertTrue(store.adjustments.isEmpty)
        XCTAssertFalse(store.reminderEnabled)
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, cleared.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(store.components(at: cleared).totalSeconds, 0)
    }

    func testTurningReminderOffDoesNotMoveTheClock() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        store.setReminder(enabled: false, hour: 21, minute: 0)
        XCTAssertFalse(store.reminderEnabled)
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
    }

    func testExportContainsArchivedSeconds() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        XCTAssertEqual(store.restart(at: start.addingTimeInterval(15)), .success)
        let text = String(decoding: try store.exportData(), as: UTF8.self)
        XCTAssertTrue(text.contains("durationSeconds"))
        XCTAssertTrue(text.contains("15"))
        XCTAssertFalse(text.contains("必须打卡"))
    }

    func testUnreadableFileIsPreservedAndANewRoundStarts() {
        let file = directory.appendingPathComponent("timer.json")
        try? Data("not json".utf8).write(to: file)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TimerStore(directory: directory, now: start)
        XCTAssertEqual(store.currentStart.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("timer.unreadable.json").path))
        let saved = (try? Data(contentsOf: file)) ?? Data()
        XCTAssertFalse(saved.isEmpty)
        XCTAssertNotEqual(saved, Data("not json".utf8))
    }
}
