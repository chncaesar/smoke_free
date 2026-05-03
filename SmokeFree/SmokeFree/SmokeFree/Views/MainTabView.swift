import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("首页", systemImage: "house.fill") }

            LoggingView()
                .tabItem { Label("记录", systemImage: "pencil.circle.fill") }

            ProgressTabView()
                .tabItem { Label("进度", systemImage: "chart.bar.fill") }

            GoalsView()
                .tabItem { Label("目标", systemImage: "target") }

            PurchasesView()
                .tabItem { Label("购烟", systemImage: "cart.fill") }
        }
        .tint(.green)
    }
}
