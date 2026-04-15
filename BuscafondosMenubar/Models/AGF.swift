import Foundation
import SwiftData

@Model
final class AGF {
    @Attribute(.unique) var providerId: String
    var nombre: String
    var colorSeed: Int // for leading color chip

    @Relationship(deleteRule: .cascade, inverse: \Fund.agf)
    var funds: [Fund] = []

    init(providerId: String, nombre: String, colorSeed: Int = 0) {
        self.providerId = providerId
        self.nombre = nombre
        self.colorSeed = colorSeed
    }
}
