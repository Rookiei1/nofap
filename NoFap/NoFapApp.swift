import SwiftUI

@main
struct NoFapApp: App {
    @StateObject private var store: TimerStore

    init() {
        let directory = (try? TimerFiles.liveDirectory())
            ?? FileManager.default.temporaryDirectory
        _store = StateObject(wrappedValue: TimerStore(directory: directory, now: previewStart() ?? Date()))
    }

    /// Debug screenshots only. Release builds ignore this, and an existing save is never replaced.
    private func previewStart() -> Date? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-NoFapOffsetSeconds"),
              arguments.indices.contains(index + 1),
              let seconds = TimeInterval(arguments[index + 1]),
              seconds >= 0
        else {
            return nil
        }
        return Date().addingTimeInterval(-seconds)
        #else
        return nil
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
