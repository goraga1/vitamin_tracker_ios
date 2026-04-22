import Foundation

/// Combines results from the three search sources into a single, deduplicated
/// list. Dedup key is `brand + " " + name` lowercased; ties go to the source
/// with higher priority (bundled > swiftDataCache > dsldLive).
struct SearchResultMerger: Sendable {
    /// First pass: merge local (bundled) matches with SwiftData cache hits.
    /// Called synchronously as soon as both local sources return.
    func merge(local: [IndexedMatch], cached: [SearchResult]) -> [SearchResult] {
        let bundledResults = local.map(SearchResultFactory.fromBundled)
        return mergeOrdered(primary: bundledResults, secondary: cached)
    }

    /// Second pass: fold live DSLD results into the list we already showed
    /// the user. Existing results win on ties so the list doesn't reshuffle
    /// when the network reply lands.
    func merge(existing: [SearchResult], remote: [SearchResult]) -> [SearchResult] {
        mergeOrdered(primary: existing, secondary: remote)
    }

    private func mergeOrdered(
        primary: [SearchResult],
        secondary: [SearchResult]
    ) -> [SearchResult] {
        var seen = Set<String>()
        var out: [SearchResult] = []
        out.reserveCapacity(primary.count + secondary.count)

        for result in primary {
            let key = dedupKey(result)
            if seen.insert(key).inserted {
                out.append(result)
            }
        }
        for result in secondary {
            let key = dedupKey(result)
            if seen.insert(key).inserted {
                out.append(result)
            }
        }

        // Stable sort by (sourcePriority, -relevanceScore). Array.sort is
        // stable when the comparator treats equal keys as `<= `.
        out.sort { lhs, rhs in
            if lhs.source.priority != rhs.source.priority {
                return lhs.source.priority < rhs.source.priority
            }
            return lhs.relevanceScore > rhs.relevanceScore
        }

        return out
    }

    private func dedupKey(_ result: SearchResult) -> String {
        "\(result.brand.lowercased()) \(result.name.lowercased())"
    }
}
