import Foundation

/// Online fallback for the hybrid search. Only hits DSLD when bundled +
/// cached results come up short. Reuses the existing `DSLDClient` so the
/// URLCache, retry behavior, and timeout policy are centralized.
///
/// Successful hits are written back into the SwiftData cache so the next
/// search for the same term works offline.
actor DSLDSearchFallback {
    private let client: DSLDClient
    private let timeout: TimeInterval

    init(client: DSLDClient = .shared, timeout: TimeInterval = 8) {
        self.client = client
        self.timeout = timeout
    }

    /// Returns at most `limit` live DSLD results. Fails silently (returns
    /// empty) on cancellation, timeout, or network error.
    func search(_ query: String, limit: Int) async -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return [] }

        do {
            let products = try await withTimeout(timeout) {
                await self.client.search(trimmed)
            }
            try Task.checkCancellation()
            return products
                .prefix(limit)
                .enumerated()
                .map { idx, product in
                    SearchResultFactory.fromDSLDProduct(
                        product,
                        relevance: max(0.0, 1.0 - Double(idx) * 0.05)
                    )
                }
        } catch {
            return []
        }
    }

    private func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        operation: @Sendable @escaping () async -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw SearchTimeout()
            }
            guard let result = try await group.next() else {
                throw SearchTimeout()
            }
            group.cancelAll()
            return result
        }
    }

    private struct SearchTimeout: Error {}
}
