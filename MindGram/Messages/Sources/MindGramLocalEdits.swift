import Foundation

/// «Изменить локально»: a message's text replaced on this device only. Nothing is sent, so the message gets no
/// "edited" mark and others still see the original.
public enum MindGramLocalEdits {
    private struct Entry: Codable {
        var key: MindGramMessageKey
        var text: String
    }

    private static let file = MindGramJSONFile<[Entry]>(name: "localedits", defaultValue: [])
    private static let lock = NSLock()
    private static var cache: [MindGramMessageKey: String]?

    private static func loaded() -> [MindGramMessageKey: String] {
        if let cache = self.cache {
            return cache
        }
        let value = self.file.read { entries in
            Dictionary(entries.map { ($0.key, $0.text) }, uniquingKeysWith: { _, last in last })
        }
        self.cache = value
        return value
    }

    /// The local text of a message, nil when it has none. Called while chat messages lay out.
    public static func text(_ key: MindGramMessageKey) -> String? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.loaded()[key]
    }

    /// Sets the local text; nil or an empty text removes it.
    public static func set(_ key: MindGramMessageKey, text: String?) {
        self.lock.lock()
        var value = self.loaded()
        if let text, !text.isEmpty {
            value[key] = text
        } else {
            value.removeValue(forKey: key)
        }
        self.cache = value
        self.lock.unlock()
        self.file.modify { entries in
            entries = value.map { Entry(key: $0.key, text: $0.value) }
        }
        mindGramNotifyChanged()
    }
}

/// «Визуальный юзернейм» and «Визуальное описание»: what this device shows instead of a profile's @username and
/// bio (or a channel's description). Only the view changes; nothing is sent.
public enum MindGramVisualProfile {
    private struct Entry: Codable {
        var peerId: Int64
        var username: String?
        var about: String?
    }

    private static let file = MindGramJSONFile<[Entry]>(name: "visualprofile", defaultValue: [])
    private static let lock = NSLock()
    private static var cache: [Int64: Entry]?

    private static func loaded() -> [Int64: Entry] {
        if let cache = self.cache {
            return cache
        }
        let value = self.file.read { entries in
            Dictionary(entries.map { ($0.peerId, $0) }, uniquingKeysWith: { _, last in last })
        }
        self.cache = value
        return value
    }

    /// The username to show (without "@"), nil to show the real one.
    public static func username(peerId: Int64) -> String? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.loaded()[peerId]?.username
    }

    /// The bio or description to show, nil to show the real one.
    public static func about(peerId: Int64) -> String? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.loaded()[peerId]?.about
    }

    public static func setUsername(peerId: Int64, _ username: String?) {
        self.update(peerId: peerId, { entry in
            let value = username?.trimmingCharacters(in: CharacterSet(charactersIn: "@ ").union(.whitespacesAndNewlines))
            entry.username = (value?.isEmpty ?? true) ? nil : value
        })
    }

    public static func setAbout(peerId: Int64, _ about: String?) {
        self.update(peerId: peerId, { entry in
            entry.about = (about?.isEmpty ?? true) ? nil : about
        })
    }

    private static func update(peerId: Int64, _ f: (inout Entry) -> Void) {
        self.lock.lock()
        var value = self.loaded()
        var entry = value[peerId] ?? Entry(peerId: peerId, username: nil, about: nil)
        f(&entry)
        if entry.username == nil && entry.about == nil {
            value.removeValue(forKey: peerId)
        } else {
            value[peerId] = entry
        }
        self.cache = value
        self.lock.unlock()
        self.file.modify { entries in
            entries = Array(value.values)
        }
        mindGramNotifyChanged()
    }
}
