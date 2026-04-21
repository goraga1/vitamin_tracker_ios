import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case splash, welcome, permissions, camera, parsing, confirm, schedule, allSet
}

/// Orchestrates the A1–A8 onboarding sequence. Each step is a standalone
/// view; this view owns the cursor and finalizes the profile on A8. Port
/// of the demo `Scene` switcher in `Screens.jsx`.
struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @State private var step: OnboardingStep = .splash

    var onComplete: () -> Void = {}

    var body: some View {
        ZStack {
            AppColor.bg.ignoresSafeArea()
            currentView
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .id(step)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .task {
            // A1 auto-advances after 1.5s — matches the prototype splash.
            if step == .splash {
                try? await Task.sleep(for: .milliseconds(1500))
                if step == .splash { advance() }
            }
        }
    }

    @ViewBuilder
    private var currentView: some View {
        switch step {
        case .splash:      A1Splash()
        case .welcome:     A2Welcome(onNext: advance)
        case .permissions: A3Permissions(onNext: advance)
        case .camera:      A4Camera(onDone: advance, onDismiss: finish)
        case .parsing:     A5Parsing(onComplete: advance)
        case .confirm:     A6Confirm(onNext: advance)
        case .schedule:    A7Schedule(onNext: advance)
        case .allSet:      A8AllSet(onOpenDay: finish)
        }
    }

    private func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            step = next
        } else {
            finish()
        }
    }

    private func finish() {
        // Mark profile as onboarded; seed the stack so the user lands on a
        // populated Today (matches the "found 5 supplements" moment at A6).
        let existing = try? context.fetch(FetchDescriptor<UserProfile>()).first
        let profile = existing ?? UserProfile(displayName: "Maya", streakDays: 0)
        profile.onboardingCompleted = true
        if existing == nil { context.insert(profile) }

        MockData.seedSupplementsIfEmpty(context: context)

        try? context.save()
        onComplete()
    }
}

#Preview {
    OnboardingFlow()
        .modelContainer(MockData.previewContainer(seedSupplements: false, seedProfile: false))
}
