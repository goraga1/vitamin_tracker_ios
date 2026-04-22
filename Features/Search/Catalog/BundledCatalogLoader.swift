import Foundation

/// Loads the bundled `catalog_v1.json` into memory and hands the decoded
/// product list to the search index. Decoding runs on a background task so
/// we don't block the main actor during cold launch.
///
/// Callers should invoke `load()` once during app startup. Subsequent calls
/// are cheap no-ops.
actor BundledCatalogLoader {
    static let shared = BundledCatalogLoader()

    private(set) var products: [CatalogProduct] = []
    private(set) var isLoaded: Bool = false
    private(set) var lastError: Error?

    /// File name (without extension) of the catalog JSON in the main bundle.
    private let resourceName = "catalog_v1"
    private let resourceExtension = "json"

    private var loadTask: Task<Void, Never>?

    init() {}

    /// Starts loading the bundled catalog. Safe to call repeatedly — only the
    /// first call performs work; the rest await the in-flight task.
    func load() async {
        if isLoaded { return }
        if let task = loadTask {
            await task.value
            return
        }
        loadTask = Task { [weak self] in
            await self?.performLoad()
        }
        await loadTask?.value
    }

    private func performLoad() async {
        do {
            guard let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: resourceExtension
            ) else {
                // Missing catalog is a soft failure — search still works via
                // SwiftData cache + DSLD fallback. Log so CI catches it.
                print("[BundledCatalogLoader] catalog_v1.json not in bundle — bundled search disabled")
                isLoaded = true
                return
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let file = try JSONDecoder().decode(CatalogFile.self, from: data)
            products = file.products
            isLoaded = true
            print("[BundledCatalogLoader] loaded \(products.count) products (v\(file.version))")
        } catch {
            lastError = error
            isLoaded = true  // avoid retry loops — fall back to other sources
            print("[BundledCatalogLoader] load failed: \(error)")
        }
    }
}
