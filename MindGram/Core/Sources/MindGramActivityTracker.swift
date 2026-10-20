import Foundation

/// Remembers when MindGram last saw a user being active: a message from them, or them typing.
///
/// People who hide their last seen time show up as "last seen recently" with no time at all. MindGram
/// fills that gap with the last moment it observed them itself, shown as an approximate time.
public enum MindGramActivityTracker {
    private static let storageKey = "MindGram.lastActivity"
    private static let maxEntries = 3000
    private static let lock = NSLock()
    private static var loaded = false
    private static var entries: [Int64: Int32] = [:]
    private static var savePending = false

    public static func record(userId: Int64, timestamp: Int32) {
        self.lock.lock()
        self.loadIfNeeded()
        if let current = self.entries[userId], current >= timestamp {
            self.lock.unlock()
            return
        }
        self.entries[userId] = timestamp
        if self.entries.count > self.maxEntries {
            let oldest = self.entries.sorted(by: { $0.value < $1.value }).prefix(self.entries.count - self.maxEntries)
            for (key, _) in oldest {
                self.entries.removeValue(forKey: key)
            }
        }
        let shouldSchedule = !self.savePending
        self.savePending = true
        self.lock.unlock()

        if shouldSchedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.save()
            }
        }
    }

    public static func lastActivity(userId: Int64) -> Int32? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        self.loadIfNeeded()
        return self.entries[userId]
    }

    /// "≈ 12:43" (or "≈ 19 окт. 12:43" for an earlier day) when "Время у «был(а) недавно»" is on and the
    /// user was seen active; nil otherwise.
    public static func approximateText(userId: Int64, languageCode: String) -> String? {
        guard MindGramSettings.isOn(.approximateLastSeen), let timestamp = self.lastActivity(userId: userId) else {
            return nil
        }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode.isEmpty ? "en" : languageCode)
        formatter.setLocalizedDateFormatFromTemplate(Calendar.current.isDateInToday(date) ? "HHmm" : "dMMMHHmm")
        return "≈ " + formatter.string(from: date)
    }

    private static func loadIfNeeded() {
        if self.loaded {
            return
        }
        self.loaded = true
        if let stored = UserDefaults.standard.dictionary(forKey: self.storageKey) {
            for (key, value) in stored {
                if let id = Int64(key), let timestamp = value as? Int {
                    self.entries[id] = Int32(clamping: timestamp)
                }
            }
        }
    }

    private static func save() {
        self.lock.lock()
        self.savePending = false
        var stored: [String: Int] = [:]
        for (key, value) in self.entries {
            stored[String(key)] = Int(value)
        }
        self.lock.unlock()
        UserDefaults.standard.set(stored, forKey: self.storageKey)
    }
}
