import SwiftUI

/// A1 — app splash. Centered logo + wordmark. Auto-advances after 1.5s
/// from `OnboardingFlow`.
struct A1Splash: View {
    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 22)
                .fill(AppColor.sage)
                .frame(width: 76, height: 76)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 20, height: 8)
                            .offset(y: -11)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 24, height: 22)
                            .offset(y: 5)
                        Circle()
                            .fill(AppColor.sage)
                            .frame(width: 10, height: 10)
                            .offset(y: 8)
                    }
                )
                .shadow(color: AppColor.sage.opacity(0.25), radius: 12, x: 0, y: 8)

            SerifText("Vitamin Tracker", size: 32)
            LabelText("A quiet daily ritual", color: AppColor.ink4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bg)
    }
}

#Preview { A1Splash() }
