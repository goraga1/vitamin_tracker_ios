import SwiftUI

/// A6 — list of supplements extracted from photos. Visual only; the real
/// flow edits `Supplement` rows via sheet. Port of `A6Confirm`.
struct A6Confirm: View {
    var onNext: () -> Void = {}

    private struct Item {
        let name: String, brand: String, dose: String, tint: UInt32, accent: UInt32
    }
    // Matches MockData rows 0–4.
    private let items: [Item] = [
        .init(name: "Vitamin D3",          brand: "Thorne",            dose: "5,000 IU", tint: 0xF3E5C6, accent: 0xC49A48),
        .init(name: "Omega-3",             brand: "Nordic Naturals",   dose: "1,280 mg", tint: 0xE5EDD9, accent: 0x7C9658),
        .init(name: "Magnesium Glycinate", brand: "Pure Encapsulations", dose: "240 mg", tint: 0xE2E6EE, accent: 0x6F7C96),
        .init(name: "Women's Multi",       brand: "Ritual",            dose: "2 caps",   tint: 0xF8E4E0, accent: 0xC07A6B),
        .init(name: "Zinc Picolinate",     brand: "Solgar",            dose: "22 mg",    tint: 0xE7E0D2, accent: 0xA08753),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 8) {
                ComposedSerif(leading: "We found ",
                              italic: "\(items.count) supplements",
                              size: 32,
                              italicColor: AppColor.ink)
                BodyText("Tap any row to edit the name, brand, or dose.",
                         size: 14, color: AppColor.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        row(it)
                    }

                    Button {} label: {
                        HStack(spacing: 6) {
                            Text("+").font(.system(size: 16))
                            Text("Add manually").font(AppFont.sans(14))
                        }
                        .foregroundStyle(AppColor.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .foregroundStyle(AppColor.border)
                        )
                    }
                    .buttonStyle(PressScaleStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)

            PillButton(title: "Continue", variant: .primary, action: onNext)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
    }

    private var header: some View {
        HStack {
            Button {} label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.ink)
                    .frame(width: 36, height: 36)
            }
            Spacer()
            LabelText("Step 3 of 4")
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func row(_ it: Item) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: it.tint))
                .frame(width: 52, height: 62)
                .overlay(
                    BottleView(
                        tint: Color(hex: it.tint),
                        accent: Color(hex: it.accent),
                        label: String(it.name.prefix(2)),
                        size: 38
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(it.name)
                    .font(AppFont.sans(16, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                BodyText("\(it.brand) · \(it.dose)", size: 13, color: AppColor.ink3)
            }

            Spacer(minLength: 0)

            Button {} label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(AppColor.surface))
                    .overlay(Circle().strokeBorder(AppColor.border, lineWidth: 1))
            }
        }
        .padding(12)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(AppColor.border, lineWidth: 1)
        )
    }
}

#Preview { A6Confirm() }
