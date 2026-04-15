import Foundation
import SwiftData

@Model
final class Fund {
    @Attribute(.unique) var realAssetId: String
    var conceptId: String
    var run: String
    var nombre: String
    var serie: String
    var categoria: String?

    var ultimoValorCuota: Decimal
    var ultimoValorCuotaFecha: Date
    var tacAnual: Decimal?

    var agf: AGF?

    @Relationship(deleteRule: .cascade, inverse: \FundTransaction.fund)
    var transacciones: [FundTransaction] = []

    init(
        realAssetId: String,
        conceptId: String,
        run: String,
        nombre: String,
        serie: String,
        categoria: String? = nil,
        ultimoValorCuota: Decimal = 0,
        ultimoValorCuotaFecha: Date = .distantPast,
        tacAnual: Decimal? = nil,
        agf: AGF? = nil
    ) {
        self.realAssetId = realAssetId
        self.conceptId = conceptId
        self.run = run
        self.nombre = nombre
        self.serie = serie
        self.categoria = categoria
        self.ultimoValorCuota = ultimoValorCuota
        self.ultimoValorCuotaFecha = ultimoValorCuotaFecha
        self.tacAnual = tacAnual
        self.agf = agf
    }
}
