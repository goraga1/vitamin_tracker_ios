import SwiftUI

enum CheckState {
    case pending, ready, taken, missed
}

/// Round tappable checkbox with four visual states. Port of `Check`.
struct CheckButton: View {
    var state: CheckState
    var size: CGFloat = 44
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .overlay(
                        Circle().strokeBorder(border, lineWidth: 1.5)
                    )

                switch state {
                case .taken:
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(.white)
                case .missed:
                    Circle()
                        .fill(AppColor.coral)
                        .frame(width: 6, height: 6)
                case .pending, .ready:
                    EmptyView()
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        switch state {
        case .pending: AppColor.surface
        case .ready:   AppColor.surface
        case .taken:   AppColor.sage
        case .missed:  AppColor.coralSoft
        }
    }

    private var border: Color {
        switch state {
        case .pending: AppColor.border
        case .ready:   AppColor.amber
        case .taken:   AppColor.sage
        case .missed:  AppColor.coral
        }
    }
}
