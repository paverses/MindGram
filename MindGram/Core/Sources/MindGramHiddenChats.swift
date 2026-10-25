import Foundation

public enum MindGramHiddenChats {
    private static let key = "MindGram.hiddenChats"

    public static var ids: Set<Int64> {
        get {
            let values = UserDefaults.standard.array(forKey: self.key) as? [NSNumber] ?? []
            return Set(values.map { $0.int64Value })
        }
        set {
            UserDefaults.standard.set(newValue.map { NSNumber(value: $0) }, forKey: self.key)
            NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
        }
    }

    public static func isHidden(_ peerId: Int64) -> Bool {
        return self.ids.contains(peerId)
    }

    public static func setHidden(_ peerId: Int64, _ value: Bool) {
        var ids = self.ids
        if value {
            ids.insert(peerId)
        } else {
            ids.remove(peerId)
        }
        self.ids = ids
    }
}
