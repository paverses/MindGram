import Foundation

/// Saved deleted messages. When the server says a message was deleted, TelegramCore asks `shouldKeep`;
/// a kept message stays in the chat (marked) and gets a record here for the history screen.
public enum MindGramDeleted {
    /// One deleted message, as it looked when it was deleted.
    public struct Record: Codable, Equatable {
        public let key: MindGramMessageKey
        public let chatKind: MindGramChatKind
        public let chatTitle: String
        public let author: String
        /// The author's PeerId.toInt64(), for the avatar and the profile; nil in records from older builds.
        public let authorId: Int64?
        public let text: String
        /// "Фото", "Голосовое"... for messages with media, empty otherwise.
        public let media: String
        public let isOutgoing: Bool
        /// When the message was sent (unix time).
        public let date: Int32
        /// When MindGram saw it deleted (unix time).
        public let deletedAt: Int32

        public init(key: MindGramMessageKey, chatKind: MindGramChatKind, chatTitle: String, author: String, authorId: Int64?, text: String, media: String, isOutgoing: Bool, date: Int32, deletedAt: Int32) {
            self.key = key
            self.chatKind = chatKind
            self.chatTitle = chatTitle
            self.author = author
            self.authorId = authorId
            self.text = text
            self.media = media
            self.isOutgoing = isOutgoing
            self.date = date
            self.deletedAt = deletedAt
        }
    }

    /// How a deleted message is marked next to its time.
    public enum Mark: String, CaseIterable {
        case trash
        case cross
        case ghost
        case prohibited
        case word

        public var prefix: String {
            switch self {
            case .trash:
                return "🗑"
            case .cross:
                return "✕"
            case .ghost:
                return "👻"
            case .prohibited:
                return "⊘"
            case .word:
                return ""
            }
        }
    }

    private static let file = MindGramJSONFile<[Record]>(name: "deleted", defaultValue: [])
    private static let maxRecords = 5000
    private static let lock = NSLock()
    private static var cachedKeys: Set<MindGramMessageKey>?

    // MARK: Settings

    public static var isEnabled: Bool {
        get { return MindGramDefaults.bool("MindGram.deleted.enabled", default: true) }
        set { MindGramDefaults.setBool("MindGram.deleted.enabled", newValue) }
    }

    public static func saves(_ kind: MindGramChatKind) -> Bool {
        return MindGramDefaults.bool("MindGram.deleted.save.\(kind.rawValue)", default: true)
    }

    public static func setSaves(_ kind: MindGramChatKind, _ value: Bool) {
        MindGramDefaults.setBool("MindGram.deleted.save.\(kind.rawValue)", value)
    }

    /// Keep own messages deleted from another device too.
    public static var savesOwnMessages: Bool {
        get { return MindGramDefaults.bool("MindGram.deleted.own", default: false) }
        set { MindGramDefaults.setBool("MindGram.deleted.own", newValue) }
    }

    /// Show kept messages in the chat; when off they are only in the history screen.
    public static var showsInChat: Bool {
        get { return MindGramDefaults.bool("MindGram.deleted.showInChat", default: true) }
        set { MindGramDefaults.setBool("MindGram.deleted.showInChat", newValue) }
    }

    /// The mark is always the trash icon (drawn in the chosen colour); the other marks were removed.
    public static var mark: Mark {
        get { return .trash }
        set { MindGramDefaults.setString("MindGram.deleted.mark", newValue.rawValue) }
    }

    /// Also write "удалено" next to the time.
    public static var showsWord: Bool {
        get { return MindGramDefaults.bool("MindGram.deleted.word", default: false) }
        set { MindGramDefaults.setBool("MindGram.deleted.word", newValue) }
    }

    /// Color of the mark (and "удалено") from the palette, as "#FF3B30"; empty means the time's own color.
    public static var markColor: String {
        get { return MindGramDefaults.string("MindGram.deleted.markColor", default: "") }
        set { MindGramDefaults.setString("MindGram.deleted.markColor", newValue) }
    }

    /// Size of the mark relative to the time, percent (70–200).
    public static var markScalePercent: Int {
        get { return max(70, min(200, MindGramDefaults.int("MindGram.deleted.markScale", default: 100))) }
        set { MindGramDefaults.setInt("MindGram.deleted.markScale", newValue) }
    }

    /// Opacity of a kept deleted message in the chat, percent (20–100).
    public static var opacityPercent: Int {
        get { return max(20, min(100, MindGramDefaults.int("MindGram.deleted.opacity", default: 100))) }
        set { MindGramDefaults.setInt("MindGram.deleted.opacity", newValue) }
    }

    /// RGB components 0...1 of `markColor`, nil when it is empty or unreadable.
    public static func parsedMarkColor() -> (red: Double, green: Double, blue: Double)? {
        let text = self.markColor.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            return nil
        }
        let parts = text.components(separatedBy: CharacterSet(charactersIn: ",; ")).filter { !$0.isEmpty }
        if parts.count == 3, let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) {
            return (min(255.0, r) / 255.0, min(255.0, g) / 255.0, min(255.0, b) / 255.0)
        }
        var hex = text.replacingOccurrences(of: "#", with: "")
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            return nil
        }
        return (Double((value >> 16) & 0xFF) / 255.0, Double((value >> 8) & 0xFF) / 255.0, Double(value & 0xFF) / 255.0)
    }

    // MARK: Store

    /// Whether TelegramCore should keep this message instead of deleting it.
    public static func shouldKeep(kind: MindGramChatKind, isOutgoing: Bool) -> Bool {
        guard self.isEnabled, self.saves(kind) else {
            return false
        }
        if isOutgoing && !self.savesOwnMessages {
            return false
        }
        return true
    }

    public static func add(_ record: Record) {
        self.file.modify { records in
            records.removeAll(where: { $0.key == record.key })
            records.append(record)
            if records.count > self.maxRecords {
                records.removeFirst(records.count - self.maxRecords)
            }
        }
        self.lock.lock()
        self.cachedKeys?.insert(record.key)
        self.lock.unlock()
        mindGramNotifyChanged()
    }

    /// Whether this message was deleted on the server and kept by MindGram.
    public static func isDeleted(_ key: MindGramMessageKey) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if self.previewKeys.contains(key) {
            return true
        }
        if self.cachedKeys == nil {
            self.cachedKeys = self.file.read { Set($0.map(\.key)) }
        }
        return self.cachedKeys?.contains(key) ?? false
    }

    /// Messages of a settings preview drawn as deleted (they are not real messages).
    private static var previewKeys: Set<MindGramMessageKey> = []

    public static func addPreviewKey(_ key: MindGramMessageKey) {
        self.lock.lock()
        self.previewKeys.insert(key)
        self.lock.unlock()
    }

    /// All records, newest deletion first.
    public static var records: [Record] {
        return self.file.read { $0.reversed() }
    }

    public static func remove(_ key: MindGramMessageKey) {
        self.file.modify { records in
            records.removeAll(where: { $0.key == key })
        }
        self.lock.lock()
        self.cachedKeys?.remove(key)
        self.lock.unlock()
        mindGramNotifyChanged()
    }

    public static func clear() {
        self.file.modify { records in
            records.removeAll()
        }
        self.lock.lock()
        self.cachedKeys = []
        self.lock.unlock()
        mindGramNotifyChanged()
    }

    /// The text put before a deleted message's time: the mark, and "удалено" when chosen.
    public static func timestampPrefix(isRussian: Bool) -> String {
        var parts: [String] = []
        let mark = self.mark
        if !mark.prefix.isEmpty {
            parts.append(mark.prefix)
        }
        if mark == .word || self.showsWord {
            parts.append(isRussian ? "удалено" : "deleted")
        }
        return parts.joined(separator: " ")
    }
}

/// Edit history: every earlier text of an edited message.
public enum MindGramEdits {
    public struct Version: Codable, Equatable {
        public let text: String
        /// When this text became the message's text (unix time).
        public let date: Int32

        public init(text: String, date: Int32) {
            self.text = text
            self.date = date
        }
    }

    private struct Entry: Codable {
        var key: MindGramMessageKey
        var versions: [Version]
    }

    private static let file = MindGramJSONFile<[Entry]>(name: "edits", defaultValue: [])
    private static let maxEntries = 3000

    public static var isEnabled: Bool {
        get { return MindGramDefaults.bool("MindGram.edits.enabled", default: true) }
        set { MindGramDefaults.setBool("MindGram.edits.enabled", newValue) }
    }

    /// Records the text a message had before an edit.
    public static func record(_ key: MindGramMessageKey, previousText: String, previousDate: Int32) {
        guard self.isEnabled else {
            return
        }
        self.file.modify { entries in
            let version = Version(text: previousText, date: previousDate)
            if let index = entries.firstIndex(where: { $0.key == key }) {
                if entries[index].versions.last != version {
                    entries[index].versions.append(version)
                }
                let entry = entries.remove(at: index)
                entries.append(entry)
            } else {
                entries.append(Entry(key: key, versions: [version]))
            }
            if entries.count > self.maxEntries {
                entries.removeFirst(entries.count - self.maxEntries)
            }
        }
        mindGramNotifyChanged()
    }

    /// Earlier texts, oldest first; empty when MindGram saw no edits.
    public static func versions(_ key: MindGramMessageKey) -> [Version] {
        return self.file.read { entries in
            return entries.first(where: { $0.key == key })?.versions ?? []
        }
    }

    public static func clear() {
        self.file.modify { entries in
            entries.removeAll()
        }
        mindGramNotifyChanged()
    }
}
