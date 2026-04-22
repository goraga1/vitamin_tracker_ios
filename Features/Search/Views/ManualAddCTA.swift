import SwiftUI

/// Always-visible escape hatch: the search list can't possibly cover every
/// product on the market, so we make the manual-entry CTA prominent rather
/// than hiding it. Tapping hands control back to the caller via `onTap`.
struct ManualAddCTA: View {
    var message: String = "Can't find it?"
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                VStack(alignment: .leading, spacing: 2) {
                    BodyText(message, size: 13, color: AppColor.ink3)
                    BodyText("Add manually", size: 14, weight: .semibold, color: AppColor.ink)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.ink3)
            }
            .padding(14)
            .background(AppColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle())
    }
}
