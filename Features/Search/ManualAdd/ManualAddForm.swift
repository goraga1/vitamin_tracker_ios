import SwiftUI
import SwiftData

/// Escape-hatch screen for products that don't surface in any of the hybrid
/// search sources. Captures the minimum needed to create a `Supplement` row
/// with a first `Schedule`, and hands off back to the caller on save.
///
/// Intentionally spartan: no ingredient editor, no photo, no notes. Those
/// belong in a full edit screen — users can refine later from Stack.
struct ManualAddForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var onSave: (Supplement) -> Void

    @State private var brand: String = ""
    @State private var productName: String = ""
    @State private var form: SupplementForm = .capsule
    @State private var servingSize: String = "1"
    @State private var timeOfDay: TimeOfDay = .morning
    @State private var time: Date = Self.defaultMorningTime()

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case brand, product, serving }

    private var servingValue: Double {
        Double(servingSize.replacingOccurrences(of: ",", with: ".")) ?? 1
    }

    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !productName.trimmingCharacters(in: .whitespaces).isEmpty
            && servingValue > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Brand", text: $brand)
                        .focused($focusedField, equals: .brand)
                        .textInputAutocapitalization(.words)
                    TextField("Product name", text: $productName)
                        .focused($focusedField, equals: .product)
                        .textInputAutocapitalization(.words)
                }
                Section("Dosage") {
                    Picker("Form", selection: $form) {
                        ForEach(SupplementForm.allCases, id: \.self) { f in
                            Text(label(for: f)).tag(f)
                        }
                    }
                    HStack {
                        Text("Per serving")
                        Spacer()
                        TextField("1", text: $servingSize)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .serving)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text(servingUnit(for: form))
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Schedule") {
                    Picker("Time of day", selection: $timeOfDay) {
                        ForEach(TimeOfDay.allCases) { t in
                            Text(t.defaultLabel).tag(t)
                        }
                    }
                    DatePicker(
                        "Remind me at",
                        selection: $time,
                        displayedComponents: .hourAndMinute
                    )
                }
            }
            .navigationTitle("Add manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { focusedField = .brand }
        }
    }

    private func save() {
        let tint = hashHex(brand + productName, palette: tintPalette)
        let accent = hashHex(brand + productName, palette: accentPalette)

        let supp = Supplement(
            brand: brand.trimmingCharacters(in: .whitespaces),
            productName: productName.trimmingCharacters(in: .whitespaces),
            form: form,
            servingSize: servingValue,
            servingUnit: servingUnit(for: form),
            tintHex: tint,
            accentHex: accent
        )
        supp.schedules = [Schedule(timeOfDay: timeOfDay, specificTime: time)]
        context.insert(supp)
        try? context.save()
        onSave(supp)
        dismiss()
    }

    private static func defaultMorningTime() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }

    private func label(for form: SupplementForm) -> String {
        switch form {
        case .tablet: "Tablet"
        case .capsule: "Capsule"
        case .softgel: "Softgel"
        case .liquid: "Liquid"
        case .powder: "Powder"
        case .gummy: "Gummy"
        case .lozenge: "Lozenge"
        case .other: "Other"
        }
    }

    private func servingUnit(for form: SupplementForm) -> String {
        switch form {
        case .tablet: "tab"
        case .capsule: "cap"
        case .softgel: "softgel"
        case .liquid: "ml"
        case .powder: "scoop"
        case .gummy: "gummy"
        case .lozenge: "lozenge"
        case .other: "serving"
        }
    }

    // MARK: - Deterministic palette

    private let tintPalette: [UInt32] = [
        0xE2E6EE, 0xF3E5C6, 0xE5EDD9, 0xF8E4E0, 0xE7E2F3, 0xDDEEF2,
    ]
    private let accentPalette: [UInt32] = [
        0x6F7C96, 0xC49A48, 0x7C9658, 0xC07A6B, 0x7F6EB3, 0x4F8796,
    ]

    private func hashHex(_ seed: String, palette: [UInt32]) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        let idx = Int(hash % UInt64(palette.count))
        return String(format: "#%06X", palette[idx])
    }
}
