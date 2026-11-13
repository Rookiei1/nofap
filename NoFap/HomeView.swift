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
    var showsTabBar: Bool = true

    @Environment(\.dynamicTypeSize) private var typeSize
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
            ViewThatFits(in: .vertical) {
                page(components: components, now: now, compact: false)
                ScrollView {
                    page(components: components, now: now, compact: true)
                }
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

    private func page(components: ElapsedComponents, now: Date, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            header
            dayBlock(components, compact: compact)
            timeBlock(components, compact: compact)
            Text(ElapsedTime.startCaption(start: store.currentStart, now: now))
                .font(.system(size: metric(13, compact: compact)))
                .foregroundStyle(Obsidian.muted)
            if components.clockBehind {
                Text("系统时间早于开始时间，显示停在 000。校正后会按原来的开始时间继续。")
                    .font(.footnote)
                    .foregroundStyle(Obsidian.lava.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !refusal.isEmpty {
                Text(refusal)
                    .font(.footnote)
                    .foregroundStyle(Obsidian.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            restartButton
            Text("新的一轮，从此刻开始")
                .font(.system(size: metric(13, compact: compact)))
                .foregroundStyle(Obsidian.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
            if store.undo != nil && !hideUndoHint {
                undoBanner
            }
            Spacer(minLength: 0)
            if showsTabBar {
                AppTabBar(section: $section)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("NOFAP")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(5)
                        .foregroundStyle(Obsidian.silver)
                    Text("/")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Obsidian.silver.opacity(0.85))
                }
                Text("掌控此刻")
                    .font(.system(size: 13, weight: .regular))
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
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("说明")
            .buttonStyle(.plain)
        }
    }

    private func dayBlock(_ components: ElapsedComponents, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(ElapsedTime.dayText(components.days))
                    .font(.system(size: metric(132, compact: compact), weight: .black))
                    .foregroundStyle(Obsidian.metal)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .accessibilityHidden(true)
                Text("DAYS")
                    .font(.system(size: metric(13, compact: compact), weight: .medium))
                    .tracking(4)
                    .foregroundStyle(Obsidian.muted)
                    .padding(.top, 2)
                Text(components.clockBehind ? "已坚持 0 天" : "已坚持 \(components.days) 天")
                    .font(.system(size: metric(16, compact: compact), weight: .regular))
                    .foregroundStyle(Obsidian.silver.opacity(0.92))
                    .padding(.top, 6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(components.spoken)
            Spacer(minLength: 8)
            TimeSpine(days: components.days, reduceMotion: reduceMotion)
                .frame(width: 108, height: metric(210, compact: compact))
        }
    }

    private func timeBlock(_ components: ElapsedComponents, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("连续计时")
                .font(.system(size: metric(13, compact: compact)))
                .foregroundStyle(Obsidian.muted)
            HStack(alignment: .top, spacing: 0) {
                timeColumn(value: components.hours, unit: "时", size: metric(54, compact: compact))
                colon(size: metric(48, compact: compact))
                timeColumn(value: components.minutes, unit: "分", size: metric(54, compact: compact))
                colon(size: metric(48, compact: compact))
                timeColumn(value: components.seconds, unit: "秒", size: metric(54, compact: compact))
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
                .font(.system(size: size, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(Obsidian.faint)
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Obsidian.lava)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Obsidian.lava, lineWidth: 1.4))
                Text("重新开始")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(white: 0.78))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 31, style: .continuous)
                    .fill(Obsidian.buttonFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 31, style: .continuous)
                    .stroke(Color(white: 0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("确认后从零开始新的一轮，并把上一轮记入轨迹")
        .padding(.top, 6)
    }

    private var undoBanner: some View {
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
    }

    private func metric(_ base: CGFloat, compact: Bool) -> CGFloat {
        let compactFactor: CGFloat = compact ? 0.78 : 1
        let typeFactor: CGFloat
        switch typeSize {
        case .xSmall: typeFactor = 0.86
        case .small: typeFactor = 0.93
        case .medium, .large: typeFactor = 1
        case .xLarge: typeFactor = 1.06
        case .xxLarge: typeFactor = 1.12
        case .xxxLarge: typeFactor = 1.16
        default: typeFactor = 1.04
        }
        return base * compactFactor * typeFactor
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
