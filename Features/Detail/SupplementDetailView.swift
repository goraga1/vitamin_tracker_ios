import SwiftUI
import SwiftData

/// Supplement detail — hero, schedule, ingredients, cost, 30-day adherence,
/// notes. Port of `DetailScreen` in `Stack.jsx`.
struct SupplementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let supplement: Supplement

    // 30-day adherence pattern mirrors the prototype sample exactly.
    private let adherence: [Int] = [1,1,0,1,1,1,1, 1,0,1,1,1,1,1, 1,1,1,0,1,1,1, 1,1,1,1,1,1,0, 1,1]

    private var tint: Color { Color(hexString: supplement.tintHex) ?? AppColor.surface2 }
    private var accent: Color { Color(hexString: supplement.accentHex) ?? AppColor.ink3 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                detailBody
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
            }
        }
        .scrollIndicators(.hidden)
        .background(AppColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var hero: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [tint.opacity(0.8), tint],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                HStack {
                    circleButton("chevron.left") { dismiss() }
                    Spacer()
                    HStack(spacing: 8) {
                        circleButton("pencil") {}
                        circleButton("ellipsis") {}
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                BottleView(tint: tint, accent: accent,
                           label: String(supplement.productName.prefix(2)),
                           size: 144)
                    .padding(.top, 10)
            }
        }
        .frame(height: 310)
    }

    private var detailBody: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                LabelText(supplement.brand)
                SerifText(supplement.productName, size: 32)
                    .padding(.top, 4)
                BodyText(doseLine, size: 14, color: AppColor.ink3)
            }

            SectionCard(title: "Schedule") {
                DetailRow(left: "Time of day",
                          right: supplement.schedules.first?.displayLabel ?? "—")
                DetailRow(left: "Frequency", right: "1×/day")
                DetailRow(left: "Reminder", right: reminderTime, isLast: true)
            }

            SectionCard(title: "Ingredients") {
                FlowWrap(spacing: 6) {
                    ForEach(supplement.ingredients) { ing in
                        Chip(
                            text: ingredientDisplayName(ing.nutrientKey),
                            trailingDetail: "\(AmountFormat.trim(ing.amount)) \(ing.unit)",
                            tone: .quiet
                        )
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SectionCard(title: "Cost") {
                VStack(spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCell(label: "Per bottle", value: "$38")
                        StatCell(label: "Days left",  value: "22")
                        StatCell(label: "Per day",    value: "$0.64")
                        StatCell(label: "Last order", value: "Apr 02")
                    }
                    PillButton(title: "Reorder on Amazon", variant: .quiet, size: .small) {}
                }
                .padding(14)
            }

            SectionCard(title: "Adherence · last 30 days") {
                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<adherence.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(adherence[i] == 1 ? AppColor.sage : AppColor.coralSoft)
                                .frame(maxWidth: .infinity)
                                .frame(height: adherence[i] == 1 ? 56 : 56 * 0.35)
                                .opacity(i >= 23 ? 1 : 0.9)
                        }
                    }
                    .frame(height: 56)

                    HStack {
                        BodyText("96% adherence", size: 12, color: AppColor.ink3)
                        Spacer()
                        BodyText("28 of 30 days", size: 12, color: AppColor.ink3)
                    }
                }
                .padding(14)
            }

            SectionCard(title: "Notes") {
                BodyText(
                    supplement.notes ?? "Take with breakfast, fat-soluble.",
                    size: 14,
                    color: AppColor.ink3
                )
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            VStack(spacing: 10) {
                PillButton(title: "Pause for…", variant: .ghost) {}
                Button("Delete supplement") {}
                    .font(AppFont.sans(14))
                    .foregroundStyle(AppColor.coral)
                    .padding(.vertical, 14)
            }
            .padding(.top, 8)
        }
    }

    // ── helpers ──────────────────────────────────────────────────────

    private var doseLine: String {
        let dose = supplement.ingredients.first.map {
            "\(AmountFormat.trim($0.amount)) \($0.unit)"
        } ?? "\(AmountFormat.trim(supplement.servingSize)) \(supplement.servingUnit)"
        return "\(dose) · 1×/day"
    }

    private var reminderTime: String {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        if let t = supplement.schedules.first?.specificTime {
            return df.string(from: t)
        }
        return "8:00 AM"
    }

    private func ingredientDisplayName(_ key: String) -> String {
        switch key {
        case "vitamin_d":    "Vitamin D3"
        case "vitamin_c":    "Vitamin C"
        case "vitamin_b12":  "B12"
        case "epa":          "EPA"
        case "dha":          "DHA"
        case "magnesium":    "Magnesium"
        case "iron":         "Iron"
        case "folate":       "Folate"
        case "zinc":         "Zinc"
        case "creatine":     "Creatine"
        case "ashwagandha":  "KSM-66"
        case "probiotic_cfu":"CFU"
        default: key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func circleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.ink)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.7)))
                .overlay(Circle().strokeBorder(AppColor.border, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }
}

#Preview {
    let container = MockData.previewContainer()
    let sample = try! container.mainContext.fetch(FetchDescriptor<Supplement>()).first!
    return NavigationStack {
        SupplementDetailView(supplement: sample)
    }
    .modelContainer(container)
}
