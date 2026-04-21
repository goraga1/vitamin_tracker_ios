import SwiftUI

/// CTA button with primary / sage / ghost / quiet variants. Port of `CTA`.
enum CTAVariant {
    case primary, sage, ghost, quiet
}

enum CTASize {
    case large, small
    var height: CGFloat { self == .large ? 54 : 44 }
}

struct PillButton: View {
    var title: String
    var icon: String? = nil
    var variant: CTAVariant = .primary
    var size: CTASize = .large
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .medium)) }
                Text(title)
                    .font(AppFont.sans(16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .background(background)
            .foregroundStyle(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(strokeColor, lineWidth: variant == .ghost ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(disabled)
    }

    private var background: Color {
        switch variant {
        case .primary: AppColor.ink
        case .sage:    AppColor.sage
        case .ghost:   .clear
        case .quiet:   AppColor.surface2
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary: AppColor.cream
        case .sage:    .white
        case .ghost:   AppColor.ink
        case .quiet:   AppColor.ink
        }
    }

    private var strokeColor: Color {
        variant == .ghost ? AppColor.border : .clear
    }

    private var shadowColor: Color {
        if disabled { return .clear }
        switch variant {
        case .primary: return AppColor.ink.opacity(0.12)
        case .sage:    return AppColor.sage.opacity(0.25)
        case .ghost, .quiet: return .clear
        }
    }
}

/// Press-scale button style used across the app.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
