import Foundation

public enum MindGramBetaTesters {
    private static let url = URL(string: "https://raw.githubusercontent.com/paverses/MindGram/main/MindGram/Bot/palette.json")!
    private static let cacheKey = "MindGram.palette.cache"
    private static let revisionKey = "MindGram.palette.rev"
    private static let lock = NSLock()
    private static var loadedIds: Set<Int64>?
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

    public static var ids: Set<Int64> {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let loadedIds = self.loadedIds {
            return loadedIds
        }
        let values = UserDefaults.standard.array(forKey: self.cacheKey) as? [NSNumber] ?? []
        let result = Set(values.map { $0.int64Value })
        self.loadedIds = result
        return result
    }

    public static func isBetaTester(_ userId: Int64) -> Bool {
        return self.showsStatus && self.ids.contains(userId)
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

    private static func refresh() {
        var request = URLRequest(url: self.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20.0)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data, (response as? HTTPURLResponse)?.statusCode == 200, let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let tones = root["tones"] as? [Any] else {
                return
            }
            let ids = Set(tones.compactMap { value -> Int64? in
                if let number = value as? NSNumber {
                    return number.int64Value
                }
                if let string = value as? String {
                    return Int64(string)
                }
                return nil
            })
            if let revision = root["rev"] as? NSNumber {
                UserDefaults.standard.set(revision.int64Value, forKey: self.revisionKey)
            }
            self.lock.lock()
            let changed = self.loadedIds != ids
            self.loadedIds = ids
            self.lock.unlock()
            if changed {
                UserDefaults.standard.set(ids.map { NSNumber(value: $0) }, forKey: self.cacheKey)
                self.notify()
            }
        }.resume()
    }

    private static func notify() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
        }
    }
}
