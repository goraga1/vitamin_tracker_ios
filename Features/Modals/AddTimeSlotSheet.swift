import SwiftUI

/// Creates a custom time-of-day slot on Today (Afternoon, Pre-workout, etc.).
/// Matches `AddTimeSlotSheet` in `Today.jsx`.
struct AddTimeSlotSheet: View {
    var onAdd: (TodayView.CustomSlot) -> Void
    var onCancel: () -> Void

    @State private var label = "Afternoon"
    @State private var icon  = "☕"
    @State private var time  = Calendar.current.date(from: DateComponents(hour: 15, minute: 0)) ?? .now

    private let icons = ["☀","🌤","☕","🌙","⭐","🍵","🏃","🌿"]

    private struct Preset {
        let label: String; let icon: String; let hour: Int; let minute: Int
    }
    private let presets: [Preset] = [
        .init(label: "Pre-workout", icon: "🏃", hour: 16, minute: 30),
        .init(label: "Afternoon",   icon: "☕", hour: 15, minute: 0),
        .init(label: "Before bed",  icon: "🌿", hour: 21, minute: 30),
        .init(label: "Late night",  icon: "⭐", hour: 23, minute: 0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SerifText("New time of day", size: 24)
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(AppFont.sans(14))
                    .foregroundStyle(AppColor.ink3)
            }

            LabelText("Quick picks")
            FlowWrap(spacing: 8) {
                ForEach(presets, id: \.label) { p in
                    Button {
                        label = p.label
                        icon = p.icon
                        time = Calendar.current.date(from: DateComponents(hour: p.hour, minute: p.minute)) ?? .now
                    } label: {
                        HStack(spacing: 6) {
                            Text(p.icon)
                            Text(p.label)
                                .font(AppFont.sans(13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(label == p.label ? .white : AppColor.ink)
                        .background(
                            Capsule().fill(label == p.label ? AppColor.ink : AppColor.surface2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            LabelText("Icon")
            FlowWrap(spacing: 8) {
                ForEach(icons, id: \.self) { g in
                    Button { icon = g } label: {
                        Text(g)
                            .font(.system(size: 18))
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(icon == g ? AppColor.sageSoft : AppColor.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(icon == g ? AppColor.sage : .clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            LabelText("Name")
            TextField("Afternoon", text: $label)
                .font(AppFont.sans(15))
                .foregroundStyle(AppColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            LabelText("Time")
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)

            Spacer()

            PillButton(title: "Add to today", variant: .primary) {
                onAdd(.init(label: label, icon: icon, time: time))
            }
        }
        .padding(24)
        .background(AppColor.bg.ignoresSafeArea())
    }
}

/// Simple wrap layout — ports the `display:flex; flex-wrap:wrap` patterns
/// the prototype relies on.
struct FlowWrap<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) { content() }
            WrapLayout(spacing: spacing) { content() }
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if rowWidth + size.width > width {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
