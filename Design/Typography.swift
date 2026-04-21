import SwiftUI

/// Font families used by the design. Register the `.ttf` files in
/// `Resources/Fonts/` via the target's `UIAppFonts` Info plist array. If a
/// custom font is missing, SwiftUI falls back to the system default, which
/// keeps the app bootable during setup.
enum AppFont {
    static let serifName       = "InstrumentSerif-Regular"
    static let serifItalicName = "InstrumentSerif-Italic"
    static let sansName        = "Inter-Regular"
    static let sansMediumName  = "Inter-Medium"
    static let sansSemiName    = "Inter-SemiBold"
    static let sansBoldName    = "Inter-Bold"

    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        Font.custom(italic ? serifItalicName : serifName, size: size, relativeTo: .title)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String = switch weight {
        case .bold, .heavy, .black:     sansBoldName
        case .semibold:                 sansSemiName
        case .medium:                   sansMediumName
        default:                        sansName
        }
        return Font.custom(name, size: size, relativeTo: .body)
    }
}

// ── Text styles ──────────────────────────────────────────────────────
// Mirrors `Serif`, `H2`, `Body`, `Label` from Shared.jsx.

struct SerifText: View {
    let text: String
    var size: CGFloat = 32
    var italic: Bool = false
    var color: Color = AppColor.ink

    var body: some View {
        Text(text)
            .font(AppFont.serif(size, italic: italic))
            .foregroundStyle(color)
            .tracking(size >= 48 ? -0.5 : 0)
            .lineSpacing(size * 0.08)
    }

    init(_ text: String, size: CGFloat = 32, italic: Bool = false, color: Color = AppColor.ink) {
        self.text = text
        self.size = size
        self.italic = italic
        self.color = color
    }
}

/// Renders "Good morning<italic>, Maya</italic>" style composed headlines.
struct ComposedSerif: View {
    let leading: String
    let italic: String
    var size: CGFloat = 30
    var italicColor: Color = AppColor.ink3

    var body: some View {
        (Text(leading)
            .font(AppFont.serif(size))
            .foregroundStyle(AppColor.ink)
         + Text(italic)
            .font(AppFont.serif(size, italic: true))
            .foregroundStyle(italicColor))
            .tracking(size >= 48 ? -0.5 : 0)
    }
}

struct BodyText: View {
    let text: String
    var size: CGFloat = 15
    var weight: Font.Weight = .regular
    var color: Color = AppColor.ink2

    var body: some View {
        Text(text)
            .font(AppFont.sans(size, weight: weight))
            .foregroundStyle(color)
    }

    init(_ text: String, size: CGFloat = 15, weight: Font.Weight = .regular, color: Color = AppColor.ink2) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
    }
}

struct LabelText: View {
    let text: String
    var color: Color = AppColor.ink3

    var body: some View {
        Text(text.uppercased())
            .font(AppFont.sans(11, weight: .medium))
            .tracking(0.5)
            .foregroundStyle(color)
    }

    init(_ text: String, color: Color = AppColor.ink3) {
        self.text = text
        self.color = color
    }
}
