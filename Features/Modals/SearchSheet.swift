import SwiftUI

/// DSLD search placeholder. Real network calls land with `DSLDClient` in
/// Phase 1b; for now the list is hardcoded. Port of `SearchScreen`.
struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = "magnesium gly"

    private struct Result {
        let name: String, brand: String, tint: UInt32, accent: UInt32
    }
    private let results: [Result] = [
        .init(name: "Magnesium Glycinate", brand: "Pure Encaps",      tint: 0xE2E6EE, accent: 0x6F7C96),
        .init(name: "Magnesium Glycinate", brand: "Thorne",            tint: 0xF3E5C6, accent: 0xC49A48),
        .init(name: "Mag Threonate",       brand: "Life Extension",    tint: 0xE5EDD9, accent: 0x7C9658),
        .init(name: "Magnesium Citrate",   brand: "NOW",               tint: 0xF8E4E0, accent: 0xC07A6B),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColor.ink3)
                    TextField("Search supplements", text: $query)
                        .font(AppFont.sans(14))
                        .foregroundStyle(AppColor.ink)
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(
                    Capsule().fill(AppColor.surface)
                )
                .overlay(Capsule().strokeBorder(AppColor.border, lineWidth: 1))

                Button("Cancel") { dismiss() }
                    .font(AppFont.sans(14))
                    .foregroundStyle(AppColor.ink3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    LabelText("Matches")
                        .padding(.top, 16)

                    ForEach(Array(results.enumerated()), id: \.offset) { _, r in
                        resultRow(r)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppColor.bg.ignoresSafeArea())
    }

    private func resultRow(_ r: Result) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: r.tint))
                .frame(width: 36, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: r.accent))
                        .frame(width: 10, height: 14)
                )

            VStack(alignment: .leading, spacing: 2) {
                BodyText(r.name, size: 14, color: AppColor.ink)
                BodyText(r.brand, size: 12, color: AppColor.ink3)
            }

            Spacer()

            Button {} label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppColor.surface2))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(12)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(AppColor.border, lineWidth: 1)
        )
    }
}

#Preview { SearchSheet() }
