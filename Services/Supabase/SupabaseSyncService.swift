import Foundation
import SwiftData

#if canImport(Supabase)
import Supabase

/// Двусторонняя синхронизация SwiftData ↔ Supabase Postgres.
///
/// Стратегия: last-write-wins по `updated_at`. Никаких векторных
/// часов, никакого CRDT — данные тривиальные (стек добавок + история
/// приёмов), коллизий между девайсами одного юзера почти не бывает.
///
/// Поток pull:
///   1. читаем локальный курсор `lastPullAt` из UserDefaults
///   2. для каждой таблицы запрашиваем `updated_at > lastPullAt`
///   3. для каждой строки:
///        - если deleted_at != nil → удаляем локальную модель
///        - иначе ищем по id, обновляем или создаём
///   4. сохраняем новый курсор = max(updated_at) из ответа
///
/// Поток push:
///   - в этой версии — простой "push everything": все локальные строки,
///     помеченные как .updatedAt > lastPushAt, идут в upsert.
///   - upsert использует unique-PK по `id`. Сервер сам пересчитает
///     `updated_at` через триггер. На клиенте при ошибке (нет интернета)
///     — оставляем lastPushAt как есть, попробуем в следующий sync.
///
/// Этот скелет НЕ обрабатывает: фото в storage, soft-delete на локале
/// (нужно добавить `deletedAt: Date?` на модели), оффлайн-очередь.
/// См. README §"TODO до прод-релиза".
@MainActor
final class SupabaseSyncService {
    static let shared = SupabaseSyncService()

    private var client: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    enum SyncError: Error {
        case notAuthenticated
    }

    /// Disambiguates the first sync of a session. The on-device onboarding
    /// flow seeds local SwiftData (profile, supplements, schedules) BEFORE
    /// the user authenticates. If we always pushed that draft, a returning
    /// user signing into an existing account would have their server
    /// profile overwritten and onboarding "starter" supplements appended
    /// to their real stack. So sign-in needs to know whose data is whose.
    enum BootstrapIntent {
        /// User explicitly chose "Sign in" — discard the local onboarding
        /// draft and hydrate from the server.
        case signIn
        /// User explicitly chose "Create account" — push the local draft
        /// as the new account's initial state.
        case signUp
        /// Apple, magic-link, deep-link confirmations. We can't tell from
        /// the auth event alone whether the user is new or returning, so
        /// `bootstrapAfterSignIn` probes the `profiles` table to decide.
        case unknown
    }

    // ----- курсор -----

    private let lastPullKey = "supabase.lastPullAt"

    private var lastPullAt: Date {
        get { UserDefaults.standard.object(forKey: lastPullKey) as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: lastPullKey) }
    }

    /// Сбросить курсор — следующий sync притянет ВСЁ. Использовать
    /// при логине нового юзера на этом девайсе.
    func resetCursor() {
        UserDefaults.standard.removeObject(forKey: lastPullKey)
    }

    // ----- bootstrap marker -----
    // Per-user flag, set only when a `bootstrapAfterSignIn` actually
    // reached its end. Lets us detect "signed in but the first sync
    // never finished" — the failure mode behind users seeing stale
    // onboarding data after reinstall + sign-in.
    private static let bootstrapCompletedPrefix = "supabase.bootstrapCompleted."

    private static func bootstrapKey(for userId: UUID) -> String {
        bootstrapCompletedPrefix + userId.uuidString
    }

    func bootstrapCompleted(for userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: Self.bootstrapKey(for: userId))
    }

    private func markBootstrapCompleted(for userId: UUID) {
        UserDefaults.standard.set(true, forKey: Self.bootstrapKey(for: userId))
    }

    private func clearBootstrapMarker(for userId: UUID) {
        UserDefaults.standard.removeObject(forKey: Self.bootstrapKey(for: userId))
    }

    // ----- public entrypoints -----

    /// Полная синхронизация: сначала push (чтобы локальные изменения
    /// добрались до сервера и получили updated_at), потом pull
    /// (включая то, что только что запушили — это даст серверный
    /// updated_at и подвинет курсор).
    func syncNow(in context: ModelContext) async throws {
        guard let userId = SupabaseService.shared.currentUserID else {
            throw SyncError.notAuthenticated
        }
        try await pushAll(userId: userId, context: context)
        try await pullAll(userId: userId, context: context)
    }

    /// First sync after a Supabase sign-in. Picks between two starting
    /// points based on `intent`:
    ///
    ///   - **Returning user** (`.signIn`, or `.unknown` with a server
    ///     profile already present): the local SwiftData was seeded by the
    ///     onboarding flow on a fresh install. That draft does NOT belong
    ///     to the account being signed into — pushing it would clobber the
    ///     real profile (upsert by `user_id`) and graft "starter"
    ///     supplements onto the user's stack. We wipe the local user-data
    ///     tables, reset the pull cursor, and hydrate from the server.
    ///   - **New user** (`.signUp`, or `.unknown` with no server profile):
    ///     the local draft IS this account's initial state. Run the same
    ///     push-then-pull as `syncNow`.
    ///
    /// Either way the local profile ends up with `onboardingCompleted = true`
    /// so the user lands in the app rather than being bounced back to the
    /// onboarding flow.
    func bootstrapAfterSignIn(intent: BootstrapIntent, in context: ModelContext) async throws {
        guard let userId = SupabaseService.shared.currentUserID else {
            throw SyncError.notAuthenticated
        }

        // Drop any prior marker — if we throw partway through, the next
        // `ensureBootstrapped` retry will see "not done" and pick up
        // again instead of trusting half-applied state.
        clearBootstrapMarker(for: userId)

        let isReturningUser: Bool
        switch intent {
        case .signIn:  isReturningUser = true
        case .signUp:  isReturningUser = false
        case .unknown: isReturningUser = try await remoteProfileExists(userId: userId)
        }

        if isReturningUser {
            try wipeLocalUserData(in: context)
            resetCursor()
            try await pullAll(userId: userId, context: context)
            try ensureOnboardedProfileExists(in: context)
        } else {
            try await pushAll(userId: userId, context: context)
            try await pullAll(userId: userId, context: context)
        }

        markBootstrapCompleted(for: userId)
    }

    /// Recovery hook for cases where `bootstrapAfterSignIn` never finished
    /// (network failure, app killed mid-sync, the silent `try?` we used
    /// to wrap it, …). Call from `RootGate` on every signed-in launch:
    /// idempotent — does nothing if a successful bootstrap is on record
    /// for the current user. Otherwise runs `bootstrapAfterSignIn` with
    /// `.unknown` so the sync layer probes the server to decide whether
    /// to wipe-and-pull or push-and-pull, just like an Apple sign-in.
    ///
    /// Without this, a user who hits a transient error during the first
    /// sync gets dropped into the app with the local onboarding draft
    /// still in place and no retry path short of reinstalling.
    func ensureBootstrapped(in context: ModelContext) async throws {
        guard let userId = SupabaseService.shared.currentUserID else {
            throw SyncError.notAuthenticated
        }
        if bootstrapCompleted(for: userId) { return }
        try await bootstrapAfterSignIn(intent: .unknown, in: context)
    }

    private func remoteProfileExists(userId: UUID) async throws -> Bool {
        let rows: [ProfileDTO] = try await client.database
            .from("profiles")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.contains { $0.deletedAt == nil }
    }

    /// Drop every user-owned local model in dependency order (children
    /// first). Catalog data (`SupplementCatalog`) is the cached search
    /// index — not user data — and stays put.
    ///
    /// `UserProfile` is intentionally kept and reset in place rather than
    /// deleted: `RootGate` observes it via `@Query`, and a nil profile
    /// even briefly (during the await on `pullAll`) flips the gate to
    /// `OnboardingFlow`, bouncing the just-authenticated user out of the
    /// sign-in flow. `pullProfiles` overwrites the row's fields with
    /// server data, and `ensureOnboardedProfileExists` keeps
    /// `onboardingCompleted = true` set in case the server has no row.
    private func wipeLocalUserData(in context: ModelContext) throws {
        for marker in (try? context.fetch(FetchDescriptor<MarkerReading>())) ?? [] {
            context.delete(marker)
        }
        for test in (try? context.fetch(FetchDescriptor<LabTest>())) ?? [] {
            context.delete(test)
        }
        for log in (try? context.fetch(FetchDescriptor<IntakeLog>())) ?? [] {
            context.delete(log)
        }
        for schedule in (try? context.fetch(FetchDescriptor<Schedule>())) ?? [] {
            context.delete(schedule)
        }
        for ingredient in (try? context.fetch(FetchDescriptor<Ingredient>())) ?? [] {
            context.delete(ingredient)
        }
        for supplement in (try? context.fetch(FetchDescriptor<Supplement>())) ?? [] {
            context.delete(supplement)
        }
        // Reset the previous user's identity off the kept profile so it
        // doesn't briefly render with the wrong email/name before the
        // pull lands.
        if let profile = try context.fetch(FetchDescriptor<UserProfile>()).first {
            profile.authProvider = nil
            profile.appleUserID = nil
            profile.email = nil
            profile.displayName = ""
            profile.onboardingCompleted = true
        }
        try context.save()
    }

    /// Guarantees the local store has at least one onboarded profile after
    /// a returning-user bootstrap. Covers two edges: the pull failed
    /// mid-flight and left no profile behind, or the server profile is a
    /// legacy row with `onboardingCompleted=false`. In either case we'd
    /// rather force-mark complete than bounce the just-authenticated user
    /// back into onboarding (their draft has already been discarded).
    private func ensureOnboardedProfileExists(in context: ModelContext) throws {
        if let p = try context.fetch(FetchDescriptor<UserProfile>()).first {
            if !p.onboardingCompleted { p.onboardingCompleted = true }
        } else {
            let p = UserProfile()
            p.onboardingCompleted = true
            context.insert(p)
        }
        try context.save()
    }

    // ----- pull -----

    private func pullAll(userId: UUID, context: ModelContext) async throws {
        let cursor = lastPullAt
        var newCursor = cursor

        // ⚠️ Порядок важен: parents до children, иначе при apply
        // ребёнка не найдётся parent для resolve.

        try await pullProfiles(userId: userId, after: cursor, context: context, cursor: &newCursor)
        try await pullSupplements(userId: userId, after: cursor, context: context, cursor: &newCursor)
        try await pullIngredients(userId: userId, after: cursor, context: context, cursor: &newCursor)
        try await pullSchedules(userId: userId, after: cursor, context: context, cursor: &newCursor)
        try await pullIntakeLogs(userId: userId, after: cursor, context: context, cursor: &newCursor)
        try await pullLabTests(userId: userId, after: cursor, context: context, cursor: &newCursor)
        try await pullMarkerReadings(userId: userId, after: cursor, context: context, cursor: &newCursor)

        try context.save()
        lastPullAt = newCursor
    }

    private func pullProfiles(userId: UUID, after: Date, context: ModelContext,
                              cursor: inout Date) async throws {
        let rows: [ProfileDTO] = try await client.database
            .from("profiles")
            .select()
            .eq("user_id", value: userId)
            .gt("updated_at", value: after)
            .execute()
            .value

        for dto in rows {
            cursor = max(cursor, dto.updatedAt ?? cursor)

            let descriptor = FetchDescriptor<UserProfile>()
            let existing = try context.fetch(descriptor).first

            if dto.deletedAt != nil {
                if let existing { context.delete(existing) }
                continue
            }

            if let existing {
                dto.apply(to: existing)
            } else {
                let p = UserProfile()
                dto.apply(to: p)
                context.insert(p)
            }
        }
    }

    private func pullSupplements(userId: UUID, after: Date, context: ModelContext,
                                 cursor: inout Date) async throws {
        let rows: [SupplementDTO] = try await client.database
            .from("supplements")
            .select()
            .eq("user_id", value: userId)
            .gt("updated_at", value: after)
            .execute()
            .value

        for dto in rows {
            cursor = max(cursor, dto.updatedAt ?? cursor)
            let id = dto.id
            let existing = try context.fetch(
                FetchDescriptor<Supplement>(predicate: #Predicate { $0.id == id })
            ).first

            if dto.deletedAt != nil {
                if let existing { context.delete(existing) }
                continue
            }

            if let existing {
                dto.apply(to: existing)
            } else {
                context.insert(dto.makeModel())
            }
        }
    }

    private func pullIngredients(userId: UUID, after: Date, context: ModelContext,
                                 cursor: inout Date) async throws {
        let rows: [IngredientDTO] = try await client.database
            .from("ingredients")
            .select()
            .eq("user_id", value: userId)
            .gt("updated_at", value: after)
            .execute()
            .value

        for dto in rows {
            cursor = max(cursor, dto.updatedAt ?? cursor)
            let id = dto.id
            let existing = try context.fetch(
                FetchDescriptor<Ingredient>(predicate: #Predicate { $0.id == id })
            ).first

            if dto.deletedAt != nil {
                if let existing { context.delete(existing) }
                continue
            }

            if let existing {
                dto.apply(to: existing)
            } else {
                let model = dto.makeModel()
                let parentId = dto.supplementId
                if let parent = try context.fetch(
                    FetchDescriptor<Supplement>(predicate: #Predicate { $0.id == parentId })
                ).first {
                    parent.ingredients.append(model)
                }
                context.insert(model)
            }
        }
    }

    private func pullSchedules(userId: UUID, after: Date, context: ModelContext,
                               cursor: inout Date) async throws {
        let rows: [ScheduleDTO] = try await client.database
            .from("schedules")
            .select()
            .eq("user_id", value: userId)
            .gt("updated_at", value: after)
            .execute()
            .value

        for dto in rows {
            cursor = max(cursor, dto.updatedAt ?? cursor)
            let id = dto.id
            let existing = try context.fetch(
                FetchDescriptor<Schedule>(predicate: #Predicate { $0.id == id })
            ).first

            if dto.deletedAt != nil {
                if let existing { context.delete(existing) }
                continue
            }

            if let existing {
                dto.apply(to: existing)
            } else {
                let model = dto.makeModel()
                let parentId = dto.supplementId
                if let parent = try context.fetch(
                    FetchDescriptor<Supplement>(predicate: #Predicate { $0.id == parentId })
                ).first {
                    parent.schedules.append(model)
                }
                context.insert(model)
            }
        }
    }

    private func pullIntakeLogs(userId: UUID, after: Date, context: ModelContext,
                                cursor: inout Date) async throws {
        let rows: [IntakeLogDTO] = try await client.database
            .from("intake_logs")
            .select()
            .eq("user_id", value: userId)
            .gt("updated_at", value: after)
            .execute()
            .value

        for dto in rows {
            cursor = max(cursor, dto.updatedAt ?? cursor)
            let id = dto.id
            let existing = try context.fetch(
                FetchDescriptor<IntakeLog>(predicate: #Predicate { $0.id == id })
            ).first

            let resolveSupplement: (UUID) -> Supplement? = { sid in
                try? context.fetch(
                    FetchDescriptor<Supplement>(predicate: #Predicate { $0.id == sid })
                ).first
            }
            let resolveSchedule: (UUID) -> Schedule? = { scid in
                try? context.fetch(
                    FetchDescriptor<Schedule>(predicate: #Predicate { $0.id == scid })
                ).first
            }

            if dto.deletedAt != nil {
                if let existing { context.delete(existing) }
                continue
            }

            if let existing {
                dto.apply(to: existing,
                          resolveSupplement: resolveSupplement,
                          resolveSchedule:   resolveSchedule)
            } else {
                let model = dto.makeModel(
                    resolveSupplement: resolveSupplement,
                    resolveSchedule:   resolveSchedule
                )
                context.insert(model)
            }
        }
    }

    private func pullLabTests(userId: UUID, after: Date, context: ModelContext,
                              cursor: inout Date) async throws {
        let rows: [LabTestDTO] = try await client.database
            .from("lab_tests")
            .select()
            .eq("user_id", value: userId)
            .gt("updated_at", value: after)
            .execute()
            .value

        for dto in rows {
            cursor = max(cursor, dto.updatedAt ?? cursor)
            let id = dto.id
            let existing = try context.fetch(
                FetchDescriptor<LabTest>(predicate: #Predicate { $0.id == id })
            ).first

            if dto.deletedAt != nil {
                if let existing { context.delete(existing) }
                continue
            }

            if let existing {
                dto.apply(to: existing)
            } else {
                context.insert(dto.makeModel())
            }
        }
    }

    private func pullMarkerReadings(userId: UUID, after: Date, context: ModelContext,
                                    cursor: inout Date) async throws {
        let rows: [MarkerReadingDTO] = try await client.database
            .from("marker_readings")
            .select()
            .eq("user_id", value: userId)
            .gt("updated_at", value: after)
            .execute()
            .value

        for dto in rows {
            cursor = max(cursor, dto.updatedAt ?? cursor)
            let id = dto.id
            let existing = try context.fetch(
                FetchDescriptor<MarkerReading>(predicate: #Predicate { $0.id == id })
            ).first

            if dto.deletedAt != nil {
                if let existing { context.delete(existing) }
                continue
            }

            if let existing {
                dto.apply(to: existing)
            } else {
                let model = dto.makeModel()
                let parentId = dto.testId
                if let parent = try context.fetch(
                    FetchDescriptor<LabTest>(predicate: #Predicate { $0.id == parentId })
                ).first {
                    parent.readings.append(model)
                }
                context.insert(model)
            }
        }
    }

    // ----- push -----

    /// Простейший вариант: пушим ВСЁ, что есть локально. Идемпотентно
    /// по PK через upsert, поэтому повторные запуски безопасны.
    /// Когда трафик разрастётся — заменим на pending-queue.
    private func pushAll(userId: UUID, context: ModelContext) async throws {
        // profiles — один на юзера
        if let profile = try context.fetch(FetchDescriptor<UserProfile>()).first {
            let dto = ProfileDTO(model: profile, userId: userId)
            try await client.database
                .from("profiles")
                .upsert(dto, onConflict: "user_id")
                .execute()
        }

        let supplements = try context.fetch(FetchDescriptor<Supplement>())
        if !supplements.isEmpty {
            let dtos = supplements.map { SupplementDTO(model: $0, userId: userId) }
            try await client.database
                .from("supplements")
                .upsert(dtos, onConflict: "id")
                .execute()
        }

        // ingredients и schedules идут в общем цикле по supplements,
        // чтобы знать parent.id
        var ingredients: [IngredientDTO] = []
        var schedules: [ScheduleDTO] = []
        for s in supplements {
            ingredients.append(contentsOf: s.ingredients.map {
                IngredientDTO(model: $0, supplementId: s.id, userId: userId)
            })
            schedules.append(contentsOf: s.schedules.map {
                ScheduleDTO(model: $0, supplementId: s.id, userId: userId)
            })
        }
        if !ingredients.isEmpty {
            try await client.database
                .from("ingredients")
                .upsert(ingredients, onConflict: "id")
                .execute()
        }
        if !schedules.isEmpty {
            try await client.database
                .from("schedules")
                .upsert(schedules, onConflict: "id")
                .execute()
        }

        let logs = try context.fetch(FetchDescriptor<IntakeLog>())
        if !logs.isEmpty {
            let dtos = logs.map { IntakeLogDTO(model: $0, userId: userId) }
            try await client.database
                .from("intake_logs")
                .upsert(dtos, onConflict: "id")
                .execute()
        }

        let tests = try context.fetch(FetchDescriptor<LabTest>())
        if !tests.isEmpty {
            let dtos = tests.map { LabTestDTO(model: $0, userId: userId) }
            try await client.database
                .from("lab_tests")
                .upsert(dtos, onConflict: "id")
                .execute()
        }

        var markers: [MarkerReadingDTO] = []
        for t in tests {
            markers.append(contentsOf: t.readings.map {
                MarkerReadingDTO(model: $0, testId: t.id, userId: userId)
            })
        }
        if !markers.isEmpty {
            try await client.database
                .from("marker_readings")
                .upsert(markers, onConflict: "id")
                .execute()
        }
    }

    // ----- delete account -----

    /// Стирает данные на сервере + локально + сбрасывает курсор.
    /// Удаление самого `auth.users` строки требует service-role
    /// ключа → делается через Edge Function (см. README).
    func deleteAccountData(in context: ModelContext) async throws {
        let userId = SupabaseService.shared.currentUserID
        try await client.database.rpc("delete_account_data").execute()
        try await SupabaseAuthService.shared.signOut()
        resetCursor()
        if let userId { clearBootstrapMarker(for: userId) }
        // локальная очистка — отдельно, чтобы пользователь решил
        // оставлять ли данные локально
    }
}

#else

// ---- stub до подключения SPM-пакета supabase-swift ----
@MainActor
final class SupabaseSyncService {
    static let shared = SupabaseSyncService()

    private init() {}

    enum SyncError: Error {
        case notAuthenticated
        case notConfigured
    }

    enum BootstrapIntent {
        case signIn
        case signUp
        case unknown
    }

    func resetCursor() {}

    func syncNow(in context: ModelContext) async throws {
        throw SyncError.notConfigured
    }

    func bootstrapAfterSignIn(intent: BootstrapIntent, in context: ModelContext) async throws {
        throw SyncError.notConfigured
    }

    func ensureBootstrapped(in context: ModelContext) async throws {
        throw SyncError.notConfigured
    }

    func deleteAccountData(in context: ModelContext) async throws {
        throw SyncError.notConfigured
    }
}

#endif
