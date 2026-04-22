import SwiftUI

/// One row in the hybrid search list. Small swatch on the left, brand +
/// product name in the middle, optional dose badge on the right, and a
/// "verified" glyph when the source has authoritative data (bundled catalog
/// or live DSLD).
struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            formIcon
            VStack(alignment: .leading, spacing: 2) {
                BodyText(result.brand, size: 12, color: AppColor.ink3)
                HStack(spacing: 6) {
                    BodyText(result.name, size: 14, weight: .semibold, color: AppColor.ink)
                        .lineLimit(2)
                    if showsVerifiedBadge {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColor.sageDeep)
                            .accessibilityLabel("Verified")
                    }
                }
            }
            Spacer(minLength: 8)
            if let dose = primaryDoseBadge {
                doseBadge(dose)
            }
        }
        .padding(12)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppColor.border, lineWidth: 1)
        )
    }

    private var showsVerifiedBadge: Bool {
        switch result.source {
        case .bundled, .dsldLive: true
        case .swiftDataCache: false
        }
    }

    private var formIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColor.surface2)
                .frame(width: 36, height: 44)
            Image(systemName: formSymbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColor.ink2)
        }
    }

    private var formSymbol: String {
        switch result.form {
        case .tablet, .capsule, .softgel: "pills"
        case .gummy: "circle.grid.2x2.fill"
        case .powder: "square.stack.3d.up"
        case .liquid: "drop"
        case .lozenge: "circle.fill"
        case .other: "pill"
        }
    }

    private var primaryDoseBadge: String? {
        guard let first = result.keyIngredients.first else { return nil }
        let amount = formatAmount(first.amount)
        return "\(amount) \(first.unit)"
    }

    private func formatAmount(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func doseBadge(_ text: String) -> some View {
        Text(text)
            .font(AppFont.sans(11, weight: .semibold))
            .foregroundStyle(AppColor.ink2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppColor.surface2))
    }
}
