import SwiftUI

/// A7 — schedule assignment. Visual grouping of supplements into
/// time-of-day slots. Drag-to-reorder lands in a later phase; for now the
/// pills are static. Port of `A7Schedule`.
struct A7Schedule: View {
    var onNext: () -> Void = {}

    private struct Pill { let name: String; let tint: UInt32; let accent: UInt32 }
    private struct Slot {
        let id: String, label: String, icon: String, hint: String
        let items: [Pill]
    }
    private let slots: [Slot] = [
        .init(id: "morning", label: "Morning", icon: "☀", hint: "7:30", items: [
            .init(name: "Vitamin D3",    tint: 0xF3E5C6, accent: 0xC49A48),
            .init(name: "Omega-3",       tint: 0xE5EDD9, accent: 0x7C9658),
            .init(name: "Women's Multi", tint: 0xF8E4E0, accent: 0xC07A6B),
        ]),
        .init(id: "midday", label: "Midday", icon: "🌤", hint: "12:30", items: [
            .init(name: "Zinc",     tint: 0xE7E0D2, accent: 0xA08753),
            .init(name: "Creatine", tint: 0xDDE6E4, accent: 0x6D8884),
        ]),
        .init(id: "evening", label: "Evening", icon: "🌙", hint: "19:00", items: [
            .init(name: "Magnesium", tint: 0xE2E6EE, accent: 0x6F7C96),
        ]),
        .init(id: "night", label: "Night", icon: "⭐", hint: "22:00", items: [
            .init(name: "Ashwagandha", tint: 0xE8DCC9, accent: 0x9A7A4E),
        ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 8) {
                SerifText("When do you like to pause?", size: 32)
                BodyText("Drag supplements between parts of your day.",
                         size: 14, color: AppColor.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(slots, id: \.id) { s in slotCard(s) }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
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
            LabelText("Step 4 of 4")
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func slotCard(_ s: Slot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(s.icon).font(.system(size: 18))
                Text(s.label)
                    .font(AppFont.sans(15, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                Chip(text: s.hint, tone: .quiet)
                Spacer()
                Button("Edit time") {}
                    .font(AppFont.sans(13))
                    .foregroundStyle(AppColor.ink3)
            }

            if s.items.isEmpty {
                BodyText("Drop supplements here", size: 13, color: AppColor.ink4)
                    .padding(.vertical, 8)
            } else {
                FlowWrap(spacing: 8) {
                    ForEach(s.items, id: \.name) { pill in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: pill.tint))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: pill.accent))
                                        .frame(width: 10, height: 12)
                                )
                            Text(pill.name)
                                .font(AppFont.sans(13, weight: .medium))
                                .foregroundStyle(AppColor.ink)
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppColor.surface2))
                    }
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
}

#Preview { A7Schedule() }
