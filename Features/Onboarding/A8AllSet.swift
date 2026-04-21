import SwiftUI

/// A8 — completion screen. Checkmark ring + summary chips + CTA into the
/// app. Port of `A8AllSet`.
struct A8AllSet: View {
    var onOpenDay: () -> Void = {}

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ProgressRing(size: 120, value: 1, stroke: 4,
                         color: AppColor.sage,
                         background: AppColor.surface3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppColor.sage)
            }

            VStack(spacing: 12) {
                SerifText("You're all set", size: 44)
                BodyText("5 supplements across 3 times of day. We'll nudge you at the right moments.",
                         size: 15, color: AppColor.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            FlowWrap(spacing: 8) {
                Chip(text: "5 supplements", tone: .sage)
                Chip(text: "3 reminders",    tone: .quiet)
                Chip(text: "Stored on device", tone: .quiet)
            }
            .frame(maxWidth: 320)

            Spacer()

            PillButton(title: "Open my day", variant: .sage, action: onOpenDay)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 32)
    }
}

#Preview { A8AllSet() }
