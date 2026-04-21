import SwiftUI

/// SVG-style supplement bottle illustration. Port of the `Bottle` component
/// in `Shared.jsx`. `tint` fills the body, `accent` the cap and label ink.
struct BottleView: View {
    var tint: Color
    var accent: Color
    var label: String = "Rx"
    var size: CGFloat = 72

    private var width: CGFloat  { size }
    private var height: CGFloat { size * 1.25 }

    var body: some View {
        Canvas { ctx, size in
            // Scale: viewBox 72×90 → rendered width×height
            let sx = size.width / 72
            let sy = size.height / 90

            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 0) -> Path {
                let rect = CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)
                return Path(roundedRect: rect, cornerRadius: radius * min(sx, sy))
            }

            // cap
            ctx.fill(rect(20, 6, 32, 12, radius: 3), with: .color(accent))
            // cap highlight
            ctx.fill(rect(22, 8, 28, 2, radius: 1), with: .color(.white.opacity(0.25)))
            // neck
            ctx.fill(rect(24, 16, 24, 6), with: .color(accent.opacity(0.85)))

            // body with vertical gradient (tint → accent*0.45)
            let body = rect(14, 20, 44, 66, radius: 8)
            let gradient = Gradient(stops: [
                .init(color: tint, location: 0),
                .init(color: accent.opacity(0.45), location: 1)
            ])
            ctx.fill(
                body,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 36 * sx, y: 20 * sy),
                    endPoint:   CGPoint(x: 36 * sx, y: 86 * sy)
                )
            )

            // left highlight streak
            ctx.fill(rect(17, 23, 6, 58, radius: 3), with: .color(.white.opacity(0.35)))

            // label band
            ctx.fill(rect(18, 42, 36, 30, radius: 3), with: .color(.white.opacity(0.85)))

            // text ruling
            ctx.fill(rect(22, 48, 20, 3, radius: 1), with: .color(accent.opacity(0.7)))
            ctx.fill(rect(22, 54, 28, 2, radius: 1), with: .color(accent.opacity(0.4)))
            ctx.fill(rect(22, 58, 14, 2, radius: 1), with: .color(accent.opacity(0.35)))

            // centered italic serif label
            let txt = Text(label)
                .font(AppFont.serif(8 * min(sx, sy), italic: true))
                .foregroundStyle(accent)
            ctx.draw(txt, at: CGPoint(x: 36 * sx, y: 68 * sy), anchor: .center)
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    HStack(spacing: 20) {
        BottleView(tint: Color(hex: 0xF3E5C6), accent: Color(hex: 0xC49A48), label: "D3")
        BottleView(tint: Color(hex: 0xE5EDD9), accent: Color(hex: 0x7C9658), label: "O3")
        BottleView(tint: Color(hex: 0xE2E6EE), accent: Color(hex: 0x6F7C96), label: "Mg")
    }
    .padding()
}
