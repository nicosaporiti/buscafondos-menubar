import SwiftUI
import SwiftData

@main
struct BuscafondosMenubarApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        MenuBarExtra {
            RootView(isWindowMode: false)
                .environmentObject(environment)
                .modelContainer(environment.modelContainer)
                .frame(width: 360, height: 520)
        } label: {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
        }
        .menuBarExtraStyle(.window)

        Window("Buscafondos", id: "main") {
            RootView(isWindowMode: true)
                .environmentObject(environment)
                .modelContainer(environment.modelContainer)
                .frame(minWidth: 720, minHeight: 560)
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
    }
}
