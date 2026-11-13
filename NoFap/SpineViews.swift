import SwiftUI

struct TimeSpine: View {
    var days: Int
    var reduceMotion: Bool

    var body: some View {
        let spine = ElapsedTime.spine(days: days)
        Canvas { context, size in
            let barWidth = min(16, size.width * 0.24)
            let barX = size.width - barWidth - 36
            let top: CGFloat = 4
            let bottom = size.height - 4
            let height = max(1, bottom - top)
            let barRect = CGRect(x: barX, y: top, width: barWidth, height: height)

            let metal = Gradient(colors: [
                Color(white: 0.28),
                Color(white: 0.07),
                Color(white: 0.18),
                Color(white: 0.04)
            ])
            context.fill(
                Path(roundedRect: barRect, cornerRadius: 1.5),
                with: .linearGradient(
                    metal,
                    startPoint: CGPoint(x: barRect.minX, y: barRect.midY),
                    endPoint: CGPoint(x: barRect.maxX, y: barRect.midY)
                )
            )

            var edge = Path()
            edge.move(to: CGPoint(x: barRect.minX + 0.5, y: barRect.minY + 2))
            edge.addLine(to: CGPoint(x: barRect.minX + 0.5, y: barRect.maxY - 2))
            context.stroke(edge, with: .color(Color.white.opacity(0.38)), lineWidth: 1)

            for tick in spine.ticks {
                let fraction = CGFloat(tick) / CGFloat(spine.maximum)
                let y = bottom - fraction * height
                var mark = Path()
                mark.move(to: CGPoint(x: barRect.maxX + 7, y: y))
                mark.addLine(to: CGPoint(x: barRect.maxX + 16, y: y))
                context.stroke(mark, with: .color(Color(white: 0.58)), lineWidth: 1)
                let label = Text("+\(tick)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(white: 0.62))
                context.draw(label, at: CGPoint(x: barRect.maxX + 20, y: y), anchor: .leading)
            }

            let indicatorY = bottom - CGFloat(spine.fraction) * height
            var glow = Path()
            glow.move(to: CGPoint(x: barRect.minX - 1, y: indicatorY))
            glow.addLine(to: CGPoint(x: barRect.maxX + 3, y: indicatorY))
            if !reduceMotion {
                context.stroke(glow, with: .color(Obsidian.lava.opacity(0.35)), lineWidth: 6)
            }
            context.stroke(glow, with: .color(Obsidian.lava), lineWidth: 1.6)
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
