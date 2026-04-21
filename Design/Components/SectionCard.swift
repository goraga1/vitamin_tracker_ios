import SwiftUI

/// Surface container + uppercase label used throughout the detail, profile,
/// and onboarding screens. Port of `Section` / `Row` / `Stat` from Stack.jsx.
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabelText(title)
                .padding(.leading, 2)
            VStack(spacing: 0) {
                content()
            }
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(AppColor.border, lineWidth: 1)
            )
        }
    }
}

struct DetailRow: View {
    let left: String
    var right: String = ""
    var showChevron: Bool = true
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BodyText(left, size: 14, color: AppColor.ink)
                Spacer()
                HStack(spacing: 8) {
                    BodyText(right, size: 14, color: AppColor.ink3)
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColor.ink4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider().background(AppColor.borderSoft)
            }
        }
    }
}

struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LabelText(label)
            SerifText(value, size: 22)
        }
    }
}
