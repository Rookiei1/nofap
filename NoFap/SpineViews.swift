import SwiftUI

/// Wide metal monolith beside the day count. Tick labels sit in their own column
/// so they are not clipped, and the red mark is the current day on that scale.
struct TimeSpine: View {
    var days: Int
    var reduceMotion: Bool

    var body: some View {
        let spine = ElapsedTime.spine(days: days)
        Canvas { context, size in
            let labelWidth: CGFloat = 46
            let right = size.width - labelWidth
            let top: CGFloat = 10
            let bottom = size.height - 10
            let height = max(48, bottom - top)
            let slabWidth = min(148, max(78, right * 0.58))
            let left = right - slabWidth

            func yPosition(_ fraction: CGFloat) -> CGFloat {
                let clamped = min(1, max(0, fraction))
                return min(bottom - 12, max(top + 12, bottom - clamped * height))
            }

            var back = Path()
            back.move(to: CGPoint(x: left + 28, y: top + 22))
            back.addLine(to: CGPoint(x: right + 8, y: top + 34))
            back.addLine(to: CGPoint(x: right - 6, y: bottom + 6))
            back.addLine(to: CGPoint(x: left + 10, y: bottom - 4))
            back.closeSubpath()
            context.fill(back, with: .color(Color.black.opacity(0.85)))

            var side = Path()
            side.move(to: CGPoint(x: right - slabWidth * 0.22, y: top + 16))
            side.addLine(to: CGPoint(x: right, y: top + 6))
            side.addLine(to: CGPoint(x: right - 12, y: bottom))
            side.addLine(to: CGPoint(x: right - slabWidth * 0.28, y: bottom - 10))
            side.closeSubpath()
            context.fill(
                side,
                with: .linearGradient(
                    Gradient(colors: [Color(white: 0.20), Color(white: 0.05)]),
                    startPoint: CGPoint(x: right - slabWidth * 0.28, y: top),
                    endPoint: CGPoint(x: right, y: bottom)
                )
            )

            var front = Path()
            front.move(to: CGPoint(x: left + 18, y: top))
            front.addLine(to: CGPoint(x: right - slabWidth * 0.16, y: top + 18))
            front.addLine(to: CGPoint(x: right - slabWidth * 0.24, y: bottom - 4))
            front.addLine(to: CGPoint(x: left, y: bottom - 18))
            front.closeSubpath()
            context.fill(
                front,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(white: 0.55), location: 0),
                        .init(color: Color(white: 0.22), location: 0.16),
                        .init(color: Color(white: 0.07), location: 0.48),
                        .init(color: Color(white: 0.16), location: 1)
                    ]),
                    startPoint: CGPoint(x: left, y: top),
                    endPoint: CGPoint(x: right, y: bottom)
                )
            )

            var highlight = Path()
            highlight.move(to: CGPoint(x: left + 18, y: top))
            highlight.addLine(to: CGPoint(x: left + 30, y: top + 6))
            highlight.addLine(to: CGPoint(x: left + 12, y: bottom - 14))
            highlight.addLine(to: CGPoint(x: left, y: bottom - 18))
            highlight.closeSubpath()
            context.fill(
                highlight,
                with: .linearGradient(
                    Gradient(colors: [Color(white: 0.96), Color(white: 0.55)]),
                    startPoint: CGPoint(x: left, y: top),
                    endPoint: CGPoint(x: left + 24, y: bottom)
                )
            )

            let indicatorY = yPosition(CGFloat(spine.fraction))
            var seam = Path()
            seam.move(to: CGPoint(x: right - slabWidth * 0.18, y: top + 20))
            seam.addLine(to: CGPoint(x: right - slabWidth * 0.22, y: bottom - 8))
            context.stroke(seam, with: .color(Obsidian.lava.opacity(reduceMotion ? 0.45 : 0.28)), lineWidth: 4)
            var current = Path()
            current.move(to: CGPoint(x: right - slabWidth * 0.19, y: max(top + 14, indicatorY - 34)))
            current.addLine(to: CGPoint(x: right - slabWidth * 0.21, y: min(bottom - 8, indicatorY + 16)))
            context.stroke(current, with: .color(Obsidian.lava), lineWidth: 3)

            for tick in spine.ticks {
                let fraction = CGFloat(tick) / CGFloat(max(spine.maximum, 1))
                let y = yPosition(fraction)
                var tickMark = Path()
                tickMark.move(to: CGPoint(x: right + 6, y: y))
                tickMark.addLine(to: CGPoint(x: right + 14, y: y))
                context.stroke(tickMark, with: .color(Color(white: 0.62)), lineWidth: 1)
                let label = Text("+\(tick)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(white: 0.78))
                context.draw(label, at: CGPoint(x: right + 18, y: y), anchor: .leading)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("时间脊柱，已坚持 \(days) 天，刻度 0 到 \(spine.maximum)")
    }
}

struct HourRuler: View {
    var fraction: Double

    var body: some View {
        Canvas { context, size in
            let count = 41
            for index in 0..<count {
                let x = size.width * CGFloat(index) / CGFloat(count - 1)
                let markHeight: CGFloat = index % 5 == 0 ? 11 : 6
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x, y: size.height - markHeight))
                context.stroke(path, with: .color(Color(white: 0.42)), lineWidth: 1)
            }
            let x = size.width * CGFloat(min(1, max(0, fraction)))
            var marker = Path()
            marker.move(to: CGPoint(x: x, y: 1))
            marker.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(marker, with: .color(Obsidian.lava), lineWidth: 2)
        }
        .frame(height: 18)
        .accessibilityLabel("这一小时已经过去的位置")
    }
}
