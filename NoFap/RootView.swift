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
        Group {
            switch section {
            case .timer:
                HomeView(store: store, section: $section)
            case .history:
                HistoryView(store: store, section: $section)
            case .settings:
                SettingsView(store: store, section: $section)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(section: $section)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(Obsidian.background)
                .overlay(alignment: .top) {
                    Rectangle().fill(Obsidian.line.opacity(0.5)).frame(height: 0.5)
                }
        }
        .background(Obsidian.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

struct AppTabBar: View {
    @Binding var section: AppSection

    var body: some View {
        HStack(spacing: 0) {
            tab(.timer, "计时", "timer")
            tab(.history, "轨迹", "chart.xyaxis.line")
            tab(.settings, "设置", "gearshape")
        }
    }

    private func tab(_ value: AppSection, _ title: String, _ symbol: String) -> some View {
        let selected = section == value
        return Button {
            section = value
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .light))
                    .frame(height: 25)
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Circle().fill(Obsidian.lava).frame(width: 4, height: 4)
                                .offset(x: 7, y: -2)
                        }
                    }
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(selected ? Color.white : Obsidian.faint)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("tab-\(value)")
    }
}
