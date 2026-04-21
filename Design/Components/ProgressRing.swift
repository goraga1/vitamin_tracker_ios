import SwiftUI

/// Circular progress ring. `value` is 0…1. Matches the `Ring` primitive.
struct ProgressRing<Content: View>: View {
    var size: CGFloat = 44
    var value: Double
    var stroke: CGFloat = 4
    var color: Color = AppColor.sage
    var background: Color = AppColor.surface3
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(background, lineWidth: stroke)

            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: value)

            content()
        }
        .frame(width: size, height: size)
    }
}

extension ProgressRing where Content == EmptyView {
    init(size: CGFloat = 44, value: Double, stroke: CGFloat = 4,
         color: Color = AppColor.sage, background: Color = AppColor.surface3) {
        self.init(size: size, value: value, stroke: stroke,
                  color: color, background: background) { EmptyView() }
    }
}
