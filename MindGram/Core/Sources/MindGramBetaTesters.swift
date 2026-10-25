import Foundation

public enum MindGramBetaTesters {
    public struct Member: Equatable {
        public let id: Int64
        public let username: String?
        public let name: String?
        public let build: Int?
        public let date: String?
    }

    public struct Palette: Equatable {
        public var beta: Set<Int64> = []
        public var blocked: Set<Int64> = []
        public var marks: [Int64: String] = [:]
        public var members: [Member] = []
    }

    public enum Access {
        case allowed
        case notBetaTester
        case blocked
    }

    private static let url = URL(string: "https://raw.githubusercontent.com/paverses/MindGram/main/MindGram/Bot/palette.json")!
    private static let cacheKey = "MindGram.palette.data"
    private static let lock = NSLock()
    private static var loaded: Palette?
    private static var timer: DispatchSourceTimer?
    private static let queue = DispatchQueue(label: "MindGram.palette", qos: .utility)

    public static var showsStatus: Bool {
        get {
            return UserDefaults.standard.object(forKey: "MindGram.palette.show") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "MindGram.palette.show")
            self.notify()
        }
    }

    public static var palette: Palette {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let loaded = self.loaded {
            return loaded
        }
        let result = UserDefaults.standard.data(forKey: self.cacheKey).flatMap { self.parse($0) } ?? Palette()
        self.loaded = result
        return result
    }

    public static var ids: Set<Int64> {
        return self.palette.beta
    }

    public static func isBetaTester(_ userId: Int64) -> Bool {
        return self.showsStatus && self.palette.beta.contains(userId)
    }

    public static func remoteMark(_ userId: Int64) -> String? {
        return self.palette.marks[userId]
    }

    public static func start() {
        self.queue.async {
            if self.timer != nil {
                return
            }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 60.0, leeway: .seconds(5))
            timer.setEventHandler {
                self.refresh()
            }
            self.timer = timer
            timer.resume()
        }
    }

    public static func reload(completion: @escaping () -> Void) {
        self.refresh(completion: { _ in
            DispatchQueue.main.async {
                completion()
            }
        })
    }

    public static func access(userId: Int64, requiresBeta: Bool, completion: @escaping (Access) -> Void) {
        self.refresh(completion: { fresh in
            let palette = fresh ?? self.palette
            let result: Access
            if palette.blocked.contains(userId) {
                result = .blocked
            } else if requiresBeta && !palette.beta.contains(userId) {
                result = .notBetaTester
            } else {
                result = .allowed
            }
            DispatchQueue.main.async {
                completion(result)
            }
        })
    }

    public static func applyLocally(_ f: (inout Palette) -> Void) {
        self.lock.lock()
        var value = self.loaded ?? Palette()
        f(&value)
        self.loaded = value
        self.lock.unlock()
        self.notify()
    }

    private static func ids(_ value: Any?) -> Set<Int64> {
        guard let array = value as? [Any] else {
            return []
        }
        return Set(array.compactMap { item -> Int64? in
            if let number = item as? NSNumber {
                return number.int64Value
            }
            if let string = item as? String {
                return Int64(string)
            }
            return nil
        })
    }

    private static func parse(_ data: Data) -> Palette? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], root["tones"] != nil else {
            return nil
        }
        var palette = Palette()
        palette.beta = self.ids(root["tones"])
        palette.blocked = self.ids(root["muted"])
        if let marks = root["accents"] as? [String: String] {
            for (key, value) in marks {
                if let id = Int64(key) {
                    palette.marks[id] = value
                }
            }
        }
        if let members = root["swatches"] as? [[String: Any]] {
            palette.members = members.compactMap { item in
                guard let id = (item["i"] as? NSNumber)?.int64Value else {
                    return nil
                }
                return Member(id: id, username: item["u"] as? String, name: item["n"] as? String, build: (item["b"] as? NSNumber)?.intValue, date: item["t"] as? String)
            }
        }
        return palette
    }

    private static func refresh(completion: ((Palette?) -> Void)? = nil) {
        var request = URLRequest(url: self.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20.0)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data, (response as? HTTPURLResponse)?.statusCode == 200, let palette = self.parse(data) else {
                completion?(nil)
                return
            }
            self.lock.lock()
            let changed = self.loaded != palette
            self.loaded = palette
            self.lock.unlock()
            if changed {
                UserDefaults.standard.set(data, forKey: self.cacheKey)
                self.notify()
            }
            completion?(palette)
        }.resume()
    }

    private static func notify() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
        }
    }
}
