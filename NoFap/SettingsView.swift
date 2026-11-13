import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var store: TimerStore
    @Binding var section: AppSection

    @State private var editingStart = false
    @State private var draftDate = Date()
    @State private var draftSecond = 0
    @State private var message = ""
    @State private var confirmingErase = false
    @State private var showingBreath = false
    @State private var exportPayload: ExportPayload?
    @State private var reminderDenied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("设置")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Obsidian.silver)
                sectionTitle("计时起点")
                Text(ElapsedTime.startCaption(start: store.currentStart, now: Date()))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.white)
                Text("改起点会按新的开始时间重算这一轮，不会另记一档。重新开始才会把上一轮归档。")
                    .font(.footnote)
                    .foregroundStyle(Obsidian.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("修改开始时间") {
                    draftDate = store.currentStart
                    draftSecond = Calendar.current.component(.second, from: store.currentStart)
                    editingStart = true
                }
                .buttonStyle(ObsidianButtonStyle())

                if store.undo != nil {
                    Button("撤销最近一次重新开始") {
                        if case .success = store.undoRestart() {
                            message = "已回到上一轮的开始时间。"
                        }
                    }
                    .buttonStyle(ObsidianButtonStyle())
                }

                sectionTitle("提醒")
                Toggle(isOn: reminderBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("到点看一眼")
                        Text("可选。关掉或拒绝通知，计时一样继续。这不是每天要完成的打卡。")
                            .font(.footnote)
                            .foregroundStyle(Obsidian.muted)
                    }
                }
                .tint(Obsidian.lava)
                if store.reminderEnabled {
                    DatePicker(
                        "时间",
                        selection: reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                }
                if reminderDenied {
                    Text("通知没有打开。计时不受影响。")
                        .font(.footnote)
                        .foregroundStyle(Obsidian.muted)
                }

                sectionTitle("呼吸")
                Text("需要停一下时可以用。它不暂停、也不重置计时。")
                    .font(.footnote)
                    .foregroundStyle(Obsidian.muted)
                Button("开始呼吸") { showingBreath = true }
                    .buttonStyle(ObsidianButtonStyle())

                sectionTitle("这台手机上的记录")
                Button("导出记录") {
                    if let data = try? store.exportData() {
                        exportPayload = ExportPayload(data: data)
                    } else {
                        message = "导出没有成功。"
                    }
                }
                .buttonStyle(ObsidianButtonStyle())
                Button("清除本机记录") { confirmingErase = true }
                    .buttonStyle(ObsidianButtonStyle(role: .destructive))
                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Obsidian.muted)
                }
                Text("没有账号。记录不会上传，也不作为样本收集。这是计时工具，不承诺医疗或健康效果。")
                    .font(.footnote)
                    .foregroundStyle(Obsidian.faint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            AppTabBar(section: $section)
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
                .background(Obsidian.background.opacity(0.94))
        }
        .sheet(isPresented: $editingStart) {
            startEditor
        }
        .sheet(isPresented: $showingBreath) {
            BreathingView()
        }
        .sheet(item: $exportPayload) { payload in
            ShareSheet(data: payload.data)
        }
        .alert("清除本机记录", isPresented: $confirmingErase) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                store.eraseAll(at: Date())
                GlanceReminder.apply(enabled: false, hour: store.reminderHour, minute: store.reminderMinute)
                message = "记录已清除，新的一轮从刚才这一秒开始。"
            }
        } message: {
            Text("轨迹、起点修改和撤销都会删掉，并且不能恢复。计时会从清除的这一秒重新开始。")
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { store.reminderEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        let allowed = await GlanceReminder.requestPermission()
                        if allowed {
                            store.setReminder(enabled: true, hour: store.reminderHour, minute: store.reminderMinute)
                            GlanceReminder.apply(enabled: true, hour: store.reminderHour, minute: store.reminderMinute)
                            reminderDenied = false
                        } else {
                            store.setReminder(enabled: false, hour: store.reminderHour, minute: store.reminderMinute)
                            reminderDenied = true
                        }
                    }
                } else {
                    store.setReminder(enabled: false, hour: store.reminderHour, minute: store.reminderMinute)
                    GlanceReminder.apply(enabled: false, hour: store.reminderHour, minute: store.reminderMinute)
                    reminderDenied = false
                }
            }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                parts.hour = store.reminderHour
                parts.minute = store.reminderMinute
                return Calendar.current.date(from: parts) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.setReminder(
                    enabled: true,
                    hour: parts.hour ?? 21,
                    minute: parts.minute ?? 0
                )
                GlanceReminder.apply(enabled: true, hour: store.reminderHour, minute: store.reminderMinute)
            }
        )
    }

    private var startEditor: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DatePicker("日期和时间", selection: $draftDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                Stepper("秒：\(draftSecond)", value: $draftSecond, in: 0...59)
                Text("不能设在当前时间之后。保存后按这个起点重算，精确到秒。")
                    .font(.footnote)
                    .foregroundStyle(Obsidian.muted)
            }
            .padding(20)
            }
            .background(Obsidian.background)
            .navigationTitle("开始时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { editingStart = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveStart() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveStart() {
        let now = Date()
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: draftDate)
        parts.second = draftSecond
        let chosen = calendar.date(from: parts) ?? draftDate
        switch store.adjustStart(to: chosen, now: now) {
        case .success:
            message = "开始时间已更新。"
            editingStart = false
        case .refused(.futureStart):
            message = "开始时间不能晚于现在。"
            editingStart = false
        case .refused(_):
            message = "开始时间没有改成。"
            editingStart = false
        }
    }
}

struct BreathingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = "吸气"
    @State private var running = true

    var body: some View {
        VStack(spacing: 28) {
            Text("呼吸")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Obsidian.silver)
            Text(phase)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 220, height: 220)
                .background(
                    Circle()
                        .stroke(Obsidian.lava.opacity(0.85), lineWidth: 2)
                        .scaleEffect(circleScale)
                )
                .animation(reduceMotion ? nil : .easeInOut(duration: 4), value: phase)
            Text("计时没有暂停，也没有归零。")
                .font(.footnote)
                .foregroundStyle(Obsidian.muted)
            Button("结束") { dismiss() }
                .buttonStyle(ObsidianButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Obsidian.background)
        .task {
            let phases = [("吸气", 4), ("屏息", 4), ("呼气", 6)]
            while !Task.isCancelled && running {
                for item in phases {
                    phase = item.0
                    try? await Task.sleep(nanoseconds: UInt64(item.1) * 1_000_000_000)
                }
            }
        }
        .onDisappear { running = false }
        .preferredColorScheme(.dark)
    }

    private var circleScale: CGFloat {
        if reduceMotion { return 1 }
        switch phase {
        case "吸气": return 1.08
        case "呼气": return 0.86
        default: return 1
        }
    }
}

struct ObsidianButtonStyle: ButtonStyle {
    enum Role { case normal, destructive }
    var role: Role = .normal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(role == .destructive ? Obsidian.lava : Obsidian.silver)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Obsidian.buttonFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(white: 0.24), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ExportPayload: Identifiable {
    let id = UUID()
    let data: Data
}

struct ShareSheet: UIViewControllerRepresentable {
    let data: Data

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nofap-timer.json")
        try? data.write(to: url, options: .atomic)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
