import SwiftUI

enum Obsidian {
    static let background = Color(red: 0.02, green: 0.02, blue: 0.025)
    static let silver = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let muted = Color(red: 0.62, green: 0.63, blue: 0.67)
    static let faint = Color(red: 0.40, green: 0.41, blue: 0.44)
    static let line = Color(white: 0.22)
    static let lava = Color(red: 1.0, green: 0.16, blue: 0.11)
    static let buttonFill = Color(red: 0.07, green: 0.07, blue: 0.082)

    static let metal = LinearGradient(
        stops: [
            .init(color: Color(white: 0.98), location: 0.0),
            .init(color: Color(white: 0.78), location: 0.32),
            .init(color: Color(white: 0.94), location: 0.48),
            .init(color: Color(white: 0.58), location: 0.74),
            .init(color: Color(white: 0.90), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
