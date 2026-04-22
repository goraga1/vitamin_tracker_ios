import Foundation
import Observation
import SwiftData

/// Drives the hybrid search flow: instant bundled + SwiftData results on
/// every keystroke, followed by a debounced DSLD fallback when the local
/// union is thin. The view binds to `results`, `isSearching`,
/// `hasSearchedRemote`, and `popularSuggestions`.
///
/// Design notes:
/// - Each new `search(_:)` cancels the pending task. Debounce for the remote
///   call happens *inside* the task; local results are already on screen by
///   the time we sleep.
/// - All state mutations hop through `@MainActor` so SwiftUI bindings stay
///   on the main actor.
@Observable
@MainActor
final class CatalogSearcher {
    // Dependencies
    private let bundledIndex: LocalCatalogIndex
    private let bundledLoader: BundledCatalogLoader
    private let swiftDataSearcher: SwiftDataCatalogSearcher
    private let dsldFallback: DSLDSearchFallback
    private let merger: SearchResultMerger
    private let network: NetworkMonitor

    // Observable state
    private(set) var results: [SearchResult] = []
    private(set) var isSearching: Bool = false
    private(set) var hasSearchedRemote: Bool = false
    private(set) var popularSuggestions: [SearchResult] = []
    private(set) var lastQuery: String = ""

    private var currentSearchTask: Task<Void, Never>?
    private let remoteThreshold = 5
    private let debounce: Duration = .milliseconds(400)
    private let maxQueryLength = 100

    init(
        modelContext: ModelContext,
        bundledLoader: BundledCatalogLoader = .shared,
        bundledIndex: LocalCatalogIndex = .shared,
        dsldFallback: DSLDSearchFallback = DSLDSearchFallback(),
        merger: SearchResultMerger = SearchResultMerger(),
        network: NetworkMonitor = .shared
    ) {
        self.bundledLoader = bundledLoader
        self.bundledIndex = bundledIndex
        self.swiftDataSearcher = SwiftDataCatalogSearcher(modelContext: modelContext)
        self.dsldFallback = dsldFallback
        self.merger = merger
        self.network = network

        Task { await self.prepareIndex() }
    }

    // MARK: - Lifecycle

    private func prepareIndex() async {
        await bundledLoader.load()
        let products = await bundledLoader.products
        let alreadyBuilt = await bundledIndex.totalProducts() > 0
        if !alreadyBuilt {
            await bundledIndex.build(from: products)
        }
        let popular = await bundledIndex.popularTop(20)
        self.popularSuggestions = popular.map { product in
            let match = IndexedMatch(product: product, score: Double(product.popularity) / 100.0)
            return SearchResultFactory.fromBundled(match)
        }
    }

    // MARK: - Public API

    /// Entry point for every keystroke. Cancels the in-flight task and starts
    /// a new one. Empty queries reset results to popular suggestions.
    func search(_ rawQuery: String) {
        currentSearchTask?.cancel()

        let normalized = normalize(rawQuery)
        lastQuery = normalized

        guard normalized.count >= 2 else {
            results = []
            isSearching = false
            hasSearchedRemote = false
            return
        }

        isSearching = true
        hasSearchedRemote = false

        currentSearchTask = Task { [weak self] in
            await self?.performSearch(normalized)
        }
    }

    private func normalize(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if trimmed.count > maxQueryLength {
            return String(trimmed.prefix(maxQueryLength))
        }
        return trimmed
    }

    private func performSearch(_ query: String) async {
        // Instant local pass — run both local sources in parallel.
        async let local = bundledIndex.search(query, limit: 30)
        let cached = await swiftDataSearcher.search(query, limit: 10)
        let localMatches = await local

        if Task.isCancelled { return }

        let merged = merger.merge(local: localMatches, cached: cached)
        self.results = merged
        self.isSearching = false

        // Decide whether we need the network fallback.
        guard merged.count < remoteThreshold,
              network.isOnline,
              query.count >= 3 else {
            return
        }

        // Debounce the remote call. If the user keeps typing, this task is
        // cancelled and the sleep throws — no wasted network request.
        do {
            try await Task.sleep(for: debounce)
        } catch {
            return
        }
        if Task.isCancelled { return }

        let remote = await dsldFallback.search(query, limit: 10)
        if Task.isCancelled { return }

        self.hasSearchedRemote = true
        guard !remote.isEmpty else { return }
        self.results = merger.merge(existing: self.results, remote: remote)
    }
}

