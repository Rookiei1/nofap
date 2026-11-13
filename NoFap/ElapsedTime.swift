import Foundation

/// A streak length computed from two absolute instants.
/// Days are whole 24-hour blocks. The remainder is hours, minutes and seconds.
/// Calendar dates, midnights and time zones are not used.
struct ElapsedComponents: Equatable {
    var days: Int
    var hours: Int
    var minutes: Int
    var seconds: Int
    var totalSeconds: Int
    var clockBehind: Bool

    var clockText: String {
        String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var spoken: String {
        if clockBehind {
            return "系统时间早于开始时间，显示停在 0 天 00:00:00"
        }
        return "已坚持 \(days) 天 \(hours) 小时 \(minutes) 分 \(seconds) 秒"
    }
}

enum ElapsedTime {
    static let dayLength = 86_400

    static func components(from start: Date, to now: Date) -> ElapsedComponents {
        let delta = now.timeIntervalSince(start)
        if delta < 0 {
            return ElapsedComponents(
                days: 0, hours: 0, minutes: 0, seconds: 0,
                totalSeconds: 0, clockBehind: true
            )
        }
        let total = wholeSeconds(delta)
        let days = total / dayLength
        let remainder = total % dayLength
        return ElapsedComponents(
            days: days,
            hours: remainder / 3_600,
            minutes: (remainder % 3_600) / 60,
            seconds: remainder % 60,
            totalSeconds: total,
            clockBehind: false
        )
    }

    /// Floor of a non-negative interval. Sub-second fractions do not advance the display.
    static func wholeSeconds(_ delta: TimeInterval) -> Int {
        guard delta > 0 else { return 0 }
        let floored = delta.rounded(.down)
        guard floored < Double(Int.max) else { return Int.max }
        return Int(floored)
    }

    static func dayText(_ days: Int) -> String {
        let value = max(0, days)
        if value < 1_000 {
            return String(format: "%03d", value)
        }
        return String(value)
    }

    /// Vertical spine scale. Twelve days sits at 12/30, matching the approved marks +0…+30.
    /// Longer streaks step the scale by 30 so the indicator stays on a labeled range.
    static func spine(days: Int) -> (maximum: Int, fraction: Double, ticks: [Int]) {
        let safe = max(0, days)
        let maximum = max(30, ((safe + 29) / 30) * 30)
        let step = maximum / 3
        let fraction = min(1, Double(safe) / Double(maximum))
        return (maximum, fraction, [0, step, step * 2, maximum])
    }

    /// Position of the red mark on the hour ruler: minutes and seconds within the current hour.
    static func hourFraction(minutes: Int, seconds: Int) -> Double {
        let minute = min(59, max(0, minutes))
        let second = min(59, max(0, seconds))
        return Double(minute * 60 + second) / 3_600
    }

    static func durationText(totalSeconds: Int) -> String {
        let shown = components(
            from: Date(timeIntervalSince1970: 0),
            to: Date(timeIntervalSince1970: TimeInterval(max(0, totalSeconds)))
        )
        return "\(shown.days) 天 \(shown.clockText) · \(max(0, totalSeconds)) 秒"
    }

    static func startCaption(start: Date, now: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: now)
        formatter.dateFormat = sameYear ? "MM/dd HH:mm:ss" : "yyyy/MM/dd HH:mm:ss"
        return "开始于 \(formatter.string(from: start))"
    }

    /// The next whole second after `date`. An exact whole second waits one second.
    static func nextDisplayDate(after date: Date) -> Date {
        let interval = date.timeIntervalSince1970
        let whole = interval.rounded(.down)
        if interval == whole {
            return date.addingTimeInterval(1)
        }
        return Date(timeIntervalSince1970: whole + 1)
    }
}
