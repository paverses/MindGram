import Foundation

public enum MindGramAccounts {
    public static let hiddenFileName = "mindgram-hidden-accounts.json"

    public static var sharedDirectory: String? {
        didSet {
            self.writeHiddenFile()
        }
    }

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    public static var hidden: Set<Int64> {
        get {
            let values = self.defaults.array(forKey: "MindGram.accounts.hidden") as? [NSNumber] ?? []
            return Set(values.map { $0.int64Value })
        }
        set {
            self.defaults.set(newValue.map { NSNumber(value: $0) }, forKey: "MindGram.accounts.hidden")
            self.writeHiddenFile()
            self.notify()
        }
    }

    public static func isHidden(_ id: Int64) -> Bool {
        return self.hidden.contains(id)
    }

    public static func setHidden(_ id: Int64, _ value: Bool) {
        var hidden = self.hidden
        if value {
            hidden.insert(id)
        } else {
            hidden.remove(id)
        }
        if hidden != self.hidden {
            self.hidden = hidden
        }
    }

    public static var order: [Int64] {
        get {
            let values = self.defaults.array(forKey: "MindGram.accounts.order") as? [NSNumber] ?? []
            return values.map { $0.int64Value }
        }
        set {
            self.defaults.set(newValue.map { NSNumber(value: $0) }, forKey: "MindGram.accounts.order")
            self.notify()
        }
    }

    public static func sorted<T>(_ items: [T], id: (T) -> Int64) -> [T] {
        let order = self.order
        return items.enumerated().sorted { lhs, rhs in
            let lhsIndex = order.firstIndex(of: id(lhs.element)) ?? (order.count + lhs.offset)
            let rhsIndex = order.firstIndex(of: id(rhs.element)) ?? (order.count + rhs.offset)
            return lhsIndex < rhsIndex
        }.map(\.element)
    }

    public static func move(_ id: Int64, by delta: Int, currentIds: [Int64]) {
        var ids = currentIds
        guard let index = ids.firstIndex(of: id) else {
            return
        }
        let target = min(max(index + delta, 0), ids.count - 1)
        if target == index {
            return
        }
        ids.remove(at: index)
        ids.insert(id, at: target)
        var order = self.order.filter { !ids.contains($0) }
        order.insert(contentsOf: ids, at: 0)
        self.order = order
    }

    private static func writeHiddenFile() {
        guard let directory = self.sharedDirectory else {
            return
        }
        let url = URL(fileURLWithPath: directory).appendingPathComponent(self.hiddenFileName)
        if let data = try? JSONSerialization.data(withJSONObject: Array(self.hidden).map { NSNumber(value: $0) }) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func notify() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
            }
        }
    }
}
