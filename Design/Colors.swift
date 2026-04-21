import SwiftUI

/// Warm cream palette from the design prototype. Hex values mirror the `T`
/// object in `Shared.jsx` exactly so screens can be diffed 1:1 against the
/// HTML.
enum AppColor {
    static let bg        = Color(hex: 0xFFFFFF)
    static let surface   = Color(hex: 0xFFFFFF)
    static let surface2  = Color(hex: 0xF5F3EF)
    static let surface3  = Color(hex: 0xEDEAE3)

    static let ink       = Color(hex: 0x1C1A18)
    static let ink2      = Color(hex: 0x3A3633)
    static let ink3      = Color(hex: 0x6B6660)
    static let ink4      = Color(hex: 0xA39E96)

    static let border     = Color(hex: 0xEAE4DA)
    static let borderSoft = Color(hex: 0xF2EDE4)

    static let sage       = Color(hex: 0x7A9B7E)
    static let sageDeep   = Color(hex: 0x5F8065)
    static let sageSoft   = Color(hex: 0xE8EDE6)
    static let sageSofter = Color(hex: 0xF0F3EE)

    static let amber     = Color(hex: 0xE8B574)
    static let amberSoft = Color(hex: 0xFAEDD7)
    static let amberInk  = Color(hex: 0x8A6020)

    static let coral     = Color(hex: 0xD88B7A)
    static let coralSoft = Color(hex: 0xF5DED6)
    static let coralInk  = Color(hex: 0x9A4A3C)

    static let cream     = Color(hex: 0xFAF7F2)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }
}
