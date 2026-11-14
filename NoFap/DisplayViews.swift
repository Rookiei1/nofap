import SwiftUI
import CoreText

/// Live glyph outlines fit the tall numerals without the font's ascender gaps.
struct MetalDayNumerals: View {
    var text: String

    var body: some View {
        Canvas { context, size in
            let font = CTFontCreateWithName("SixCaps" as CFString, 200, nil)
            let outlines = CGMutablePath()
            var advanceX: CGFloat = 0
            for character in text.utf16 {
                var code = character
                var glyph: CGGlyph = 0
                CTFontGetGlyphsForCharacters(font, &code, &glyph, 1)
                if let outline = CTFontCreatePathForGlyph(font, glyph, nil) {
                    outlines.addPath(outline, transform: CGAffineTransform(translationX: advanceX, y: 0))
                }
                var advance = CGSize.zero
                CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
                advanceX += advance.width + 2
            }
            let bounds = outlines.boundingBoxOfPath
            guard bounds.width > 0, bounds.height > 0 else { return }
            let vertical = min(size.height / bounds.height, size.width / (bounds.width * 1.38))
            let horizontal = vertical * 1.38
            var fit = CGAffineTransform(a: horizontal, b: 0, c: 0, d: -vertical,
                                       tx: -bounds.minX * horizontal,
                                       ty: size.height + bounds.minY * vertical)
            guard let fitted = outlines.copy(using: &fit) else { return }
            context.fill(Path(fitted), with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(white: 0.98), location: 0),
                    .init(color: Color(white: 0.84), location: 0.36),
                    .init(color: Color(white: 0.96), location: 0.46),
                    .init(color: Color(white: 0.56), location: 0.85),
                    .init(color: Color(white: 0.68), location: 1)
                ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
        .accessibilityHidden(true)
    }
}

/// Two ascending metal faces and a separate column for the actual day scale.
struct TimeSpine: View {
    var days: Int
    var reduceMotion: Bool

    var body: some View {
        let scale = ElapsedTime.spine(days: days)
        Canvas { context, size in
            let labelWidth: CGFloat = scale.maximum >= 1_000 ? 43 : 30
            let metalWidth = max(28, size.width - labelWidth - 8)
            let top: CGFloat = 3
            let bottom = size.height - 4
            let scaleTop = size.height * 0.24
            let scaleBottom = size.height * 0.89
            func face(_ points: [CGPoint]) -> Path {
                var path = Path()
                path.addLines(points)
                path.closeSubpath()
                return path
            }
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: metalWidth * x, y: top + (bottom - top) * y)
            }
            let back = face([point(0.55, 0.13), point(0.98, 0), point(0.98, 0.96), point(0.55, 1)])
            context.fill(back, with: .linearGradient(
                Gradient(colors: [Color(white: 0.38), Color(white: 0.10), Color(white: 0.04)]),
                startPoint: point(0.55, 0), endPoint: point(1, 1)
            ))
            let backEdge = face([point(0.98, 0), point(1, 0.012), point(1, 0.96), point(0.98, 0.96)])
            context.fill(backEdge, with: .color(Color(white: 0.44)))
            var upperEdge = Path()
            upperEdge.move(to: point(0.55, 0.13))
            upperEdge.addLine(to: point(0.98, 0))
            context.stroke(upperEdge, with: .color(Color(white: 0.80)), lineWidth: 0.75)
            let front = face([point(0.12, 0.48), point(0.70, 0.33), point(0.70, 1), point(0.02, 1)])
            context.fill(front, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(white: 0.08), location: 0),
                    .init(color: Color(white: 0.34), location: 0.28),
                    .init(color: Color(white: 0.12), location: 0.53),
                    .init(color: Color(white: 0.035), location: 1)
                ]), startPoint: point(0.1, 0.38), endPoint: point(0.75, 1)
            ))
            let bevel = face([point(0.70, 0.33), point(0.77, 0.35), point(0.77, 1), point(0.70, 1)])
            context.fill(bevel, with: .color(Color(white: 0.045)))
            var frontEdge = Path()
            frontEdge.move(to: point(0.12, 0.48))
            frontEdge.addLine(to: point(0.70, 0.33))
            frontEdge.addLine(to: point(0.70, 1))
            context.stroke(frontEdge, with: .linearGradient(
                Gradient(colors: [Color(white: 0.74), Color(white: 0.22)]),
                startPoint: point(0.1, 0.4), endPoint: point(0.7, 1)
            ), lineWidth: 0.75)
            var brushed = context
            brushed.clip(to: back)
            for index in 0..<90 {
                let y = CGFloat(index) * 5
                var grain = Path()
                grain.move(to: CGPoint(x: 0, y: y + 20))
                grain.addLine(to: CGPoint(x: metalWidth, y: y - 12))
                brushed.stroke(grain, with: .color(.white.opacity(index % 3 == 0 ? 0.055 : 0.025)), lineWidth: 0.5)
            }
            var frontBrush = context
            frontBrush.clip(to: front)
            for index in 0..<90 {
                let y = CGFloat(index) * 4
                var grain = Path()
                grain.move(to: CGPoint(x: 0, y: y + 22))
                grain.addLine(to: CGPoint(x: metalWidth, y: y - 16))
                frontBrush.stroke(grain, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
            }
            let seamX = metalWidth * 0.94
            var seam = Path()
            seam.move(to: CGPoint(x: seamX, y: scaleTop))
            seam.addLine(to: CGPoint(x: seamX, y: scaleBottom))
            context.stroke(seam, with: .color(Obsidian.lava.opacity(0.25)), lineWidth: 1)
            let currentY = scaleBottom - CGFloat(scale.fraction) * (scaleBottom - scaleTop)
            var current = Path()
            current.move(to: CGPoint(x: seamX - 2, y: currentY))
            current.addLine(to: CGPoint(x: seamX + 3, y: currentY))
            context.stroke(current, with: .color(Obsidian.lava), lineWidth: 2)
            for division in 0...15 {
                let y = scaleBottom - CGFloat(division) / 15 * (scaleBottom - scaleTop)
                let major = division % 5 == 0
                var mark = Path()
                mark.move(to: CGPoint(x: metalWidth + 5, y: y))
                mark.addLine(to: CGPoint(x: metalWidth + (major ? 13 : 9), y: y))
                context.stroke(mark, with: .color(Color(white: major ? 0.57 : 0.28)), lineWidth: 0.6)
                if major {
                    let value = scale.ticks[division / 5]
                    let label = Text("+\(value)").font(.system(size: scale.maximum >= 1_000 ? 9 : 10))
                        .foregroundStyle(Obsidian.muted)
                    context.draw(label, at: CGPoint(x: metalWidth + 17, y: y), anchor: .leading)
                }
            }
        }
        .accessibilityLabel("时间脊柱，已坚持 \(days) 天，刻度 0 到 \(scale.maximum) 天")
    }
}

struct HourRuler: View {
    var fraction: Double

    var body: some View {
        Canvas { context, size in
            for index in 0...30 {
                let x = 1 + (size.width - 2) * CGFloat(index) / 30
                let height: CGFloat = index % 5 == 0 ? 11 : 5
                var mark = Path()
                mark.move(to: CGPoint(x: x, y: size.height))
                mark.addLine(to: CGPoint(x: x, y: size.height - height))
                context.stroke(mark, with: .color(Color(white: index % 5 == 0 ? 0.42 : 0.25)), lineWidth: 0.75)
            }
            let x = 1 + (size.width - 2) * CGFloat(min(1, max(0, fraction)))
            var current = Path()
            current.move(to: CGPoint(x: x, y: 0))
            current.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(current, with: .color(Obsidian.lava), lineWidth: 1.5)
        }
        .frame(height: 17)
        .accessibilityLabel("这一小时已经过去 \(Int(fraction * 60)) 分钟")
    }
}
