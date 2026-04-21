import SwiftUI

/// A4 — camera capture mock. Real AVCaptureSession + `LabelParser` wire up
/// in Phase 1c; for now the shutter button just advances the flow so the
/// visual can be QA'd. Port of `A4Camera`.
struct A4Camera: View {
    var onDone: () -> Void
    var onDismiss: () -> Void

    @State private var captured: Int = 2

    var body: some View {
        ZStack {
            // warm-blur background simulating the live feed
            RadialGradient(
                colors: [AppColor.surface3, Color(hex: 0x5C5550), Color(hex: 0x2A2724)],
                center: UnitPoint(x: 0.6, y: 0.35),
                startRadius: 20, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                bottleMask
                Spacer()
                footer
            }
        }
    }

    private var header: some View {
        HStack {
            chromeButton("xmark", action: onDismiss)
            Spacer()
            Text("\(captured) of up to 5")
                .font(AppFont.sans(13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.4)))
            Spacer()
            chromeButton("photo.on.rectangle", action: {})
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var bottleMask: some View {
        ZStack {
            // dark vignette with a bottle-shaped cutout
            Color.black.opacity(0.28)
                .mask(
                    Rectangle()
                        .overlay(
                            VStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 8).fill(.black)
                                    .frame(width: 100, height: 36)
                                RoundedRectangle(cornerRadius: 20).fill(.black)
                                    .frame(width: 120, height: 180)
                            }
                            .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )

            // corner brackets framing the bottle mask
            ZStack {
                ForEach([(-60, -104), (60, -104), (-60, 106), (60, 106)], id: \.0) { dx, dy in
                    CornerBracket()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .rotationEffect(
                            .degrees(dx < 0 ? (dy < 0 ? 0 : 270)
                                             : (dy < 0 ? 90 : 180))
                        )
                        .offset(x: CGFloat(dx), y: CGFloat(dy))
                }
            }
        }
        .frame(width: 200, height: 280)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            Text("Center the label and tap")
                .font(AppFont.sans(14))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.4)))

            HStack(spacing: 20) {
                // thumbnail stack
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColor.surface3)
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white, lineWidth: 2))
                        .rotationEffect(.degrees(-6))
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0xF3E5C6))
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white, lineWidth: 2))
                        .rotationEffect(.degrees(4))
                        .offset(x: 4, y: 4)

                    Text("\(captured)")
                        .font(AppFont.sans(10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(AppColor.sage))
                        .offset(x: 20, y: 18)
                }
                .frame(width: 60, height: 60)

                Spacer()

                Button {
                    captured = min(captured + 1, 5)
                    if captured >= 3 { onDone() }
                } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 76, height: 76)
                        .overlay(
                            Circle()
                                .fill(.white)
                                .padding(4)
                        )
                }
                .buttonStyle(PressScaleStyle())

                Spacer()

                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(AppFont.sans(13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                        )
                }
                .buttonStyle(PressScaleStyle())
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 44)
    }

    private func chromeButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.4)))
        }
    }
}

#Preview { A4Camera(onDone: {}, onDismiss: {}) }
