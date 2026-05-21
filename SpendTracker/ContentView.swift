import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.pie.fill")
                    }

                TransactionListView()
                    .tabItem {
                        Label("Transactions", systemImage: "list.bullet.rectangle")
                    }

                DebugView()
                    .tabItem {
                        Label("Debug", systemImage: "ant.fill")
                    }
            }

            // Clipboard monitor sits invisibly over everything
            ClipboardMonitorView()
        }
    }
}
