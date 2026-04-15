import Foundation
import SwiftData
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let api: BuscafondosAPI
    let modelContainer: ModelContainer
    let calculator: PortfolioCalculator

    @Published var lastSync: Date?
    @Published var isSyncing: Bool = false

    init() {
        self.api = BuscafondosAPI()
        do {
            let schema = Schema([AGF.self, Fund.self, FundTransaction.self])
            let config = ModelConfiguration("BuscafondosMenubar", schema: schema)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("No se pudo inicializar SwiftData: \(error)")
        }
        self.calculator = PortfolioCalculator()
    }

    func refreshAll(context: ModelContext) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let funds = try context.fetch(FetchDescriptor<Fund>())
            for fund in funds {
                if let latest = try? await api.latestPrice(realAssetId: fund.realAssetId) {
                    fund.ultimoValorCuota = latest.price
                    fund.ultimoValorCuotaFecha = latest.date
                }
            }
            try context.save()
            lastSync = Date()
        } catch {
            print("refreshAll error: \(error)")
        }
    }
}
