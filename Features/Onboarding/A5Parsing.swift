import SwiftUI

/// A5 — label-parsing loading screen. Three bottles bob in sequence while
/// an indeterminate bar slides. Auto-advances after 2s. Port of `A5Parsing`.
struct A5Parsing: View {
    var onComplete: () -> Void = {}

    @State private var bob: Bool = false
    @State private var slide: CGFloat = -0.4

    private struct Mini { let tint: UInt32; let accent: UInt32; let label: String }
    private let bottles: [Mini] = [
        .init(tint: 0xF3E5C6, accent: 0xC49A48, label: "Vi"),
        .init(tint: 0xE5EDD9, accent: 0x7C9658, label: "Om"),
        .init(tint: 0xE2E6EE, accent: 0x6F7C96, label: "Ma"),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                ForEach(Array(bottles.enumerated()), id: \.offset) { i, b in
                    BottleView(
                        tint: Color(hex: b.tint),
                        accent: Color(hex: b.accent),
                        label: b.label,
                        size: 56
                    )
                    .offset(
                        x: CGFloat(-60 + i * 60),
                        y: CGFloat(-12 + i * 12) + (bob ? -8 : 0)
                    )
                    .animation(
                        .easeInOut(duration: 2.0 + Double(i) * 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: bob
                    )
                }

                LinearGradient(
                    colors: [.clear, AppColor.sage, .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 1)
                .offset(y: 70)
            }
            .frame(width: 240, height: 160)

            VStack(spacing: 10) {
                (Text("Reading your stack")
                    .font(AppFont.serif(32))
                 + Text("…")
                    .font(AppFont.serif(32, italic: true))
                    .foregroundStyle(AppColor.ink3))
                    .foregroundStyle(AppColor.ink)

                BodyText("Extracting name, dose, and frequency from each label.",
                         size: 14, color: AppColor.ink3)
            }
            .multilineTextAlignment(.center)

            indeterminateBar
                .frame(width: 180, height: 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bg)
        .onAppear {
            bob = true
            startSlide()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(2000))
            onComplete()
        }
    }

    private var indeterminateBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.surface2)
                Capsule()
                    .fill(AppColor.sage)
                    .frame(width: geo.size.width * 0.4)
                    .offset(x: geo.size.width * slide)
            }
        }
    }

    private func startSlide() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
            slide = 1.0
        }
    }
}

#Preview { A5Parsing() }
