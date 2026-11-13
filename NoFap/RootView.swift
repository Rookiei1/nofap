import SwiftUI

enum AppSection: Hashable {
    case timer
    case history
    case settings
}

struct RootView: View {
    @ObservedObject var store: TimerStore
    @State private var section: AppSection = .timer

    var body: some View {
        ZStack {
            Obsidian.background.ignoresSafeArea()
            switch section {
            case .timer:
                HomeView(store: store, section: $section)
            case .history:
                HistoryView(store: store, section: $section)
            case .settings:
                SettingsView(store: store, section: $section)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AppTabBar: View {
    @Binding var section: AppSection

    var body: some View {
        HStack {
            tab(.timer, "计时", "timer")
            tab(.history, "轨迹", "chart.xyaxis.line")
            tab(.settings, "设置", "gearshape")
        }
        .padding(.top, 8)
    }

    private func tab(_ value: AppSection, _ title: String, _ symbol: String) -> some View {
        let selected = section == value
        return Button {
            section = value
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(selected ? Obsidian.lava : Color.clear)
                    .frame(width: 5, height: 5)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .regular))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(selected ? Color.white : Obsidian.faint)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
