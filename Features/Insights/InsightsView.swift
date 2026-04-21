import SwiftUI

enum InsightsRange: String, CaseIterable, Identifiable {
    case today, week, month
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Nutrient dashboard — bars for each nutrient vs RDA, plus interactions
/// warning. Port of `InsightsScreen`. Behind a paywall by default.
struct InsightsView: View {
    @State private var range: InsightsRange = .week
    @State private var showPaywall = false

    /// Set to false to view the unlocked variant (useful after RevenueCat
    /// integration lands).
    var locked: Bool = true

    private struct Nutrient {
        let name: String
        let value: Int       // percent of RDA
        let total: String    // "125 µg / day"
        let color: Color
    }

    private let nutrients: [Nutrient] = [
        .init(name: "Vitamin D",          value: 94,  total: "125 µg / day",   color: AppColor.sage),
        .init(name: "Omega-3 (EPA+DHA)",  value: 70,  total: "1,100 mg / day", color: AppColor.sage),
        .init(name: "Vitamin C",          value: 112, total: "1,120 mg / day", color: AppColor.amber),
        .init(name: "Iron",               value: 58,  total: "10 mg / day",    color: AppColor.sage),
        .init(name: "Magnesium",          value: 82,  total: "240 mg / day",   color: AppColor.sage),
        .init(name: "Zinc",               value: 145, total: "32 mg / day",    color: AppColor.coral),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        LabelText("Insights")
                        SerifText("Your nutrients", size: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    rangePicker
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    ScrollView {
                        ZStack {
                            content
                                .blur(radius: locked ? 4 : 0)
                                .allowsHitTesting(!locked)

                            if locked {
                                lockCard
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(onClose: { showPaywall = false })
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(InsightsRange.allCases) { r in
                Button { withAnimation(.easeOut(duration: 0.15)) { range = r } } label: {
                    Text(r.title)
                        .font(AppFont.sans(13, weight: .medium))
                        .foregroundStyle(range == r ? AppColor.ink : AppColor.ink3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            Capsule()
                                .fill(range == r ? AppColor.surface : .clear)
                                .shadow(color: range == r ? AppColor.ink.opacity(0.06) : .clear,
                                        radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(AppColor.surface2))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 12) {
                ForEach(nutrients, id: \.name) { n in
                    nutrientRow(n)
                }
            }

            LabelText("Interactions")
                .padding(.top, 22)
                .padding(.leading, 2)

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(AppColor.amber)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("i")
                            .font(AppFont.serif(18, italic: true))
                            .foregroundStyle(.white)
                    )
                BodyText(
                    "Iron + calcium may reduce absorption when taken together. Try spacing 2 hours apart.",
                    size: 14,
                    color: AppColor.amberInk
                )
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(AppColor.amberSoft)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 140)
    }

    private func nutrientRow(_ n: Nutrient) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text(n.name)
                    .font(AppFont.sans(14, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                Spacer()
                BodyText(n.total, size: 12, color: AppColor.ink3)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.surface3)
                    Capsule()
                        .fill(n.color)
                        .frame(width: geo.size.width * min(1, CGFloat(n.value) / 100))
                    // RDA marker line at 100%
                    Rectangle()
                        .fill(AppColor.ink4)
                        .frame(width: 1, height: 10)
                        .offset(x: geo.size.width - 1)
                        .opacity(0.5)
                }
            }
            .frame(height: 6)

            BodyText("\(n.value)% of RDA", size: 12, color: percentColor(n))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(AppColor.border, lineWidth: 1)
        )
    }

    private func percentColor(_ n: Nutrient) -> Color {
        if n.color == AppColor.coral { return AppColor.coralInk }
        if n.color == AppColor.amber { return AppColor.amberInk }
        return AppColor.sageDeep
    }

    private var lockCard: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(AppColor.sageSoft)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.sageDeep)
                )
            SerifText("Nutrient insights", size: 22)
            BodyText("See what you're getting across every bottle — and where you might be over or under.",
                     size: 13, color: AppColor.ink3)
                .multilineTextAlignment(.center)
            PillButton(title: "Unlock", variant: .sage, size: .small) {
                showPaywall = true
            }
            .frame(width: 160)
        }
        .padding(24)
        .frame(maxWidth: 280)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20).strokeBorder(AppColor.border, lineWidth: 1)
        )
        .shadow(color: AppColor.ink.opacity(0.12), radius: 30, x: 0, y: 10)
        .padding(.top, 120)
    }
}

#Preview("Locked")   { InsightsView(locked: true)  }
#Preview("Unlocked") { InsightsView(locked: false) }
