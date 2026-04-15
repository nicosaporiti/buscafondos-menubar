import Foundation

struct Holding: Identifiable, Hashable {
    var id: String { fundId }
    let fundId: String
    let nombre: String
    let agfNombre: String
    let cuotasNetas: Decimal
    let valorActual: Decimal
    let costoBase: Decimal
    let ultimoValorCuota: Decimal

    var retornoAbs: Decimal { valorActual - costoBase }
    var retornoPct: Double {
        guard costoBase > 0 else { return 0 }
        let num = (valorActual - costoBase) as NSDecimalNumber
        let den = costoBase as NSDecimalNumber
        return num.doubleValue / den.doubleValue
    }
}

struct PortfolioSnapshot {
    let total: Decimal
    let costoBase: Decimal
    let retornoAbs: Decimal
    let retornoPct: Double
    let holdings: [Holding]
    // Deltas
    let today: Decimal
    let mtd: Decimal
    let lastMonth: Decimal
    let ytd: Decimal
}

final class PortfolioCalculator {
    func snapshot(from funds: [Fund]) -> PortfolioSnapshot {
        var holdings: [Holding] = []
        var total: Decimal = 0
        var base: Decimal = 0

        for fund in funds {
            let txs = fund.transacciones.sorted { $0.fecha < $1.fecha }
            var cuotasNetas: Decimal = 0
            var costo: Decimal = 0
            for tx in txs {
                if tx.tipo == .aporte {
                    costo += tx.cuotas * tx.valorCuota
                    cuotasNetas += tx.cuotas
                } else {
                    // tx.cuotas es negativo; reducir el costo base proporcionalmente
                    // a las cuotas rescatadas sobre las cuotas vigentes (método costo promedio).
                    if cuotasNetas > 0 {
                        let fraccion = min(Decimal(1), (-tx.cuotas) / cuotasNetas)
                        costo -= costo * fraccion
                    }
                    cuotasNetas += tx.cuotas
                    if cuotasNetas <= 0 {
                        cuotasNetas = 0
                        costo = 0
                    }
                }
            }
            guard cuotasNetas > 0 else { continue }
            let valor = cuotasNetas * fund.ultimoValorCuota
            total += valor
            base += costo
            holdings.append(Holding(
                fundId: fund.realAssetId,
                nombre: fund.nombre,
                agfNombre: fund.agf?.nombre ?? "—",
                cuotasNetas: cuotasNetas,
                valorActual: valor,
                costoBase: costo,
                ultimoValorCuota: fund.ultimoValorCuota
            ))
        }

        holdings.sort { $0.valorActual > $1.valorActual }
        let retornoAbs = total - base
        let retornoPct: Double = {
            guard base > 0 else { return 0 }
            let n = (total - base) as NSDecimalNumber
            let d = base as NSDecimalNumber
            return n.doubleValue / d.doubleValue
        }()

        // TODO: compute real deltas with historical NAVs once FundSyncService stores them.
        // For v1 placeholder values are 0 so the UI stays honest.
        return PortfolioSnapshot(
            total: total,
            costoBase: base,
            retornoAbs: retornoAbs,
            retornoPct: retornoPct,
            holdings: holdings,
            today: 0,
            mtd: 0,
            lastMonth: 0,
            ytd: 0
        )
    }
}
