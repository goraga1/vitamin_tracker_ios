import SwiftUI

/// A3 — camera / notifications / health consent preview. The actual
/// permission prompts land when the matching feature ships (camera with
/// A4, notifications with first schedule, HealthKit on Profile toggle).
struct A3Permissions: View {
    var onNext: () -> Void = {}

    private struct Item {
        let icon: String     // SF Symbol
        let title: String
        let body: String
        let required: Bool
    }
    private let items: [Item] = [
        .init(icon: "camera",      title: "Camera",        body: "To scan supplement labels.",       required: true),
        .init(icon: "bell",        title: "Notifications", body: "Gentle nudges at your chosen hours.", required: true),
        .init(icon: "heart",       title: "Apple Health",  body: "Optional. Sync intake with Health app.", required: false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LabelText("Step 1 of 4")
                .padding(.horizontal, 24)
                .padding(.top, 20)

            (Text("Three quick\n")
                .font(AppFont.serif(36))
             + Text("permissions")
                .font(AppFont.serif(36)))
                .foregroundStyle(AppColor.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)

            BodyText(
                "We ask only for what's needed. You can change any of these later in Settings.",
                size: 15, color: AppColor.ink3
            )
            .padding(.horizontal, 24)
            .padding(.top, 10)

            VStack(spacing: 14) {
                ForEach(items, id: \.title) { item in
                    permissionRow(item)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer(minLength: 12)

            PillButton(title: "Continue", variant: .primary, action: onNext)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
    }

    private func permissionRow(_ item: Item) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColor.surface2)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(item.icon == "heart" ? AppColor.coral : AppColor.ink)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(AppFont.sans(16, weight: .medium))
                        .foregroundStyle(AppColor.ink)
                    if !item.required {
                        Text("· optional")
                            .font(AppFont.sans(13))
                            .foregroundStyle(AppColor.ink4)
                    }
                }
                BodyText(item.body, size: 13, color: AppColor.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(AppColor.border, lineWidth: 1)
        )
    }
}

#Preview { A3Permissions() }
