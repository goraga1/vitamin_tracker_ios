import SwiftUI

/// Full-screen streak detail: current count, 6-month heatmap, milestones.
/// Port of `SheetStreak`.
struct StreakSheet: View {
    @Environment(\.dismiss) private var dismiss
    var streakDays: Int = 15

    private struct Milestone {
        let days: String, label: String, status: String, unlocked: Bool
    }
    private let milestones: [Milestone] = [
        .init(days: "7 days",   label: "Warm start",   status: "unlocked", unlocked: true),
        .init(days: "14 days",  label: "Two weeks",    status: "unlocked", unlocked: true),
        .init(days: "30 days",  label: "A month in",   status: "15 to go", unlocked: false),
        .init(days: "100 days", label: "Ritual",       status: "85 to go", unlocked: false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.ink)
                        .frame(width: 36, height: 36)
                }
                Spacer()
                LabelText("Streak")
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerBlock
                    heatmap
                    milestonesBlock
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppColor.bg.ignoresSafeArea())
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(streakDays)")
                    .font(AppFont.serif(60))
                    .tracking(-1.2)
                    .foregroundStyle(AppColor.ink)
                Text("days")
                    .font(AppFont.serif(24, italic: true))
                    .foregroundStyle(AppColor.ink3)
            }
            BodyText("Longest this year. Keep it warm.", size: 14, color: AppColor.ink3)
        }
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabelText("This year")

            // 26 weeks × 7 days — matches prototype exactly.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 26), spacing: 3) {
                ForEach(0..<26*7, id: \.self) { i in
                    let x = Double(i) * 1.3
                    let y = Double(i) * 0.7
                    let v = (sin(x) + cos(y) + 2) / 4
                    cell(intensity: v)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(AppColor.border, lineWidth: 1)
        )
    }

    private func cell(intensity v: Double) -> some View {
        let color: Color =
            v > 0.85 ? AppColor.sage :
            v > 0.60 ? AppColor.sageSoft :
            v > 0.30 ? AppColor.surface3 :
                       AppColor.surface2
        return RoundedRectangle(cornerRadius: 2).fill(color)
    }

    private var milestonesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabelText("Milestones")
            VStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { i, m in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(m.unlocked ? AppColor.sageSoft : AppColor.surface2)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Text(m.unlocked ? "✓" : "·")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColor.ink)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            BodyText(m.days, size: 14, color: AppColor.ink)
                            BodyText(m.label, size: 12, color: AppColor.ink3)
                        }
                        Spacer()
                        BodyText(m.status, size: 12,
                                 color: m.unlocked ? AppColor.sageDeep : AppColor.ink4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if i < milestones.count - 1 {
                        Divider().background(AppColor.borderSoft)
                    }
                }
            }
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14).strokeBorder(AppColor.border, lineWidth: 1)
            )
        }
    }
}

#Preview { StreakSheet() }
