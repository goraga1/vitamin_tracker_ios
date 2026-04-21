import SwiftUI

enum PaywallPlan: String, CaseIterable, Identifiable {
    case yearly, monthly
    var id: String { rawValue }
}

/// Premium subscription paywall. RevenueCat wiring lands in Phase 1b —
/// for now the CTAs are visual. Port of `PaywallScreen`.
struct PaywallView: View {
    var onClose: () -> Void = {}

    @State private var plan: PaywallPlan = .yearly

    private let bullets = [
        "Unlimited supplements",
        "Nutrient insights across your full stack",
        "Interaction warnings",
        "Apple Health sync",
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.ink)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColor.surface2))
                }
                Spacer()
                Button("Restore") {}
                    .font(AppFont.sans(13))
                    .foregroundStyle(AppColor.ink3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        LabelText("Vitamin Tracker")
                        ComposedSerif(leading: "Unlock your ",
                                      italic: "full stack",
                                      size: 44,
                                      italicColor: AppColor.ink)
                            .lineLimit(nil)
                        BodyText("Seven days free. Cancel anytime.",
                                 size: 15, color: AppColor.ink3)
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(bullets, id: \.self) { b in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(AppColor.sageSoft)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(AppColor.sageDeep)
                                    )
                                BodyText(b, size: 15, color: AppColor.ink)
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        PlanCard(
                            selected: plan == .yearly,
                            title: "Yearly",
                            subtitle: "$39 · 7 days free, then $3.25/mo",
                            badge: "Save 67%"
                        ) { plan = .yearly }

                        PlanCard(
                            selected: plan == .monthly,
                            title: "Monthly",
                            subtitle: "$9.99 / month"
                        ) { plan = .monthly }
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                PillButton(title: "Start 7-day free trial", variant: .sage) {}
                HStack(spacing: 14) {
                    Button("Terms") {}
                    Button("Privacy") {}
                }
                .font(AppFont.sans(11))
                .foregroundStyle(AppColor.ink4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(AppColor.bg.ignoresSafeArea())
    }
}

private struct PlanCard: View {
    var selected: Bool
    var title: String
    var subtitle: String
    var badge: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(selected ? AppColor.sage : AppColor.border, lineWidth: 1.5)
                        .background(Circle().fill(selected ? AppColor.sage : .clear))
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle().fill(.white).frame(width: 8, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.sans(15, weight: .semibold))
                        .foregroundStyle(AppColor.ink)
                    BodyText(subtitle, size: 13, color: AppColor.ink3)
                }

                Spacer()

                if let badge { Chip(text: badge, tone: .sage) }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? AppColor.sageSofter : AppColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? AppColor.sage : AppColor.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(PressScaleStyle())
    }
}

#Preview { PaywallView() }
