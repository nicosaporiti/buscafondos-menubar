import Foundation

// MARK: - DTOs mirroring the Buscafondos (CMF) API responses.

struct HealthDTO: Decodable {
    let status: String
    let last_scraped_date: String
    let total_records: Int
}

struct AssetProviderAttrs: Decodable {
    let name: String
}

struct ConceptualAssetAttrs: Decodable {
    let name: String
    let symbol: String?
    let run: String
    let category: String?
    let currency: String?
}

struct RealAssetAttrs: Decodable {
    let name: String
    let serie: String
    let run: String
    let currency: String?
    let investor_class: String?
    let last_day: LastDay?

    struct LastDay: Decodable {
        let net_asset_value: Double
        let total_net_assets: Double?
        let shareholders: Int?
        let date: String
    }
}

struct RealAssetDayAttrs: Decodable {
    let date: String
    let price: Double
}

struct ExpenseRatioAttrs: Decodable {
    let expense_ratio: Double
    let investor_class: String?
}

// `/all-funds` is a flat array (NOT JSON:API format).
struct AllFundItem: Codable, Identifiable, Hashable {
    let agf: String
    let fundName: String
    let fundId: String
    let run: String
    let category: String?
    let serie: String
    let serieId: String
    let currency: String?
    let tac: Double?
    let investorClass: String?
    let dailyChange: Double?
    let monthlyChange: Double?
    let patrimony: Double?
    let shareholders: Int?

    var id: String { serieId }
}

struct AllFundsResponse: Codable {
    let data: [AllFundItem]
}

// MARK: - Aggregated value types returned to the rest of the app.

struct PricePoint: Hashable {
    let date: Date
    let price: Decimal
}

// MARK: - Client

enum APIError: Error, LocalizedError {
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "HTTP \(code)"
        case .decoding(let err):   return "Decoding: \(err.localizedDescription)"
        case .transport(let err):  return "Red: \(err.localizedDescription)"
        }
    }
}

actor BuscafondosAPI {
    private let base = URL(string: "https://api.buscafondos.com")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let isoDate: DateFormatter

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.isoDate = DateFormatter()
        self.isoDate.locale = Locale(identifier: "en_US_POSIX")
        self.isoDate.timeZone = TimeZone(identifier: "America/Santiago")
        self.isoDate.dateFormat = "yyyy-MM-dd"
    }

    // MARK: Raw fetch

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.badStatus(-1) }
            guard (200..<300).contains(http.statusCode) else { throw APIError.badStatus(http.statusCode) }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.transport(error)
        }
    }

    // MARK: Endpoints

    func health() async throws -> HealthDTO {
        try await get("health")
    }

    func assetProviders() async throws -> [Resource<AssetProviderAttrs>] {
        let resp: JSONAPIList<AssetProviderAttrs> = try await get("api/asset_providers")
        return resp.data
    }

    func conceptualAssets(providerId: String) async throws -> [Resource<ConceptualAssetAttrs>] {
        let resp: JSONAPIList<ConceptualAssetAttrs> = try await get("api/asset_providers/\(providerId)/conceptual_assets")
        return resp.data
    }

    func realAssets(conceptId: String) async throws -> [Resource<RealAssetAttrs>] {
        let resp: JSONAPIList<RealAssetAttrs> = try await get("api/conceptual_assets/\(conceptId)/real_assets")
        return resp.data
    }

    func priceHistory(realAssetId: String, from: Date? = nil, to: Date? = nil) async throws -> [PricePoint] {
        var qs: [URLQueryItem] = []
        if let from { qs.append(.init(name: "from", value: isoDate.string(from: from))) }
        if let to   { qs.append(.init(name: "to",   value: isoDate.string(from: to))) }
        let resp: JSONAPIList<RealAssetDayAttrs> = try await get("api/real_assets/\(realAssetId)/days", query: qs)
        return resp.data.compactMap { r in
            guard let d = isoDate.date(from: r.attributes.date) else { return nil }
            return PricePoint(date: d, price: Decimal(r.attributes.price))
        }.sorted { $0.date < $1.date }
    }

    func latestPrice(realAssetId: String) async throws -> PricePoint? {
        // Ask for the last ~10 days to be safe, then pick the max.
        let to = Date()
        let from = Calendar(identifier: .gregorian).date(byAdding: .day, value: -10, to: to) ?? to
        let history = try await priceHistory(realAssetId: realAssetId, from: from, to: to)
        return history.last
    }

    func expenseRatio(realAssetId: String) async throws -> Decimal {
        let resp: JSONAPISingle<ExpenseRatioAttrs> = try await get("api/real_assets/\(realAssetId)/expense_ratio")
        return Decimal(resp.data.attributes.expense_ratio)
    }

    func allFunds(category: String? = nil, useCache: Bool = true) async throws -> [AllFundItem] {
        let cacheKey = "all-funds" + (category.map { "?cat=\($0)" } ?? "")
        if useCache, let cached = await DiskCache.shared.load([AllFundItem].self, key: cacheKey, ttl: 24 * 60 * 60) {
            return cached
        }
        var qs: [URLQueryItem] = []
        if let category { qs.append(.init(name: "category", value: category)) }
        let resp: AllFundsResponse = try await get("api/all-funds", query: qs)
        await DiskCache.shared.store(resp.data, key: cacheKey)
        return resp.data
    }
}
