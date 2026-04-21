import SwiftUI
import SwiftData

enum StackSegment: String, CaseIterable, Identifiable {
    case active, paused, all
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Grid of supplements with Active / Paused / All segments. Matches
/// `StackScreen` in `Stack.jsx`.
struct StackView: View {
    @Query(sort: \Supplement.createdAt) private var supplements: [Supplement]
    @State private var segment: StackSegment = .active
    @State private var showAdd = false
    @State private var showSearch = false
    @State private var selected: Supplement?

    private var filtered: [Supplement] {
        switch segment {
        case .active: supplements.filter { !$0.isPaused }
        case .paused: supplements.filter {  $0.isPaused }
        case .all:    supplements
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColor.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        SerifText("Your stack", size: 30)
                        Spacer()
                        Button { showSearch = true } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColor.ink)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(AppColor.surface))
                                .overlay(Circle().strokeBorder(AppColor.border, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    SegmentedPicker(selection: $segment)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    if filtered.isEmpty {
                        StackEmptyInner(onScan: { showAdd = true })
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 12),
                                          GridItem(.flexible(), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(filtered) { s in
                                    Button { selected = s } label: {
                                        StackCard(supplement: s)
                                    }
                                    .buttonStyle(PressScaleStyle())
                                }
                            }
                            .padding(20)
                            .padding(.bottom, 120)
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColor.cream)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(AppColor.ink))
                        .shadow(color: AppColor.ink.opacity(0.18), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(PressScaleStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selected) { SupplementDetailView(supplement: $0) }
            .sheet(isPresented: $showAdd) { AddSupplementSheet() }
            .sheet(isPresented: $showSearch) { SearchSheet() }
        }
    }
}

struct SegmentedPicker: View {
    @Binding var selection: StackSegment

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StackSegment.allCases) { seg in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = seg }
                } label: {
                    Text(seg.title)
                        .font(AppFont.sans(13, weight: .medium))
                        .foregroundStyle(selection == seg ? AppColor.ink : AppColor.ink3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            Capsule()
                                .fill(selection == seg ? AppColor.surface : .clear)
                                .shadow(color: selection == seg ? AppColor.ink.opacity(0.06) : .clear,
                                        radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(AppColor.surface2))
    }
}

struct StackCard: View {
    let supplement: Supplement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hexString: supplement.tintHex) ?? AppColor.surface2)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    BottleView(
                        tint: Color(hexString: supplement.tintHex) ?? AppColor.surface2,
                        accent: Color(hexString: supplement.accentHex) ?? AppColor.ink3,
                        label: String(supplement.productName.prefix(2)),
                        size: 64
                    )
                )

            Text(supplement.productName)
                .font(AppFont.sans(14, weight: .medium))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)

            BodyText(doseSummary, size: 12, color: AppColor.ink3)

            Chip(text: frequencyLabel, tone: .quiet, height: 22)
        }
        .padding(12)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(AppColor.border, lineWidth: 1)
        )
    }

    private var doseSummary: String {
        if let main = supplement.ingredients.first {
            return "\(AmountFormat.trim(main.amount)) \(main.unit)"
        }
        return "\(AmountFormat.trim(supplement.servingSize)) \(supplement.servingUnit)"
    }

    private var frequencyLabel: String {
        "1×/day" // Derived from Schedule once days-of-week UI ships
    }
}

// MARK: - Empty state

struct StackEmptyInner: View {
    var onScan: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Canvas { ctx, canvasSize in
                let sx = canvasSize.width / 180
                let sy = canvasSize.height / 120
                let border = AppColor.border

                func bar(_ y: CGFloat) -> Path {
                    Path(roundedRect: CGRect(x: 20 * sx, y: y * sy, width: 140 * sx, height: 4 * sy), cornerRadius: 1 * sy)
                }
                ctx.fill(bar(85), with: .color(border))
                ctx.fill(bar(50), with: .color(border))

                ctx.opacity = 0.35
                ctx.fill(
                    Path(roundedRect: CGRect(x: 32 * sx, y: 62 * sy, width: 16 * sx, height: 23 * sy), cornerRadius: 3),
                    with: .color(AppColor.surface3)
                )
                ctx.fill(
                    Path(roundedRect: CGRect(x: 130 * sx, y: 27 * sy, width: 16 * sx, height: 23 * sy), cornerRadius: 3),
                    with: .color(AppColor.surface3)
                )
            }
            .frame(width: 180, height: 120)

            VStack(spacing: 8) {
                SerifText("Your stack is empty", size: 26)
                BodyText("Scan a bottle label and we'll add it in seconds.",
                         size: 14, color: AppColor.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }

            PillButton(title: "Scan a supplement", variant: .primary, action: onScan)
                .frame(width: 220)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}

/// Standalone Stack-empty screen (preview/onboarding fallback).
struct StackEmptyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SerifText("Your stack", size: 30)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            StackEmptyInner(onScan: {})
        }
        .background(AppColor.bg)
    }
}

#Preview("Stack") {
    StackView().modelContainer(MockData.previewContainer())
}
#Preview("Empty") { StackEmptyView() }
