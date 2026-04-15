import Foundation

// Simple TTL-based disk cache in Application Support.
actor DiskCache {
    static let shared = DiskCache()

    private let root: URL

    init() {
        let fm = FileManager.default
        let support = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = support.appendingPathComponent("BuscafondosMenubar/cache", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.root = dir
    }

    private func url(for key: String) -> URL {
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return root.appendingPathComponent("\(safe).json")
    }

    func load<T: Decodable>(_ type: T.Type, key: String, ttl: TimeInterval) -> T? {
        let file = url(for: key)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
              let mtime = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(mtime) < ttl,
              let data = try? Data(contentsOf: file),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else { return nil }
        return value
    }

    func store<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }

    func invalidate(key: String) {
        try? FileManager.default.removeItem(at: url(for: key))
    }
}
