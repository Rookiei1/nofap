import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: TimerStore
    @Binding var section: AppSection
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(SecondSchedule()) { context in
            let _ = context.date
            let now = Date()
            let stats = store.statistics(at: now)
            let current = store.components(at: now)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("轨迹").font(.system(size: 32, weight: .semibold))
                        Text("每一秒，都算数。")
                            .font(.subheadline).foregroundStyle(Obsidian.muted)
                    }
                    currentRound(current, now: now)
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 12) { longest(stats.longestSeconds); rounds(stats.rounds) }
                    } else {
                        HStack(alignment: .top, spacing: 12) { longest(stats.longestSeconds); rounds(stats.rounds) }
                    }
                    if store.undo != nil {
                        Button {
                            store.undoRestart()
                        } label: {
                            Label("撤销最近一次重新开始", systemImage: "arrow.uturn.backward")
                                .font(.subheadline)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        Text("历次记录").font(.headline)
                        if store.archive.isEmpty {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.system(size: 27, weight: .ultraLight))
                                    .foregroundStyle(Obsidian.muted)
                                    .frame(width: 36, height: 44)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("第一轮，正在发生").font(.subheadline.weight(.medium))
                                    Text("计时一直继续。确认重新开始后，上一轮会留在这里。")
                                        .font(.footnote).foregroundStyle(Obsidian.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 12)
                        } else {
                            ForEach(Array(store.archive.enumerated().reversed()), id: \.element.id) { entry in
                                archivedRound(entry.element, number: entry.offset + 1, now: now)
                            }
                        }
                    }
                }
                .foregroundStyle(Obsidian.silver)
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func currentRound(_ value: ElapsedComponents, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(Obsidian.lava).frame(width: 5, height: 5)
                Text(value.clockBehind ? "等待校正系统时间" : "这一轮 · 正在继续")
                    .font(.subheadline).foregroundStyle(Obsidian.muted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(value.days)").font(.system(size: 64, weight: .light, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                Text("天").font(.callout).foregroundStyle(Obsidian.muted)
            }
            Text(value.clockText).font(.system(size: 32, weight: .light, design: .monospaced))
                .accessibilityLabel(value.spoken)
            Rectangle().fill(Obsidian.line).frame(height: 0.5)
            Text(ElapsedTime.startCaption(start: store.currentStart, now: now))
                .font(.footnote.monospacedDigit()).foregroundStyle(Obsidian.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Obsidian.buttonFill, in: RoundedRectangle(cornerRadius: 22))
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2).fill(Obsidian.lava)
                .frame(width: 24, height: 2).padding(.leading, 22)
        }
        .accessibilityIdentifier("current-round")
    }

    private func longest(_ seconds: Int) -> some View {
        let value = ElapsedTime.components(from: Date(timeIntervalSince1970: 0),
                                          to: Date(timeIntervalSince1970: TimeInterval(seconds)))
        return VStack(alignment: .leading, spacing: 12) {
            Label("最长坚持", systemImage: "flag").font(.caption).foregroundStyle(Obsidian.muted)
            Text("\(value.days) 天").font(.title2.weight(.light)).monospacedDigit()
            Text(value.clockText).font(.footnote.monospacedDigit()).foregroundStyle(Obsidian.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).background(Obsidian.buttonFill, in: RoundedRectangle(cornerRadius: 18))
    }

    private func rounds(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("累计轮次", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption).foregroundStyle(Obsidian.muted)
            Text("\(count)").font(.title2.weight(.light)).monospacedDigit()
            Text("包含正在继续的一轮").font(.caption2).foregroundStyle(Obsidian.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).background(Obsidian.buttonFill, in: RoundedRectangle(cornerRadius: 18))
    }

    private func archivedRound(_ round: ArchivedRound, number: Int, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: "%02d", number)).font(.caption.monospacedDigit())
                    .foregroundStyle(Obsidian.muted)
                Text("第 \(number) 轮").font(.subheadline.weight(.semibold))
            }
            Text(ElapsedTime.durationText(totalSeconds: round.durationSeconds).components(separatedBy: " · ")[0])
                .font(.title3.monospacedDigit())
            VStack(alignment: .leading, spacing: 4) {
                Text("起  \(stamp(round.startedAt, now: now))")
                Text("止  \(stamp(round.endedAt, now: now))")
            }
            .font(.caption.monospacedDigit()).foregroundStyle(Obsidian.muted)
            .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Obsidian.line).frame(height: 0.5).padding(.top, 10)
        }
        .accessibilityIdentifier("archived-round-\(number)")
    }

    private func stamp(_ date: Date, now: Date) -> String {
        ElapsedTime.startCaption(start: date, now: now).replacingOccurrences(of: "开始于 ", with: "")
    }
}
