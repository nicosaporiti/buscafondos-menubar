import Foundation
import SwiftData

enum TransactionTipo: String, Codable, CaseIterable, Identifiable {
    case aporte
    case rescate
    var id: String { rawValue }
    var label: String { self == .aporte ? "Aporte" : "Rescate" }
}

@Model
final class FundTransaction {
    var fecha: Date
    var tipoRaw: String
    var valorCuota: Decimal
    var cuotas: Decimal          // signed: aporte positive, rescate negative
    var montoCLP: Decimal        // cached = cuotas * valorCuota

    var fund: Fund?

    var tipo: TransactionTipo {
        get { TransactionTipo(rawValue: tipoRaw) ?? .aporte }
        set { tipoRaw = newValue.rawValue }
    }

    init(
        fecha: Date,
        tipo: TransactionTipo,
        valorCuota: Decimal,
        cuotas: Decimal,
        fund: Fund? = nil
    ) {
        self.fecha = fecha
        self.tipoRaw = tipo.rawValue
        self.valorCuota = valorCuota
        let signed: Decimal = tipo == .aporte ? abs(cuotas) : -abs(cuotas)
        self.cuotas = signed
        self.montoCLP = signed * valorCuota
        self.fund = fund
    }
}
