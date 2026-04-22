import SwiftUI
import SwiftData

/// Top-level hybrid-search screen. Renders three states:
///
///   - **Empty query**: popular suggestions pulled from the bundled catalog.
///   - **Searching**: progress indicator until first results arrive.
///   - **Populated**: list of `SearchResultRow` plus the manual-entry CTA.
///
/// Owns a `CatalogSearcher` coordinator created against the current
/// `ModelContext`. All typing events flow through the coordinator's
/// `search(_:)` method, which handles cancellation and debouncing itself.
struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var searcher: CatalogSearcher?

    @FocusState private var isFocused: Bool

    var onSelect: (SearchResult) -> Void
    var onManualAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            contentBody
        }
        .background(AppColor.bg.ignoresSafeArea())
        .onAppear {
            if searcher == nil {
                searcher = CatalogSearcher(modelContext: context)
            }
            isFocused = true
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColor.ink3)
                TextField("Search supplements", text: $query)
                    .font(AppFont.sans(14))
                    .foregroundStyle(AppColor.ink)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
                    .onChange(of: query) { _, newValue in
                        searcher?.search(newValue)
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Capsule().fill(AppColor.surface))
            .overlay(Capsule().strokeBorder(AppColor.border, lineWidth: 1))

            Button("Cancel") { dismiss() }
                .font(AppFont.sans(14))
                .foregroundStyle(AppColor.ink3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var contentBody: some View {
        if let searcher {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    popularState(searcher: searcher)
                } else if searcher.isSearching && searcher.results.isEmpty {
                    loadingState
                } else if searcher.results.isEmpty {
                    emptyResultsState(searcher: searcher)
                } else {
                    resultsList(searcher: searcher)
                }
            }
            .animation(.default, value: searcher.isSearching)
        } else {
            Spacer()
        }
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(AppColor.ink2)
            Spacer()
        }
    }

    private func popularState(searcher: CatalogSearcher) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                LabelText("Popular")
                    .padding(.top, 4)
                    .padding(.horizontal, 20)

                if searcher.popularSuggestions.isEmpty {
                    BodyText(
                        "Start typing to search supplements by brand or name.",
                        size: 13,
                        color: AppColor.ink3
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                } else {
                    ForEach(searcher.popularSuggestions) { result in
                        Button { onSelect(result) } label: {
                            SearchResultRow(result: result)
                        }
                        .buttonStyle(PressScaleStyle())
                        .padding(.horizontal, 20)
                    }
                }

                ManualAddCTA(message: "Don't see yours?", onTap: onManualAdd)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func emptyResultsState(searcher: CatalogSearcher) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(AppColor.ink3)
                BodyText("No matches", size: 14, weight: .semibold, color: AppColor.ink)
                BodyText(
                    searcher.hasSearchedRemote
                        ? "Nothing in our catalog or DSLD."
                        : offlineCopy,
                    size: 13,
                    color: AppColor.ink3
                )
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            ManualAddCTA(onTap: onManualAdd)
                .padding(.horizontal, 20)
            Spacer()
        }
    }

    private var offlineCopy: String {
        NetworkMonitor.shared.isOnline
            ? "Try a different spelling."
            : "Connect to the internet for more results."
    }

    private func resultsList(searcher: CatalogSearcher) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(searcher.results) { result in
                    Button { onSelect(result) } label: {
                        SearchResultRow(result: result)
                    }
                    .buttonStyle(PressScaleStyle())
                }

                if searcher.isSearching && searcher.hasSearchedRemote == false {
                    HStack(spacing: 8) {
                        ProgressView().tint(AppColor.ink3)
                        BodyText("Checking DSLD…", size: 12, color: AppColor.ink3)
                    }
                    .padding(.vertical, 8)
                }

                ManualAddCTA(onTap: onManualAdd)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}
