import Combine
import Foundation

struct ArchivedRound: Codable, Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
}

struct UndoRestart: Codable, Equatable {
    var archivedRoundID: UUID
    var previousStart: Date
    var restartedAt: Date
}

struct StartAdjustment: Codable, Equatable, Identifiable {
    var id: UUID
    var changedAt: Date
    var from: Date
    var to: Date
}

struct TimerStatistics: Equatable {
    var currentSeconds: Int
    var longestSeconds: Int
    var rounds: Int
}

enum TimerRefusal: Equatable {
    case clockBehind
    case futureStart
    case nothingToUndo
}

enum TimerResult: Equatable {
    case success
    case refused(TimerRefusal)
}

private struct PersistedTimer: Codable {
    var version: Int
    var currentStart: Date
    var archive: [ArchivedRound]
    var undo: UndoRestart?
    var adjustments: [StartAdjustment]
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
}

enum TimerFiles {
    static func liveDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("NoFap", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

/// Local streak clock. The displayed length is always `now - currentStart`, never an incremented counter.
final class TimerStore: ObservableObject {
    @Published private(set) var currentStart: Date
    @Published private(set) var archive: [ArchivedRound]
    @Published private(set) var undo: UndoRestart?
    @Published private(set) var adjustments: [StartAdjustment]
    @Published var reminderEnabled: Bool
    @Published var reminderHour: Int
    @Published var reminderMinute: Int
    @Published private(set) var lastSaveFailed = false

    let directory: URL
    private let fileURL: URL

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    init(directory: URL, now: Date = Date()) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("timer.json")
        self.currentStart = now
        self.archive = []
        self.undo = nil
        self.adjustments = []
        self.reminderEnabled = false
        self.reminderHour = 21
        self.reminderMinute = 0

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if !load() {
                preserveUnreadableFile()
                currentStart = now
                save()
            }
        } else {
            save()
        }
    }

    func components(at now: Date) -> ElapsedComponents {
        ElapsedTime.components(from: currentStart, to: now)
    }

    func statistics(at now: Date) -> TimerStatistics {
        let current = ElapsedTime.wholeSeconds(now.timeIntervalSince(currentStart))
        let longestArchived = archive.map(\.durationSeconds).max() ?? 0
        return TimerStatistics(
            currentSeconds: current,
            longestSeconds: max(current, longestArchived),
            rounds: archive.count + 1
        )
    }

    /// Archive the open round and start again at the confirmation instant.
    @discardableResult
    func restart(at now: Date) -> TimerResult {
        if now < currentStart {
            return .refused(.clockBehind)
        }
        let duration = ElapsedTime.wholeSeconds(now.timeIntervalSince(currentStart))
        let round = ArchivedRound(
            id: UUID(),
            startedAt: currentStart,
            endedAt: now,
            durationSeconds: duration
        )
        archive.append(round)
        undo = UndoRestart(
            archivedRoundID: round.id,
            previousStart: round.startedAt,
            restartedAt: now
        )
        currentStart = now
        save()
        return .success
    }

    /// Put the latest restart back. Elapsed time again includes the gap, because the original start is restored.
    @discardableResult
    func undoRestart() -> TimerResult {
        guard let undo, let index = archive.lastIndex(where: { $0.id == undo.archivedRoundID }) else {
            return .refused(.nothingToUndo)
        }
        guard archive[index].id == archive.last?.id, nearlyEqual(currentStart, undo.restartedAt) else {
            return .refused(.nothingToUndo)
        }
        archive.remove(at: index)
        currentStart = undo.previousStart
        self.undo = nil
        save()
        return .success
    }

    /// Change the open round's start. This is an edit, not an archived restart, and it clears undo.
    @discardableResult
    func adjustStart(to newStart: Date, now: Date) -> TimerResult {
        if newStart > now {
            return .refused(.futureStart)
        }
        if !nearlyEqual(newStart, currentStart) {
            adjustments.append(StartAdjustment(id: UUID(), changedAt: now, from: currentStart, to: newStart))
            currentStart = newStart
            undo = nil
            save()
        }
        return .success
    }

    func eraseAll(at now: Date) {
        currentStart = now
        archive = []
        undo = nil
        adjustments = []
        reminderEnabled = false
        save()
    }

    func setReminder(enabled: Bool, hour: Int, minute: Int) {
        reminderEnabled = enabled
        reminderHour = min(23, max(0, hour))
        reminderMinute = min(59, max(0, minute))
        save()
    }

    func exportData() throws -> Data {
        try Self.encoder.encode(snapshot())
    }

    private func snapshot() -> PersistedTimer {
        PersistedTimer(
            version: 1,
            currentStart: currentStart,
            archive: archive,
            undo: undo,
            adjustments: adjustments,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }

    private func load() -> Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? Self.decoder.decode(PersistedTimer.self, from: data),
              state.version == 1
        else {
            return false
        }
        currentStart = state.currentStart
        archive = state.archive
        undo = state.undo
        adjustments = state.adjustments
        reminderEnabled = state.reminderEnabled
        reminderHour = state.reminderHour
        reminderMinute = state.reminderMinute
        return true
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try Self.encoder.encode(snapshot())
            let temporary = directory.appendingPathComponent("timer.json.tmp")
            try data.write(to: temporary, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: fileURL)
            }
            lastSaveFailed = false
        } catch {
            lastSaveFailed = true
        }
    }

    private func preserveUnreadableFile() {
        let destination = directory.appendingPathComponent("timer.unreadable.json")
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.moveItem(at: fileURL, to: destination)
    }

    private func nearlyEqual(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 0.001
    }
}
