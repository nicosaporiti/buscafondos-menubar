import SwiftUI
import SwiftData
import AppKit

struct RootView: View {
    let isWindowMode: Bool
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @State private var selected: AppTab = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                onRefresh: refresh,
                onExpand: isWindowMode ? nil : openMainWindow
            )

            ZStack(alignment: .top) {
                // Keep all tabs alive so state (scroll, loaded data, form inputs) persists.
                DashboardView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(selected == .dashboard ? 1 : 0)
                    .allowsHitTesting(selected == .dashboard)
                FundsListView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(selected == .fondos ? 1 : 0)
                    .allowsHitTesting(selected == .fondos)
                TransactionFormView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(selected == .carga ? 1 : 0)
                    .allowsHitTesting(selected == .carga)
                EvolutionView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(selected == .evolucion ? 1 : 0)
                    .allowsHitTesting(selected == .evolucion)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.surface)

            BottomNavBar(selected: $selected)
        }
        .background(Palette.surface)
        .task {
            await env.refreshAll(context: context)
        }
    }

    private func refresh() {
        Task { await env.refreshAll(context: context) }
    }

    private func openMainWindow() {
        // LSUIElement apps start as .accessory — they need an explicit activate
        // for a newly opened window to actually come forward.
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
