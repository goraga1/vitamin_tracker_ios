import SwiftUI

/// Manual supplement entry sheet. Phase-1a placeholder — fields are
/// decorative until the form / photo-scan pipeline lands in Phase 1b.
/// Port of `SheetAddManual`.
struct AddSupplementSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var dose = ""
    @State private var frequency = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(AppColor.border)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

            HStack {
                SerifText("Add supplement", size: 24)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(AppFont.sans(14))
                    .foregroundStyle(AppColor.ink3)
            }
            .padding(.top, 6)

            photoPicker

            field("Name", text: $name)
            field("Brand", text: $brand)
            field("Dose", text: $dose)
            field("Frequency", text: $frequency)

            Spacer()

            PillButton(title: "Save supplement", variant: .primary) { dismiss() }
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .background(AppColor.bg.ignoresSafeArea())
    }

    private var photoPicker: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera")
                .font(.system(size: 14))
            Text("Add photo or pick an icon")
                .font(AppFont.sans(13))
        }
        .foregroundStyle(AppColor.ink3)
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(AppColor.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(AppColor.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabelText(label)
            TextField("Tap to enter", text: text)
                .font(AppFont.sans(15))
                .foregroundStyle(AppColor.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(AppColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview { AddSupplementSheet() }
