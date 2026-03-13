import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Content area with smooth crossfade
            ZStack {
                HomeView()
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .offset(y: selectedTab == 0 ? 0 : 10)
                    .allowsHitTesting(selectedTab == 0)

                HistoryView()
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .offset(y: selectedTab == 1 ? 0 : 10)
                    .allowsHitTesting(selectedTab == 1)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabNamespace

    private let tabs: [(icon: String, label: String)] = [
        ("leaf.fill", "Home"),
        ("calendar", "History"),
    ]

    var body: some View {
        HStack {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == index {
                                Capsule()
                                    .fill(Color.vqGreen.opacity(0.15))
                                    .frame(width: 56, height: 30)
                                    .matchedGeometryEffect(id: "tab_bg", in: tabNamespace)
                            }

                            Image(systemName: tabs[index].icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selectedTab == index ? Color.vqGreen : Color.vqTextSecondary.opacity(0.5))
                        }
                        .frame(height: 30)

                        Text(tabs[index].label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(selectedTab == index ? Color.vqGreen : Color.vqTextSecondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Color.vqBackground
                .shadow(color: Color.vqTextPrimary.opacity(0.06), radius: 8, y: -2)
        )
    }
}

/// Self-contained profile button that presents ProfileView as a sheet
struct ProfileButton: View {
    @State private var showProfile = false

    var body: some View {
        Button {
            showProfile = true
        } label: {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.vqGreen)
                .symbolRenderingMode(.hierarchical)
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showProfile = false }
                                .foregroundStyle(Color.vqGreen)
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .withMockEnvironment()
}
