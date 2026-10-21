import Foundation

/// Own messages that delete themselves for everyone after a timer. TelegramCore schedules a message
/// once the server has accepted it and deletes it when the time is up; the chat shows the countdown.
public enum MindGramSelfDestruct {
    public enum Scope: String, CaseIterable {
        case all
        case privateChats
        case selectedChats
    }

    /// Timer choices, in seconds.
    public static let durations: [Int] = [5, 15, 30, 60, 300, 900, 3600, 86400]

    private static let file = MindGramJSONFile<[Pending]>(name: "selfdestruct", defaultValue: [])
    private static let lock = NSLock()

    public struct Pending: Codable, Equatable {
        public let key: MindGramMessageKey
        /// Unix time when the message is deleted.
        public let deadline: Double
    }

    public static var isEnabled: Bool {
        get { return MindGramDefaults.bool("MindGram.selfDestruct.enabled", default: false) }
        set { MindGramDefaults.setBool("MindGram.selfDestruct.enabled", newValue) }
    }

    public static var seconds: Int {
        get { return MindGramDefaults.int("MindGram.selfDestruct.seconds", default: 30) }
        set { MindGramDefaults.setInt("MindGram.selfDestruct.seconds", newValue) }
    }

    public static var scope: Scope {
        get { return Scope(rawValue: MindGramDefaults.string("MindGram.selfDestruct.scope", default: Scope.all.rawValue)) ?? .all }
        set { MindGramDefaults.setString("MindGram.selfDestruct.scope", newValue.rawValue) }
    }

    public static var selectedChats: Set<Int64> {
        get { return MindGramDefaults.peerSet("MindGram.selfDestruct.chats") }
        set { MindGramDefaults.setPeerSet("MindGram.selfDestruct.chats", newValue) }
    }

    /// Show "⏱ 0:42" before the time of a message that will delete itself.
    public static var showsCountdown: Bool {
        get { return MindGramDefaults.bool("MindGram.selfDestruct.countdown", default: true) }
        set { MindGramDefaults.setBool("MindGram.selfDestruct.countdown", newValue) }
    }

    /// Whether a just-sent message in this chat should get a timer.
    public static func applies(peerId: Int64, kind: MindGramChatKind) -> Bool {
        guard self.isEnabled else {
            return false
        }
        switch self.scope {
        case .all:
            return kind != .channel
        case .privateChats:
            return kind == .privateChat || kind == .secretChat || kind == .bot
        case .selectedChats:
            return self.selectedChats.contains(peerId)
        }
    }

    public static func schedule(_ key: MindGramMessageKey) {
        let deadline = Date().timeIntervalSince1970 + Double(self.seconds)
        self.file.modify { pending in
            pending.removeAll(where: { $0.key == key })
            pending.append(Pending(key: key, deadline: deadline))
        }
    }

    public static func deadline(_ key: MindGramMessageKey) -> Double? {
        return self.file.read { pending in
            return pending.first(where: { $0.key == key })?.deadline
        }
    }

    public static var pending: [Pending] {
        return self.file.read { $0 }
    }

    public static func remove(_ keys: [MindGramMessageKey]) {
        let set = Set(keys)
        self.file.modify { pending in
            pending.removeAll(where: { set.contains($0.key) })
        }
    }

    /// "⏱ 0:42", "⏱ 5 мин", "⏱ 3 ч" for the time left until `deadline`.
    public static func countdownText(deadline: Double, isRussian: Bool) -> String {
        let left = max(0, Int(ceil(deadline - Date().timeIntervalSince1970)))
        if left < 3600 {
            return String(format: "⏱ %d:%02d", left / 60, left % 60)
        } else if left < 86400 {
            return isRussian ? "⏱ \(left / 3600) ч" : "⏱ \(left / 3600)h"
        } else {
            return isRussian ? "⏱ \(left / 86400) д" : "⏱ \(left / 86400)d"
        }
    }

    public static func durationTitle(_ seconds: Int, isRussian: Bool) -> String {
        if seconds < 60 {
            return isRussian ? "\(seconds) сек" : "\(seconds) sec"
        } else if seconds < 3600 {
            return isRussian ? "\(seconds / 60) мин" : "\(seconds / 60) min"
        } else if seconds < 86400 {
            return isRussian ? "\(seconds / 3600) ч" : "\(seconds / 3600) h"
        } else {
            return isRussian ? "\(seconds / 86400) д" : "\(seconds / 86400) d"
        }
    }
}

/// What a double or triple tap on a message does.
public enum MindGramTapAction: String, CaseIterable {
    case reaction
    case reply
    case copy
    case translate
    case menu
    case nothing

    public static var doubleTap: MindGramTapAction {
        get { return MindGramTapAction(rawValue: MindGramDefaults.string("MindGram.tap.double", default: MindGramTapAction.reaction.rawValue)) ?? .reaction }
        set { MindGramDefaults.setString("MindGram.tap.double", newValue.rawValue) }
    }

    public static var tripleTap: MindGramTapAction {
        get { return MindGramTapAction(rawValue: MindGramDefaults.string("MindGram.tap.triple", default: MindGramTapAction.nothing.rawValue)) ?? .nothing }
        set { MindGramDefaults.setString("MindGram.tap.triple", newValue.rawValue) }
    }

    public func title(isRussian: Bool) -> String {
        switch self {
        case .reaction:
            return isRussian ? "Реакция" : "Reaction"
        case .reply:
            return isRussian ? "Ответить" : "Reply"
        case .copy:
            return isRussian ? "Копировать" : "Copy"
        case .translate:
            return isRussian ? "Перевести" : "Translate"
        case .menu:
            return isRussian ? "Меню сообщения" : "Message Menu"
        case .nothing:
            return isRussian ? "Ничего" : "Nothing"
        }
    }
}

/// Voice and round message transcription on the device (Speech framework), without Premium.
public enum MindGramTranscription {
    public static var isEnabled: Bool {
        get { return MindGramDefaults.bool("MindGram.transcription.local", default: true) }
        set { MindGramDefaults.setBool("MindGram.transcription.local", newValue) }
    }

    /// Use the device even with Premium (private: audio never leaves the phone).
    public static var alwaysLocal: Bool {
        get { return MindGramDefaults.bool("MindGram.transcription.alwaysLocal", default: false) }
        set { MindGramDefaults.setBool("MindGram.transcription.alwaysLocal", newValue) }
    }

    /// Whether to transcribe on the device for an account with or without Premium.
    public static func usesLocal(isPremium: Bool) -> Bool {
        guard self.isEnabled else {
            return false
        }
        return !isPremium || self.alwaysLocal
    }
}

public extension MindGramTranscription {
    /// Translate transcribed voice and round messages into the chosen language.
    static var translates: Bool {
        get { return MindGramDefaults.bool("MindGram.transcription.translate", default: false) }
        set { MindGramDefaults.setBool("MindGram.transcription.translate", newValue) }
    }

    /// Chats where «Показать оригинал» was pressed in the translation bar: their voice transcriptions stay
    /// untranslated too, until «Перевести» is pressed again.
    static func showsOriginal(peerId: Int64) -> Bool {
        return (UserDefaults.standard.array(forKey: "MindGram.transcription.originalChats") as? [NSNumber] ?? []).contains(where: { $0.int64Value == peerId })
    }

    static func setShowsOriginal(peerId: Int64, _ value: Bool) {
        var chats = (UserDefaults.standard.array(forKey: "MindGram.transcription.originalChats") as? [NSNumber] ?? []).map { $0.int64Value }
        chats.removeAll(where: { $0 == peerId })
        if value {
            chats.append(peerId)
        }
        UserDefaults.standard.set(chats.map { NSNumber(value: $0) }, forKey: "MindGram.transcription.originalChats")
    }

    private static let requestedLock = NSLock()
    private static var requested = Set<String>()

    /// True the first time it is asked about a message and language: start that translation then.
    static func shouldRequestTranslation(_ key: MindGramMessageKey, toLang: String) -> Bool {
        let id = "\(key.peerId):\(key.namespace):\(key.id):\(toLang)"
        self.requestedLock.lock()
        defer {
            self.requestedLock.unlock()
        }
        if self.requested.contains(id) {
            return false
        }
        self.requested.insert(id)
        return true
    }
}

/// Swipes on a message: the usual swipe to the left, and a swipe to the right.
public enum MindGramSwipe {
    public static var leftAction: MindGramTapAction {
        get { return MindGramTapAction(rawValue: MindGramDefaults.string("MindGram.swipe.left", default: MindGramTapAction.reply.rawValue)) ?? .reply }
        set { MindGramDefaults.setString("MindGram.swipe.left", newValue.rawValue) }
    }

    /// `.nothing` keeps Telegram's behavior: swiping right goes back from the chat.
    public static var rightAction: MindGramTapAction {
        get { return MindGramTapAction(rawValue: MindGramDefaults.string("MindGram.swipe.right", default: MindGramTapAction.nothing.rawValue)) ?? .nothing }
        set { MindGramDefaults.setString("MindGram.swipe.right", newValue.rawValue) }
    }
}
