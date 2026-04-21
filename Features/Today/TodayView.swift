import SwiftUI
import SwiftData

/// Today — daily intake timeline grouped by time-of-day slot. Tap a
/// supplement tile to open Detail; tap the round check to mark taken.
/// "Add time of day" opens a sheet for custom slots.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Supplement.createdAt) private var supplements: [Supplement]
    @Query private var profiles: [UserProfile]

    @State private var taken: Set<UUID> = []
    @State private var missed: Set<UUID> = []
    @State private var customSlots: [CustomSlot] = []
    @State private var addingSlot = false
    @State private var showStreak = false
    @State private var showAdd = false
    @State private var selectedSupplement: Supplement?

    // Variant toggle for previews and QA; normal runs stay at .live.
    var variant: TodayVariant = .live

    struct CustomSlot: Identifiable {
        let id = UUID()
        var label: String
        var icon: String
        var time: Date
    }

    enum TodayVariant { case live, morning, midday, evening }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColor.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                            .padding(.horizontal, 20)

                        if variant == .evening || isDayComplete {
                            completeBanner
                                .padding(.horizontal, 20)
                        } else {
                            BodyText(subtitle, size: 14, color: AppColor.ink3)
                                .padding(.horizontal, 20)
                        }

                        ForEach(timelineSlots) { slot in
                            TimelineSlotView(
                                slot: slot,
                                onToggle: { toggle($0) },
                                onTapSupplement: { selectedSupplement = $0 },
                                isTaken: { taken.contains($0.id) },
                                isMissed: { missed.contains($0.id) }
                            )
                            .padding(.horizontal, 20)
                        }

                        addTimeButton
                            .padding(.horizontal, 20)

                        streakRow
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)

                fab
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedSupplement) { supp in
                SupplementDetailView(supplement: supp)
            }
        }
        .sheet(isPresented: $addingSlot) {
            AddTimeSlotSheet { slot in
                customSlots.append(slot)
                addingSlot = false
            } onCancel: { addingSlot = false }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showStreak) {
            StreakSheet(streakDays: profile?.streakDays ?? 14)
        }
        .sheet(isPresented: $showAdd) {
            AddSupplementSheet()
        }
        .onAppear(perform: hydrateFromVariant)
    }

    // ── Data derivations ─────────────────────────────────────────────

    private var profile: UserProfile? { profiles.first }

    private var activeSupplements: [Supplement] {
        supplements.filter { !$0.isPaused }
    }

    private var timelineSlots: [TimelineSlot] {
        var grouped: [TimeOfDay: [Supplement]] = [:]
        for s in activeSupplements {
            if let slot = s.schedules.first?.timeOfDay {
                grouped[slot, default: []].append(s)
            }
        }
        let baseOrder: [TimeOfDay] = [.morning, .midday, .evening, .night]
        var slots: [TimelineSlot] = baseOrder.map {
            TimelineSlot(
                id: $0.rawValue,
                label: $0.defaultLabel,
                icon: $0.defaultIcon,
                time: defaultTime(for: $0),
                items: grouped[$0] ?? []
            )
        }
        slots.append(contentsOf: customSlots.map {
            TimelineSlot(id: $0.id.uuidString,
                         label: $0.label,
                         icon: $0.icon,
                         time: timeString(from: $0.time),
                         items: [])
        })
        return slots
    }

    private var totalCount: Int { activeSupplements.count }
    private var takenCount: Int { taken.count }
    private var percentage: Double {
        totalCount == 0 ? 0 : Double(takenCount) / Double(totalCount)
    }
    private var isDayComplete: Bool { takenCount == totalCount && totalCount > 0 }

    private var greeting: String {
        switch variant {
        case .morning: "Good morning"
        case .midday:  "Afternoon pause"
        case .evening: "Evening"
        case .live:
            let h = Calendar.current.component(.hour, from: .now)
            if h < 12 { return "Good morning" }
            if h < 17 { return "Afternoon pause" }
            return "Evening"
        }
    }

    private var subtitle: String {
        switch variant {
        case .morning: "Four to begin your day."
        case .midday:  "Three in. Two more to go."
        case .evening: "Day complete."
        case .live:
            let remaining = totalCount - takenCount
            if remaining == 0 { return "Day complete." }
            if remaining == totalCount { return "\(remaining) to begin your day." }
            return "\(takenCount) in. \(remaining) more to go."
        }
    }

    private var dateHeading: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · d MMMM"
        return f.string(from: .now)
    }

    // ── UI sections ──────────────────────────────────────────────────

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                LabelText(dateHeading)
                ComposedSerif(leading: greeting,
                              italic: ", \(profile?.displayName ?? "Maya")",
                              size: 30)
                    .padding(.top, 4)
            }
            Spacer()
            ProgressRing(size: 56, value: percentage, stroke: 4,
                         color: percentage == 1 ? AppColor.sage : AppColor.ink) {
                Text("\(takenCount)/\(totalCount)")
                    .font(AppFont.sans(13, weight: .semibold))
                    .foregroundStyle(percentage == 1 ? AppColor.sage : AppColor.ink)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
    }

    private var completeBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColor.sage)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                SerifText("Day complete", size: 22)
                BodyText("\((profile?.streakDays ?? 14) + 1)-day streak extended.",
                         size: 13, color: AppColor.sageDeep)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(AppColor.sageSofter)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(AppColor.sageSoft, lineWidth: 1)
        )
    }

    private var addTimeButton: some View {
        Button { addingSlot = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add time of day")
                    .font(AppFont.sans(14))
            }
            .foregroundStyle(AppColor.ink3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(AppColor.border)
            )
        }
        .buttonStyle(PressScaleStyle())
    }

    private var streakRow: some View {
        Button { showStreak = true } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(AppColor.surface)
                    .frame(width: 44, height: 44)
                    .overlay(Text("🔥").font(.system(size: 20)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(profile?.streakDays ?? 14)-day streak")
                        .font(AppFont.sans(14, weight: .medium))
                        .foregroundStyle(AppColor.ink)
                    BodyText("Your longest this year.", size: 12, color: AppColor.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.ink3)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(variant == .evening ? AppColor.sageSoft : AppColor.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(variant == .evening ? AppColor.sageSoft : AppColor.border,
                                  lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle())
    }

    private var fab: some View {
        Button { showAdd = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppColor.cream)
                .frame(width: 56, height: 56)
                .background(Circle().fill(AppColor.ink))
                .shadow(color: AppColor.ink.opacity(0.18), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(PressScaleStyle())
    }

    // ── Actions ──────────────────────────────────────────────────────

    private func toggle(_ s: Supplement) {
        if taken.contains(s.id) {
            taken.remove(s.id)
        } else {
            taken.insert(s.id)
            missed.remove(s.id)
        }
        // In Phase 2 we'd persist an IntakeLog here and write to HealthKit.
    }

    private func hydrateFromVariant() {
        guard taken.isEmpty, missed.isEmpty else { return }
        let map = Dictionary(uniqueKeysWithValues: supplements.map { ($0.productName, $0.id) })
        func idsFor(_ names: [String]) -> [UUID] { names.compactMap { map[$0] } }

        switch variant {
        case .midday:
            taken = Set(idsFor(["Vitamin D3", "Omega-3", "Women's Multi"]))
            missed = Set(idsFor(["Probiotic"]))
        case .evening:
            taken = Set(activeSupplements.map(\.id))
        case .morning, .live:
            break
        }
    }

    private func defaultTime(for tod: TimeOfDay) -> String {
        switch tod {
        case .morning: "7:30"
        case .midday:  "12:30"
        case .evening: "19:00"
        case .night:   "22:00"
        case .custom:  ""
        }
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f.string(from: date)
    }
}

struct TimelineSlot: Identifiable {
    let id: String
    let label: String
    let icon: String
    let time: String
    let items: [Supplement]
}

private struct TimelineSlotView: View {
    let slot: TimelineSlot
    let onToggle: (Supplement) -> Void
    let onTapSupplement: (Supplement) -> Void
    let isTaken: (Supplement) -> Bool
    let isMissed: (Supplement) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(slot.icon).font(.system(size: 16))
                LabelText(slot.label)
                if !slot.time.isEmpty {
                    Text("· \(slot.time)")
                        .font(AppFont.sans(11))
                        .tracking(0.3)
                        .foregroundStyle(AppColor.ink4)
                }
                Rectangle()
                    .fill(AppColor.border)
                    .frame(height: 1)
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 2)

            if slot.items.isEmpty {
                BodyText("Drop supplements here", size: 13, color: AppColor.ink4)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppColor.border, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(slot.items.enumerated()), id: \.element.id) { idx, s in
                        TodayRow(
                            supplement: s,
                            checked: isTaken(s),
                            missed: isMissed(s),
                            onToggle: { onToggle(s) },
                            onOpen: { onTapSupplement(s) }
                        )
                        if idx < slot.items.count - 1 {
                            Divider().background(AppColor.borderSoft)
                        }
                    }
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
}

private struct TodayRow: View {
    let supplement: Supplement
    let checked: Bool
    let missed: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hexString: supplement.tintHex) ?? AppColor.surface2)
                    .frame(width: 44, height: 50)
                    .overlay(
                        BottleView(
                            tint: Color(hexString: supplement.tintHex) ?? AppColor.surface2,
                            accent: Color(hexString: supplement.accentHex) ?? AppColor.ink3,
                            label: String(supplement.productName.prefix(2)),
                            size: 32
                        )
                    )
            }
            .buttonStyle(PressScaleStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(supplement.productName)
                    .font(AppFont.sans(15, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                    .strikethrough(checked, color: AppColor.ink3)
                BodyText(
                    "\(doseLabel) · \(supplement.brand)",
                    size: 12,
                    color: AppColor.ink3
                )
            }
            .opacity(checked ? 0.55 : 1)
            .animation(.easeOut(duration: 0.2), value: checked)

            Spacer()

            CheckButton(state: state, action: onToggle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var doseLabel: String {
        if let main = supplement.ingredients.first {
            return "\(AmountFormat.trim(main.amount)) \(main.unit)"
        }
        return "\(AmountFormat.trim(supplement.servingSize)) \(supplement.servingUnit)"
    }

    private var state: CheckState {
        if checked { return .taken }
        if missed  { return .missed }
        return .ready
    }
}

enum AmountFormat {
    static func trim(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%g", v)
    }
}

#Preview("Live") {
    TodayView()
        .modelContainer(MockData.previewContainer())
}

#Preview("Morning") { TodayView(variant: .morning).modelContainer(MockData.previewContainer()) }
#Preview("Midday")  { TodayView(variant: .midday) .modelContainer(MockData.previewContainer()) }
#Preview("Evening") { TodayView(variant: .evening).modelContainer(MockData.previewContainer()) }
