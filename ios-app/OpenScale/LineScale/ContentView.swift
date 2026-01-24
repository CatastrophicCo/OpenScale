import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WeightView()
                .tabItem {
                    Label("Weight", systemImage: "scalemass")
                }
                .tag(0)

            GraphView()
                .tabItem {
                    Label("Graph", systemImage: "chart.xyaxis.line")
                }
                .tag(1)

            SessionView()
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet.clipboard")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(BluetoothManager())
}
