import SwiftUI

enum ChipTone {
    case quiet, sage, amber, coral, ink, outline
}

/// Pill-shaped tag. Port of `Chip`.
struct Chip: View {
    let text: String
    var trailingDetail: String? = nil
    var tone: ChipTone = .quiet
    var height: CGFloat = 26

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(AppFont.sans(12, weight: .medium))
            if let trailingDetail {
                Text(trailingDetail)
                    .font(AppFont.sans(12))
                    .foregroundStyle(AppColor.ink3)
            }
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(
            Capsule().fill(bg)
        )
        .overlay(
            Capsule().strokeBorder(borderColor, lineWidth: tone == .outline ? 1 : 0)
        )
    }

    private var fg: Color {
        switch tone {
        case .quiet:   AppColor.ink2
        case .sage:    AppColor.sageDeep
        case .amber:   AppColor.amberInk
        case .coral:   AppColor.coralInk
        case .ink:     AppColor.cream
        case .outline: AppColor.ink3
        }
    }

    private var bg: Color {
        switch tone {
        case .quiet:   AppColor.surface2
        case .sage:    AppColor.sageSoft
        case .amber:   AppColor.amberSoft
        case .coral:   AppColor.coralSoft
        case .ink:     AppColor.ink
        case .outline: .clear
        }
    }

    private var borderColor: Color {
        tone == .outline ? AppColor.border : .clear
    }
}
