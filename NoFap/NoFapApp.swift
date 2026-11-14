import SwiftUI

@main
struct NoFapApp: App {
    @StateObject private var store: TimerStore

    init() {
        let directory = (try? TimerFiles.liveDirectory())
            ?? FileManager.default.temporaryDirectory
        _store = StateObject(wrappedValue: TimerStore(directory: directory, now: Self.previewStart()))
    }

    /// Debug screenshots only. Release builds ignore the argument, and an existing save is never replaced.
    private static func previewStart() -> Date {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-NoFapOffsetSeconds"),
           arguments.indices.contains(index + 1),
           let seconds = TimeInterval(arguments[index + 1]),
           seconds >= 0 {
            return Date().addingTimeInterval(-seconds)
        }
        #endif
        return Date()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
