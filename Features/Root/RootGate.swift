import SwiftUI
import SwiftData

/// Top-level routing.
///
/// Three states, evaluated in order:
///   1. No profile / `onboardingCompleted == false` → `OnboardingFlow`.
///   2. Onboarded but Supabase reports no session → `SignInView` as a
///      full-screen orphan-repair gate. This catches users who slipped
///      past the onboarding sign-in via a now-removed silent fallback,
///      and users who signed out from `ProfileView` and need to
///      re-authenticate before touching the app.
///   3. Onboarded + signed in → `RootView`.
///
/// Profiles are sorted by `memberSince` ascending so `.first` is always
/// the oldest row — deterministic if a stale duplicate ever sneaks in.
struct RootGate: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.memberSince) private var profiles: [UserProfile]
    @State private var isSignedInToSupabase = SupabaseAuthService.shared.isSignedIn
    @State private var authObserver: Task<Void, Never>?

    var body: some View {
        Group {
            if let profile = profiles.first, profile.onboardingCompleted {
                if isSignedInToSupabase {
                    RootView()
                        .transition(.opacity)
                } else {
                    SignInView(onComplete: {
                        // Observer below also flips the flag from the
                        // Supabase auth-state change, but doing it here
                        // too avoids a one-frame flicker on the
                        // immediate-session paths (Apple, email login).
                        isSignedInToSupabase = true
                    })
                    .transition(.opacity)
                }
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: profiles.first?.onboardingCompleted)
        .animation(.easeInOut(duration: 0.25), value: isSignedInToSupabase)
        .task {
            authObserver?.cancel()
            authObserver = SupabaseAuthService.shared.observeIsSignedIn { signedIn in
                isSignedInToSupabase = signedIn
            }
        }
        // Recovery hook for an interrupted first sync. If the user signed
        // in last session but `bootstrapAfterSignIn` never reached its
        // success marker (network failure, app killed mid-sync, the older
        // silent `try?` wrapper), `ensureBootstrapped` re-runs the
        // wipe/push/pull so the local store matches the server. No-op
        // when the marker is set or the user isn't signed in.
        .task(id: isSignedInToSupabase) {
            guard isSignedInToSupabase else { return }
            try? await SupabaseSyncService.shared.ensureBootstrapped(in: context)
        }
        .onDisappear {
            authObserver?.cancel()
            authObserver = nil
        }
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
