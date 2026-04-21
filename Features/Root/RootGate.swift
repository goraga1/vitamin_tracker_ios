import SwiftUI
import SwiftData

/// Top-level routing. Onboarding shows until the first `UserProfile` flips
/// `onboardingCompleted` to true. Afterward we never revisit it without an
/// explicit reset.
struct RootGate: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first, profile.onboardingCompleted {
                RootView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: profiles.first?.onboardingCompleted)
    }
}

#Preview("Onboarded") {
    RootGate().modelContainer(MockData.previewContainer())
}

#Preview("Fresh install") {
    RootGate().modelContainer(
        MockData.previewContainer(seedSupplements: false, seedProfile: false)
    )
}
