import SwiftUI

@main
struct NoFapApp: App {
    @StateObject private var store: TimerStore

    init() {
        let directory = (try? TimerFiles.liveDirectory())
            ?? FileManager.default.temporaryDirectory
        _store = StateObject(wrappedValue: TimerStore(directory: directory))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
