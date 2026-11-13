import SwiftUI

private struct HistoryRow: Identifiable {
    var number: Int
    var round: ArchivedRound
    var id: UUID { round.id }
}

struct HistoryView: View {
    @ObservedObject var store: TimerStore
    @Binding var section: AppSection

    var body: some View {
        TimelineView(SecondSchedule()) { context in
            let _ = context.date
            let now = Date()
            let stats = store.statistics(at: now)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("轨迹")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Obsidian.silver)
                    HStack(spacing: 0) {
                        stat("当前", ElapsedTime.durationText(totalSeconds: stats.currentSeconds))
                        stat("最长", ElapsedTime.durationText(totalSeconds: stats.longestSeconds))
                        stat("轮次", "\(stats.rounds)")
                    }
                    if store.undo != nil {
                        Button("撤销最近一次重新开始") {
                            store.undoRestart()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Obsidian.silver)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    roundCard(
                        title: "这一轮",
                        start: store.currentStart,
                        end: nil,
                        now: now,
                        seconds: stats.currentSeconds
                    )
                    if store.archive.isEmpty {
                        Text("还没有归档的轮次。计时会一直继续，直到你确认重新开始。")
                            .font(.subheadline)
                            .foregroundStyle(Obsidian.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(Array(historyRows.reversed())) { row in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("第 \(row.number) 轮")
                                    .font(.headline)
                                    .foregroundStyle(Obsidian.silver)
                                Text("\(stamp(row.round.startedAt, now: now))  →  \(stamp(row.round.endedAt, now: now))")
                                    .font(.subheadline)
                                    .foregroundStyle(Obsidian.muted)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(2)
                                Text(ElapsedTime.durationText(totalSeconds: row.round.durationSeconds))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Obsidian.line).frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .safeAreaInset(edge: .bottom) {
                AppTabBar(section: $section)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
                    .background(Obsidian.background.opacity(0.94))
            }
        }
    }

    private var historyRows: [HistoryRow] {
        store.archive.enumerated().map { HistoryRow(number: $0.offset + 1, round: $0.element) }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Obsidian.faint)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Obsidian.silver)
                .minimumScaleFactor(0.6)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roundCard(title: String, start: Date, end: Date?, now: Date, seconds: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Obsidian.silver)
            Text(end == nil
                 ? "\(stamp(start, now: now)) 开始，仍在继续"
                 : "\(stamp(start, now: now))  →  \(stamp(end ?? now, now: now))")
                .font(.subheadline)
                .foregroundStyle(Obsidian.muted)
            Text(ElapsedTime.durationText(totalSeconds: seconds))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func stamp(_ date: Date, now: Date) -> String {
        ElapsedTime.startCaption(start: date, now: now)
            .replacingOccurrences(of: "开始于 ", with: "")
    }
}
