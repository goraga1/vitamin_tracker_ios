import SwiftUI
import UIKit

enum AppTab: Hashable {
    case today, stack, insights, profile
}

/// Root TabView. Uses a custom tab bar rendered inside each screen's
/// overlay via the prototype's look; here we lean on the system TabView
/// with UITabBarAppearance tuned to match the cream / ink palette.
struct RootView: View {
    @State private var tab: AppTab = .today

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(AppColor.cream.opacity(0.96))
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)

        let normal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(AppColor.ink4)
        ]
        let selected: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(AppColor.ink)
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normal
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selected
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColor.ink4)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColor.ink)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tag(AppTab.today)
                .tabItem {
                    Label("Today", systemImage: "clock")
                }

            StackView()
                .tag(AppTab.stack)
                .tabItem {
                    Label("Stack", systemImage: "square.stack")
                }

            InsightsView()
                .tag(AppTab.insights)
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }

            ProfileView()
                .tag(AppTab.profile)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .tint(AppColor.ink)
    }
}

#Preview {
    RootView().modelContainer(MockData.previewContainer())
}
