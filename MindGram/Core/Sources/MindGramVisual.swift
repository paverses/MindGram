import Foundation

public enum MindGramVisual {
    public struct Values: Codable, Equatable {
        public var phone: String?
        public var stars: String?
        public var gram: String?
        public var ratingLevel: Int32?
        public var ratingPoints: Int64?
        public var ratingNextPoints: Int64?

        public init() {
        }

        public var isEmpty: Bool {
            return self.phone == nil && self.stars == nil && self.gram == nil && self.ratingLevel == nil && self.ratingPoints == nil && self.ratingNextPoints == nil
        }

        public var hasRating: Bool {
            return self.ratingLevel != nil || self.ratingPoints != nil
        }
    }

    private static let lock = NSLock()
    private static var cache: [Int64: Values]?

    private static func key(_ peerId: Int64) -> String {
        return "MindGram.visual.\(peerId)"
    }

    public static func values(peerId: Int64) -> Values {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let value = self.cache?[peerId] {
            return value
        }
        var result = Values()
        if let data = UserDefaults.standard.data(forKey: self.key(peerId)), let decoded = try? JSONDecoder().decode(Values.self, from: data) {
            result = decoded
        }
        if self.cache == nil {
            self.cache = [:]
        }
        self.cache?[peerId] = result
        return result
    }

    public static func update(peerId: Int64, _ f: (inout Values) -> Void) {
        var value = self.values(peerId: peerId)
        f(&value)
        self.lock.lock()
        self.cache?[peerId] = value
        self.lock.unlock()
        if value.isEmpty {
            UserDefaults.standard.removeObject(forKey: self.key(peerId))
        } else if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: self.key(peerId))
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
        }
    }

    public static func phone(peerId: Int64) -> String? {
        return self.values(peerId: peerId).phone
    }

    public static func cleaned(_ text: String?) -> String? {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
}
