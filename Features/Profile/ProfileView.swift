import SwiftUI
import SwiftData

/// Settings / account. Port of `ProfileScreen`.
struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @State private var healthKitOn: Bool = true

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.top, 10)

                        streakBanner
                            .padding(.top, 18)

                        SectionCard(title: "Subscription") {
                            DetailRow(left: "Yearly Premium", right: "Active",
                                      showChevron: true, isLast: true)
                        }
                        .padding(.top, 20)

                        SectionCard(title: "Integrations") {
                            HStack {
                                BodyText("Apple Health", size: 14, color: AppColor.ink)
                                Spacer()
                                Toggle("", isOn: $healthKitOn)
                                    .labelsHidden()
                                    .tint(AppColor.sage)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            Divider().background(AppColor.borderSoft)
                            DetailRow(left: "Notifications", right: "3 times/day")
                            DetailRow(left: "Quiet hours",   right: "10pm – 6am", isLast: true)
                        }
                        .padding(.top, 20)

                        SectionCard(title: "App") {
                            DetailRow(left: "Widgets",        right: "Set up")
                            DetailRow(left: "Appearance",     right: "Auto")
                            DetailRow(left: "Export data",    right: "")
                            DetailRow(left: "Help & feedback", right: "")
                            DetailRow(left: "About",          right: "v1.0.0", isLast: true)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 140)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppColor.surface3)
                .frame(width: 54, height: 54)
                .overlay(
                    Text(String((profile?.displayName ?? "M").prefix(1)))
                        .font(AppFont.serif(22))
                        .foregroundStyle(AppColor.ink)
                )
            VStack(alignment: .leading, spacing: 2) {
                SerifText(profile?.displayName ?? "Maya", size: 26)
                BodyText("Member since \(memberSinceLabel)", size: 13, color: AppColor.ink3)
            }
            Spacer()
        }
    }

    private var streakBanner: some View {
        HStack(spacing: 14) {
            Text("🔥").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 2) {
                SerifText("\(profile?.streakDays ?? 15) days", size: 34)
                BodyText("Current streak · longest this year", size: 13, color: AppColor.sageDeep)
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [AppColor.sageSoft, AppColor.sageSofter],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16).strokeBorder(AppColor.sageSoft, lineWidth: 1)
        )
    }

    private var memberSinceLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        return df.string(from: profile?.memberSince ?? .now)
    }
}

#Preview {
    ProfileView().modelContainer(MockData.previewContainer())
}
