import SwiftUI

/// A2 — welcome hero. Port of `A2Welcome`.
struct A2Welcome: View {
    var onNext: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            scannerHero
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 14) {
                (Text("Snap your supplements.\n")
                    .font(AppFont.serif(40))
                    .foregroundStyle(AppColor.ink)
                 + Text("We'll do the rest.")
                    .font(AppFont.serif(40, italic: true))
                    .foregroundStyle(AppColor.ink3))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(0)
                    .fixedSize(horizontal: false, vertical: true)

                BodyText(
                    "Point your camera at a label. We read the name, dose, and schedule — then build your stack in about a minute.",
                    size: 15,
                    color: AppColor.ink3
                )
                .frame(maxWidth: 300, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 10)

            PillButton(title: "Get started", variant: .primary, action: onNext)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Text("No account needed · stored on your device")
                .font(AppFont.sans(12))
                .foregroundStyle(AppColor.ink4)
                .padding(.top, 14)
                .padding(.bottom, 28)
        }
    }

    private var scannerHero: some View {
        ZStack {
            // dashed scanner frame
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                .foregroundStyle(AppColor.ink4.opacity(0.6))
                .frame(width: 160, height: 180)

            // corner brackets
            corners

            BottleView(
                tint: Color(hex: 0xF3E5C6),
                accent: Color(hex: 0xC49A48),
                label: "D3",
                size: 72
            )

            // scan line
            LinearGradient(
                colors: [.clear, AppColor.sage, .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 2)
            .frame(maxWidth: 150)
            .opacity(0.7)
        }
        .frame(width: 260, height: 220)
    }

    private var corners: some View {
        ZStack {
            ForEach([(-80, -90), (80, -90), (-80, 90), (80, 90)], id: \.0) { dx, dy in
                CornerBracket()
                    .stroke(AppColor.ink, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(
                        .degrees(dx < 0 ? (dy < 0 ? 0 : 270)
                                         : (dy < 0 ? 90 : 180))
                    )
                    .offset(x: CGFloat(dx), y: CGFloat(dy))
            }
        }
    }
}

/// L-shape drawn for each of the four scanner corners.
struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

#Preview { A2Welcome() }
