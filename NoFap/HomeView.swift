import SwiftUI

struct SecondSchedule: TimelineSchedule {
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        AnySequence { () -> AnyIterator<Date> in
            var sentNow = false
            var next = ElapsedTime.nextDisplayDate(after: startDate)
            return AnyIterator {
                if !sentNow {
                    sentNow = true
                    return startDate
                }
                // Low frequency is the background mode. Do not promise a per-second wake.
                if mode == .lowFrequency {
                    return nil
                }
                let value = next
                next = value.addingTimeInterval(1)
                return value
            }
        }
    }
}

struct HomeView: View {
    @ObservedObject var store: TimerStore
    @Binding var section: AppSection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var confirming = false
    @State private var confirmSnapshot = ElapsedComponents(
        days: 0, hours: 0, minutes: 0, seconds: 0, totalSeconds: 0, clockBehind: false
    )
    @State private var refusal = ""
    @State private var showingInfo = false
    @State private var hideUndoHint = false

    var body: some View {
        TimelineView(SecondSchedule()) { context in
            // The timeline only wakes the view. The number is always the
            // current clock minus the saved start, so a stale schedule date
            // cannot add or drop a second.
            let _ = context.date
            let now = Date()
            let components = store.components(at: now)
            GeometryReader { geo in
                ScrollView {
                    page(components: components, now: now,
                         width: max(1, geo.size.width - 48),
                         heroHeight: min(300, max(220, geo.size.height * 0.43)))
                        .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
            }
        }
        .alert("重新开始", isPresented: $confirming) {
            Button("取消", role: .cancel) {}
            Button("重新开始", role: .destructive) {
                let now = Date()
                switch store.restart(at: now) {
                case .success:
                    hideUndoHint = false
                    refusal = ""
                case .refused(.clockBehind):
                    refusal = "系统时间早于开始时间。先校正时间，这一轮不会被清掉。"
                case .refused(_):
                    refusal = "这次没能重新开始。"
                }
            }
        } message: {
            Text("确认的这一秒会成为新一轮的开始，显示 000 天 00:00:00，然后继续计时。上一轮记入轨迹：\(confirmSnapshot.spoken)。")
        }
        .sheet(isPresented: $showingInfo) {
            InfoSheet()
        }
    }

    private func page(components: ElapsedComponents, now: Date, width: CGFloat, heroHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            dayBlock(components, width: width, height: heroHeight)
                .padding(.top, 16)
            Rectangle().fill(Obsidian.line).frame(height: 0.5)
                .padding(.top, 14)
            timeBlock(components, width: width)
                .padding(.top, 14)
            Text(ElapsedTime.startCaption(start: store.currentStart, now: now))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Obsidian.muted)
                .padding(.top, 12)
            if components.clockBehind {
                Text("系统时间早于开始时间，显示停在 000。校正后会按原来的开始时间继续。")
                    .font(.footnote)
                    .foregroundStyle(Obsidian.lava.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
            if !refusal.isEmpty {
                Text(refusal)
                    .font(.footnote)
                    .foregroundStyle(Obsidian.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
            restartButton
                .padding(.top, 20)
            Text("新的一轮，从此刻开始")
                .font(.footnote)
                .foregroundStyle(Obsidian.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
            if store.undo != nil && !hideUndoHint {
                undoBanner
                    .padding(.top, 16)
            }
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("NOFAP")
                    .font(.system(size: 18, weight: .medium))
                        .tracking(5)
                        .foregroundStyle(Obsidian.silver)
                    Text("/")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Obsidian.lava)
                }
                Text("掌控此刻")
                    .font(.caption)
                    .tracking(3)
                    .foregroundStyle(Obsidian.muted)
            }
            Spacer()
            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Obsidian.muted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("说明")
            .buttonStyle(.plain)
        }
    }

    private func dayBlock(_ components: ElapsedComponents, width: CGFloat, height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                MetalDayNumerals(text: ElapsedTime.dayText(components.days))
                    .frame(height: height - 66)
                Text("DAYS")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(6)
                    .foregroundStyle(Obsidian.muted)
                Text(components.clockBehind ? "已坚持 0 天" : "已坚持 \(components.days) 天")
                    .font(.callout)
                    .foregroundStyle(Obsidian.silver)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: width * 0.62, alignment: .leading)
            TimeSpine(days: components.days, reduceMotion: reduceMotion)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(components.spoken)
        .accessibilityIdentifier("day-counter")
    }

    private func timeBlock(_ components: ElapsedComponents, width: CGFloat) -> some View {
        let size = min(60, width * 0.17)
        return
        VStack(alignment: .leading, spacing: 6) {
            Text("连续计时")
                .font(.footnote)
                .foregroundStyle(Obsidian.muted)
            HStack(alignment: .top, spacing: 0) {
                timeColumn(value: components.hours, unit: "时", size: size)
                colon(size: size * 0.8)
                timeColumn(value: components.minutes, unit: "分", size: size)
                colon(size: size * 0.8)
                timeColumn(value: components.seconds, unit: "秒", size: size)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(components.clockText)
            HourRuler(fraction: ElapsedTime.hourFraction(minutes: components.minutes, seconds: components.seconds))
                .padding(.top, 4)
        }
    }

    private func timeColumn(value: Int, unit: String, size: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: size, weight: .light, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(Obsidian.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func colon(size: CGFloat) -> some View {
        Text(":")
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.white)
            .padding(.top, 2)
            .accessibilityHidden(true)
    }

    private var restartButton: some View {
        Button {
            confirmSnapshot = store.components(at: Date())
            confirming = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Obsidian.lava)
                    .frame(width: 30, height: 30)
                Text("重新开始")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(white: 0.78))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Obsidian.buttonFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(white: 0.52), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("restart-button")
        .accessibilityHint("确认后从零开始新的一轮，并把上一轮记入轨迹")
    }

    private var undoBanner: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
            Text("可以撤销最近一次重新开始")
                .font(.footnote)
                .foregroundStyle(Obsidian.muted)
            Spacer()
            Button("撤销") {
                if case .success = store.undoRestart() {
                    refusal = ""
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Obsidian.silver)
            Button("关闭") {
                hideUndoHint = true
            }
            .font(.footnote)
            .foregroundStyle(Obsidian.faint)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("可以撤销最近一次重新开始").font(.footnote).foregroundStyle(Obsidian.muted)
                HStack(spacing: 24) {
                    Button("撤销") { if case .success = store.undoRestart() { refusal = "" } }
                    Button("关闭") { hideUndoHint = true }
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(Obsidian.silver)
            }
        }
    }
}

private struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("NoFap 从你开始的那一秒持续计时，精确到秒。")
                    Text("天数按每满 24 小时计算，剩下的显示为时、分、秒。跨过午夜或切换时区，都不会额外加一天。")
                    Text("锁屏、切到后台、退出或重启之后，用保存的开始时间重新计算。前台每秒刷新；系统不会让 App 在后台永远每秒运行。")
                    Text("点「重新开始」并确认后，上一轮的开始、结束和持续秒数记入轨迹。新一轮从确认的那一秒归零，然后继续走。最近一次可以撤销。")
                    Text("记录只在这台手机上，没有账号，也不会上传。")
                    Text("这是计时工具，不提供医疗或健康效果承诺。")
                }
                .font(.body)
                .foregroundStyle(Obsidian.silver)
                .padding(24)
            }
            .background(Obsidian.background)
            .navigationTitle("说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
