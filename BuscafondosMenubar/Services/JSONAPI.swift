import Foundation

// Minimal JSON:API envelope helpers for endpoints returning { data: ... }.

struct JSONAPISingle<Attrs: Decodable>: Decodable {
    let data: Resource<Attrs>
}

struct JSONAPIList<Attrs: Decodable>: Decodable {
    let data: [Resource<Attrs>]
}

struct Resource<Attrs: Decodable>: Decodable {
    let id: String
    let type: String
    let attributes: Attrs
}
