import SwiftUI
import SwiftData
import AuthenticationServices
import CryptoKit
import SafariServices

/// Post-paywall registration. Three layouts:
///   - **hero (AU5)** — Apple-first compact entry. Bottle icon + Apple +
///     "Continue with email". Top-right link routes to sign in.
///   - **signUp (AU1)** — Email + password form, with Apple as the
///     accelerated path above the divider.
///   - **signIn (AU2)** — Returning-user form. Email + password, magic
///     link as fallback, Apple as alternate.
///
/// Auth wiring (HARD GATE — no silent fallbacks):
///   - Apple → Supabase identity-token sign-in. Only on success do we
///     persist the local profile and call `onComplete`. If Supabase
///     fails (offline, not configured, server down) the user sees the
///     error and stays on this screen — entering the app without a
///     real session is not allowed, even after a successful purchase.
///   - Email/password → Supabase signUp/signIn. If Supabase Auth has
///     "Confirm email" enabled, signUp creates the user but does NOT
///     issue a session: we surface the "check your email" notice and
///     keep the sheet open. An auth-state observer auto-completes when
///     the deep-link from the confirmation email establishes a session.
///   - Magic link uses `SupabaseAuthService.sendEmailMagicLink`; same
///     auto-complete path as email-confirmation.
struct SignInView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.memberSince) private var profiles: [UserProfile]

    var onComplete: () -> Void = {}

    @State private var step: Step = .hero
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showGoogleSoon = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    /// Tracks "we created an account but a session isn't established yet —
    /// the user has to confirm their email or click a magic-link". Used
    /// to render a banner instead of leaving the form looking idle, and
    /// to keep the user inside the sheet until the deep-link lands.
    @State private var pendingConfirmationEmail: String?
    @State private var isAppleAuthing = false
    @State private var isEmailAuthing = false
    @State private var isMagicLinkSending = false
    @State private var rawAppleNonce: String?
    @State private var legalLink: LegalLink?
    @State private var authObserver: Task<Void, Never>?
    @FocusState private var focused: Field?

    private static let termsURL   = URL(string: "https://www.vitamintracker.app/terms")!
    private static let privacyURL = URL(string: "https://www.vitamintracker.app/privacy")!

    /// RFC 5321 caps an addr-spec at 254 octets — anything beyond that the
    /// server will reject anyway, so block input client-side.
    private static let maxEmailLength = 254
    /// Supabase signs passwords with bcrypt, which truncates anything past
    /// 72 bytes silently. Capping at the same boundary prevents the
    /// "I typed 80 chars but only the first 72 matter" foot-gun on sign-in.
    private static let maxPasswordLength = 72

    private enum Step { case hero, signUp, signIn }
    private enum Field { case email, password }

    var body: some View {
        ZStack {
            AppColor.bg.ignoresSafeArea()
            content
        }
        .alert("Coming soon",
               isPresented: $showGoogleSoon,
               actions: { Button("OK", role: .cancel) {} },
               message: { Text("Google sign-in arrives in the next release. In the meantime, use Apple or email.") })
        .alert("Sign in failed",
               isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
               ),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(errorMessage ?? "") })
        .alert("Check your email",
               isPresented: Binding(
                    get: { infoMessage != nil },
                    set: { if !$0 { infoMessage = nil } }
               ),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(infoMessage ?? "") })
        .sheet(item: $legalLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        // Auto-complete when a deep-link (email confirmation / magic-link)
        // establishes a real Supabase session while the sheet is open.
        // Apple and immediate-session email handle completion inline, so
        // the observer only fires for the pending-confirmation path —
        // otherwise we'd race the inline path and double-call onComplete.
        .task {
            authObserver?.cancel()
            authObserver = SupabaseAuthService.shared.observeIsSignedIn { signedIn in
                guard signedIn, pendingConfirmationEmail != nil else { return }
                handleDeepLinkSessionEstablished()
            }
        }
        .onDisappear {
            authObserver?.cancel()
            authObserver = nil
        }
    }

    /// Called when the deep-link from the confirmation email establishes
    /// a Supabase session while the user is still on this sheet. The
    /// deep-link path handles both signup-confirm and magic-link-signin,
    /// so we can't tell new vs returning from here — `.unknown` lets the
    /// sync layer probe the server before deciding whether to push the
    /// local onboarding draft or wipe it.
    private func handleDeepLinkSessionEstablished() {
        guard let confirmedEmail = pendingConfirmationEmail else { return }
        pendingConfirmationEmail = nil
        Task {
            // Same hard gate as the in-app sign-in paths: if the first
            // pull fails, sign back out and surface the error rather
            // than letting the user proceed with stale onboarding
            // state. `RootGate.ensureBootstrapped` is the safety net
            // for the next launch if the user dismisses the error.
            do {
                try await SupabaseSyncService.shared.bootstrapAfterSignIn(
                    intent: .unknown, in: context
                )
            } catch {
                try? await SupabaseAuthService.shared.signOut()
                pendingConfirmationEmail = confirmedEmail
                errorMessage = "We couldn't restore your data. Check your connection and try again."
                return
            }
            persistLocalProfile(
                provider: "email",
                userID: confirmedEmail,
                email: confirmedEmail,
                displayName: nil
            )
            onComplete()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .hero:   hero
        case .signUp: signUpForm
        case .signIn: signInForm
        }
    }

    // MARK: - AU5 · Apple-first hero

    private var hero: some View {
        VStack(spacing: 0) {
            switchBar(prompt: "Have an account?", action: "Sign in") {
                go(to: .signIn)
            }

            Spacer(minLength: 0)

            VStack(spacing: 18) {
                bottleBadge
                VStack(spacing: 10) {
                    ComposedSerif(leading: "One last step\n", italic: "Save your stack",
                                  size: 38, italicColor: AppColor.ink)
                        .multilineTextAlignment(.center)
                    BodyText("Create an account to save your stack, sync devices, and keep your streak.",
                             size: 15, color: AppColor.ink3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                appleButton
                providerButton(
                    icon: "envelope",
                    title: "Continue with email",
                    foreground: AppColor.ink,
                    background: AppColor.surface,
                    border: AppColor.border
                ) {
                    Haptics.tap()
                    go(to: .signUp)
                }
            }

            footer
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    private var bottleBadge: some View {
        ZStack {
            Circle()
                .fill(AppColor.surface2)
                .frame(width: 96, height: 96)
            Circle()
                .strokeBorder(AppColor.border, lineWidth: 1)
                .frame(width: 96, height: 96)
            BottleView(tint: AppColor.sageSoft, accent: AppColor.sage,
                       label: "Rx", size: 44)
                .offset(y: -2)
            Circle()
                .fill(AppColor.sage)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
                .offset(x: 34, y: 28)
        }
        .frame(width: 130, height: 130)
    }

    // MARK: - AU1 · Sign Up

    private var signUpForm: some View {
        VStack(spacing: 0) {
            switchBar(prompt: "Have an account?", action: "Sign in") {
                go(to: .signIn)
            }

            VStack(alignment: .leading, spacing: 10) {
                ComposedSerif(leading: "Save your\n", italic: "plan & progress",
                              size: 40, italicColor: AppColor.ink)
                BodyText("Create an account so your stack and streaks sync across devices. Takes about 10 seconds.",
                         size: 14, color: AppColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 22)

            VStack(spacing: 14) {
                appleButton
                orDivider(text: "OR WITH EMAIL")
                emailField
                passwordField(placeholder: "At least 8 characters")
            }

            Spacer(minLength: 12)

            PillButton(
                title: isEmailAuthing ? "Creating…" : "Create account",
                variant: .primary,
                disabled: !canSubmitSignUp || isEmailAuthing
            ) {
                completeWithEmail()
            }
            .padding(.top, 8)

            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
        .padding(.bottom, 28)
    }

    // MARK: - AU2 · Sign In

    private var signInForm: some View {
        VStack(spacing: 0) {
            switchBar(prompt: "New here?", action: "Create account") {
                go(to: .signUp)
            }

            VStack(alignment: .leading, spacing: 10) {
                ComposedSerif(leading: "Welcome\n", italic: "back",
                              size: 40, italicColor: AppColor.ink)
                BodyText("Pick up your stack right where you left off.",
                         size: 14, color: AppColor.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 22)

            VStack(spacing: 14) {
                emailField
                passwordField(placeholder: "Your password")

                HStack {
                    Spacer()
                    Button {
                        sendMagicLink()
                    } label: {
                        Text("Forgot password?")
                            .font(AppFont.sans(13, weight: .medium))
                            .foregroundStyle(AppColor.ink2)
                    }
                    .buttonStyle(PressScaleStyle())
                    .disabled(isMagicLinkSending)
                }
            }

            Spacer(minLength: 16)

            PillButton(
                title: signInButtonTitle,
                variant: .primary,
                disabled: !canSubmitSignIn || isMagicLinkSending || isEmailAuthing
            ) {
                completeWithEmail()
            }

            orDivider(text: "OR")
                .padding(.vertical, 14)

            appleButton

            Button {
                sendMagicLink()
            } label: {
                Text("Email me a sign-in link instead")
                    .font(AppFont.sans(13, weight: .medium))
                    .foregroundStyle(AppColor.ink2)
                    .padding(.top, 12)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(isMagicLinkSending || !isValidEmail(email))

            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
        .padding(.bottom, 28)
    }

    // MARK: - Shared chrome

    private func switchBar(prompt: String, action: String, onTap: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Text(prompt)
                .font(AppFont.sans(13))
                .foregroundStyle(AppColor.ink3)
            Button(action: onTap) {
                Text(action)
                    .font(AppFont.sans(13, weight: .semibold))
                    .foregroundStyle(AppColor.ink)
                    .underline()
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.top, 6)
        .padding(.bottom, 18)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Text("By continuing you agree to our ")
                .font(AppFont.sans(11))
                .foregroundStyle(AppColor.ink4)
            Button {
                legalLink = LegalLink(url: Self.termsURL)
            } label: {
                Text("Terms")
                    .font(AppFont.sans(11, weight: .medium))
                    .foregroundStyle(AppColor.ink2)
                    .underline()
            }
            .buttonStyle(PressScaleStyle())
            Text(" and ")
                .font(AppFont.sans(11))
                .foregroundStyle(AppColor.ink4)
            Button {
                legalLink = LegalLink(url: Self.privacyURL)
            } label: {
                Text("Privacy")
                    .font(AppFont.sans(11, weight: .medium))
                    .foregroundStyle(AppColor.ink2)
                    .underline()
            }
            .buttonStyle(PressScaleStyle())
            Text(".")
                .font(AppFont.sans(11))
                .foregroundStyle(AppColor.ink4)
        }
        .padding(.top, 18)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let raw = randomNonce()
            rawAppleNonce = raw
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(raw)
        } onCompletion: { result in
            handleApple(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(isAppleAuthing)
        .opacity(isAppleAuthing ? 0.6 : 1)
    }

    private func providerButton(
        icon: String,
        title: String,
        foreground: Color,
        background: Color,
        border: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(AppFont.sans(15, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(border, lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle())
    }

    private func orDivider(text: String) -> some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(AppColor.border)
                .frame(height: 1)
            Text(text)
                .font(AppFont.sans(11, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(AppColor.ink4)
            Rectangle()
                .fill(AppColor.border)
                .frame(height: 1)
        }
    }

    // MARK: - Form fields

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabelText("Email")
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppColor.ink3)
                // Wrapped in Group so `.foregroundStyle(AppColor.ink)` applies to
                // the typed text via inheritance instead of the TextField directly,
                // which would otherwise override the prompt's own gray foregroundStyle
                // and let iOS render the placeholder in system tint.
                Group {
                    TextField(
                        "Email address",
                        text: limited($email, max: Self.maxEmailLength),
                        prompt: Text("you@example.com")
                            .foregroundStyle(AppColor.ink4)
                    )
                }
                .focused($focused, equals: .email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .font(AppFont.sans(15))
                .foregroundStyle(AppColor.ink)
                .tint(AppColor.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(AppColor.border, lineWidth: 1)
            )
        }
    }

    private func passwordField(placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabelText("Password")
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppColor.ink3)
                Group {
                    if showPassword {
                        TextField(
                            "Password",
                            text: limited($password, max: Self.maxPasswordLength),
                            prompt: Text(placeholder).foregroundStyle(AppColor.ink4)
                        )
                    } else {
                        SecureField(
                            "Password",
                            text: limited($password, max: Self.maxPasswordLength),
                            prompt: Text(placeholder).foregroundStyle(AppColor.ink4)
                        )
                    }
                }
                .focused($focused, equals: .password)
                .textContentType(step == .signUp ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit {
                    if (step == .signUp && canSubmitSignUp) || (step == .signIn && canSubmitSignIn) {
                        completeWithEmail()
                    }
                }
                .font(AppFont.sans(15))
                .foregroundStyle(AppColor.ink)
                .tint(AppColor.ink)

                Button {
                    showPassword.toggle()
                } label: {
                    Text(showPassword ? "Hide" : "Show")
                        .font(AppFont.sans(13, weight: .medium))
                        .foregroundStyle(AppColor.ink3)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(AppColor.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Submission

    private var canSubmitSignUp: Bool {
        isValidEmail(email) && password.count >= 8
    }

    private var canSubmitSignIn: Bool {
        isValidEmail(email) && !password.isEmpty
    }

    private var signInButtonTitle: String {
        if isEmailAuthing { return "Signing in…" }
        if isMagicLinkSending { return "Sending…" }
        return "Sign in"
    }

    private func go(to next: Step) {
        focused = nil
        Haptics.tap()
        // Carry email forward when prefilling, drop password between modes.
        password = ""
        showPassword = false
        if email.isEmpty { email = profiles.first?.email ?? "" }
        withAnimation(.easeInOut(duration: 0.18)) { step = next }
    }

    private func sendMagicLink() {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard isValidEmail(trimmed) else {
            errorMessage = "Enter a valid email first."
            return
        }
        isMagicLinkSending = true
        Task {
            defer { isMagicLinkSending = false }
            do {
                try await SupabaseAuthService.shared.sendEmailMagicLink(email: trimmed)
                // Hold the email aside so the observer can complete auth
                // automatically when the user taps the link in their inbox
                // (deep-link → handle(url:) → session established).
                pendingConfirmationEmail = trimmed
                infoMessage = "We sent a sign-in link to \(trimmed). Tap it on this device to finish signing in."
            } catch SupabaseAuthService.AuthError.notConfigured {
                errorMessage = "Sign-in is unavailable right now. Please update the app and try again."
            } catch is URLError {
                errorMessage = "Couldn't reach the server. Check your connection and try again."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            // Cancellation surfaces as ASAuthorizationError.canceled — silent.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected Apple credential."
                return
            }
            guard let rawNonce = rawAppleNonce else {
                errorMessage = "Missing Apple nonce. Tap Sign in with Apple again."
                return
            }
            let nameComponents = credential.fullName
            let resolvedName: String? = {
                guard let nameComponents else { return nil }
                let f = PersonNameComponentsFormatter()
                f.style = .default
                let s = f.string(from: nameComponents).trimmingCharacters(in: .whitespaces)
                return s.isEmpty ? nil : s
            }()

            isAppleAuthing = true
            Task {
                defer {
                    isAppleAuthing = false
                    rawAppleNonce = nil
                }

                do {
                    try await SupabaseAuthService.shared.signInWithApple(
                        credential: credential,
                        rawNonce: rawNonce
                    )
                } catch SupabaseAuthService.AuthError.notConfigured {
                    errorMessage = "Sign-in is unavailable right now. Please update the app and try again."
                    return
                } catch is URLError {
                    errorMessage = "Couldn't reach the server. Check your connection and try again."
                    return
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }

                // Bootstrap BEFORE persisting identity so a returning user's
                // local onboarding draft is wiped before we'd otherwise
                // attach Apple identity to it. Apple Sign In is ambiguous
                // (the same flow signs up new users and signs in returning
                // ones), so let the sync layer probe `profiles` to decide.
                //
                // HARD-GATED for the same reason as the email path: a
                // failed pull would otherwise leave a returning user
                // looking at their local onboarding draft instead of
                // their actual stack.
                do {
                    try await SupabaseSyncService.shared.bootstrapAfterSignIn(
                        intent: .unknown, in: context
                    )
                } catch {
                    try? await SupabaseAuthService.shared.signOut()
                    errorMessage = "We couldn't restore your data. Check your connection and try again."
                    return
                }

                // Persist locally only after Supabase confirmed the
                // session. Apple gives `email`/`fullName` only on the
                // very first authorization for this app+user pair — if
                // Supabase failed and we retry, those won't reappear,
                // but Supabase itself records the email from the auth
                // flow, so nothing irrecoverable is lost.
                persistLocalProfile(
                    provider: "apple",
                    userID: credential.user,
                    email: credential.email,
                    displayName: resolvedName
                )
                onComplete()
            }
        }
    }

    /// Email-путь: signUp/signIn в Supabase + локальный профиль.
    ///
    /// Hard gate. Любой исход, при котором Supabase не выдал сессию —
    /// неверный пароль, занятый email, неподтверждённая почта, нет сети,
    /// SDK не подключён — оставляет юзера на этом экране. Локальный
    /// профиль создаётся только после реальной авторизации.
    ///
    /// Исключение — pending email confirmation: signUp создал юзера, но
    /// сессии ещё нет, пока он не кликнет ссылку из письма. Показываем
    /// уведомление, придерживаем email и ждём, пока deep-link
    /// (`handle(url:)` в App) поднимет сессию — тогда observer выше
    /// сам завершит флоу.
    ///
    /// Если позже тот же email придёт через Apple Sign In,
    /// `persistLocalProfile` подвяжет `appleUserID` к существующей
    /// строке (email-merge).
    private func completeWithEmail() {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard isValidEmail(trimmed) else { return }
        let pwd = password
        let isSignUp = (step == .signUp)

        isEmailAuthing = true
        Task {
            defer { isEmailAuthing = false }

            var pendingEmailConfirmation = false
            do {
                if isSignUp {
                    let sessionEstablished = try await SupabaseAuthService.shared.signUpWithEmail(
                        email: trimmed,
                        password: pwd
                    )
                    // "Confirm email" включён → юзер создан, но сессии нет.
                    // Не персистим локально и не зовём onComplete — ждём
                    // тапа по ссылке из письма (auth-observer выше).
                    if !sessionEstablished {
                        pendingEmailConfirmation = true
                    }
                } else {
                    try await SupabaseAuthService.shared.signInWithEmail(
                        email: trimmed,
                        password: pwd
                    )
                }
            } catch SupabaseAuthService.AuthError.notConfigured {
                errorMessage = "Sign-in is unavailable right now. Please update the app and try again."
                return
            } catch is URLError {
                errorMessage = "Couldn't reach the server. Check your connection and try again."
                return
            } catch {
                // Реальная ошибка от сервера: wrong password / email taken /
                // email not confirmed / rate-limited. Показываем как есть.
                errorMessage = error.localizedDescription
                return
            }

            if pendingEmailConfirmation {
                pendingConfirmationEmail = trimmed
                infoMessage = "We sent a confirmation link to \(trimmed). Tap it on this device to finish signing in."
                return
            }

            // Bootstrap before persisting local identity. The form mode
            // tells us unambiguously whether this is a new account or a
            // returning user, so the sync layer can either push the local
            // onboarding draft (sign-up) or wipe it and pull (sign-in).
            //
            // HARD-GATED. Silently swallowing this with `try?` would let
            // a returning user proceed into the app with their local
            // onboarding draft still in place (wrong name, empty stack)
            // because the cloud pull never landed. Sign back out and
            // surface the error so the next attempt re-runs the sync.
            do {
                try await SupabaseSyncService.shared.bootstrapAfterSignIn(
                    intent: isSignUp ? .signUp : .signIn, in: context
                )
            } catch {
                try? await SupabaseAuthService.shared.signOut()
                errorMessage = "We couldn't restore your data. Check your connection and try again."
                return
            }

            persistLocalProfile(
                provider: "email",
                userID: trimmed,
                email: trimmed,
                displayName: nil
            )
            onComplete()
        }
    }

    /// Persists/updates the singleton profile. When Apple-attaches over an
    /// existing email-only profile (same email), we keep the same row so
    /// locally-owned supplements remain attached to the user. RC subscriber
    /// gets re-identified and we restore purchases to ensure entitlement
    /// transfers if the paywall purchase happened on the anonymous RC user.
    private func persistLocalProfile(
        provider: String,
        userID: String,
        email rawEmail: String?,
        displayName: String?
    ) {
        // Reuse the existing profile row whenever there is one. The
        // email→Apple "merge" is implicit: when an email-only profile
        // exists and the user later signs in with Apple, we set
        // `appleUserID` on the same row, preserving locally-owned data.
        //
        // Read the profile via `context.fetch` rather than the `@Query`
        // property because the bootstrap step that runs immediately before
        // this can wipe-and-repopulate `UserProfile` rows. `@Query` only
        // refreshes on the next SwiftUI render pass, so using it here
        // would risk dereferencing a stale (deleted) row.
        let existing: UserProfile? = (try? context.fetch(
            FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.memberSince)])
        ))?.first
        let p = existing ?? UserProfile()

        p.authProvider = provider
        if provider == "apple" { p.appleUserID = userID }
        if let rawEmail, !rawEmail.isEmpty { p.email = rawEmail }
        if let displayName, p.displayName.isEmpty { p.displayName = displayName }
        if existing == nil { context.insert(p) }
        try? context.save()

        // Tie the RC subscriber to our user ID, then re-sync attributes and
        // restore purchases. Restore is the safety net for the
        // anonymous-purchase → identified-login swap: if RC's "transferring
        // purchases" toggle is off in the dashboard, restore re-binds the
        // entitlement to the new app user.
        Task { @MainActor in
            try? await SubscriptionsManager.shared.logIn(appUserID: userID)
            _ = try? await SubscriptionsManager.shared.restore()
            SubscriptionsManager.shared.syncProfileAttributes(p)
        }
    }

    /// Wraps a `String` binding so writes that exceed `max` characters are
    /// truncated atomically. Truncating at the binding's setter (rather than
    /// reacting via `.onChange` after the fact) prevents `SecureField` from
    /// ever holding an over-length value — important on paste, where an
    /// `.onChange` watcher would briefly accept the full pasted string before
    /// writing back the trimmed version.
    private func limited(_ binding: Binding<String>, max: Int) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                let trimmed = newValue.count > max ? String(newValue.prefix(max)) : newValue
                if trimmed != binding.wrappedValue {
                    binding.wrappedValue = trimmed
                }
            }
        )
    }

    private func isValidEmail(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count >= 5, let at = t.firstIndex(of: "@") else { return false }
        let local = t[..<at]
        let domain = t[t.index(after: at)...]
        return !local.isEmpty && domain.contains(".")
    }

    // MARK: - Apple nonce

    /// 32 случайных байта в виде URL-safe base64. Сырой nonce
    /// уходит в Supabase, его SHA256 — в `request.nonce` Apple'а.
    private func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    SignInView()
        .modelContainer(MockData.previewContainer(seedSupplements: false, seedProfile: false))
}

private struct LegalLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .done
        vc.preferredControlTintColor = UIColor(AppColor.ink)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
