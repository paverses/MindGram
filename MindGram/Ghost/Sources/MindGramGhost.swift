import Foundation

/// Ghost mode: what MindGram keeps from telling the server. Kept in UserDefaults; read by TelegramCore
/// right before a request goes out, so a change applies at once.
public enum MindGramGhost {
    public enum Option: String, CaseIterable {
        /// Don't send read receipts (messages.readHistory and friends).
        case hideRead
        /// Always report "offline" (account.updateStatus).
        case hideOnline
        /// Don't send "typing", choosing a sticker, emoji interactions.
        case hideTyping
        /// Don't send recording/uploading of voice, round videos, photos, videos and files.
        case hideMediaActivity
        /// Don't report that voice and round messages were listened to (readMessageContents).
        case hideListening
        /// Watch stories without being listed as a viewer.
        case anonymousStories
        case readAfterActions
        /// Show the ghost button in the chat list.
        case chatListButton
    }

    /// Posted on every change; the same name as MindGramSettings.didChangeNotification.
    public static let didChangeNotification = Notification.Name("MindGramSettingsDidChange")

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    /// The master switch.
    public static var isEnabled: Bool {
        get {
            return self.defaults.bool(forKey: "MindGram.ghost.enabled")
        }
        set {
            self.defaults.set(newValue, forKey: "MindGram.ghost.enabled")
            self.notify()
        }
    }

    /// An option's own switch, regardless of the master switch.
    public static func isSet(_ option: Option) -> Bool {
        if let value = self.defaults.object(forKey: "MindGram.ghost.\(option.rawValue)") as? Bool {
            return value
        }
        // Everything is on by default once ghost mode is turned on.
        return true
    }

    public static func set(_ option: Option, _ value: Bool) {
        self.defaults.set(value, forKey: "MindGram.ghost.\(option.rawValue)")
        self.notify()
    }

    /// Ghost mode only in the chats in `ghostChats`, instead of everywhere.
    public static var onlySelectedChats: Bool {
        get {
            return self.defaults.bool(forKey: "MindGram.ghost.onlySelectedChats")
        }
        set {
            self.defaults.set(newValue, forKey: "MindGram.ghost.onlySelectedChats")
            self.notify()
        }
    }

    /// Chats ghost mode covers when `onlySelectedChats` is on (PeerId.toInt64()).
    public static var ghostChats: Set<Int64> {
        get {
            return self.peerSet(forKey: "MindGram.ghost.chats")
        }
        set {
            self.setPeerSet(newValue, forKey: "MindGram.ghost.chats")
        }
    }

    /// Chats that always get the real read receipts and typing (PeerId.toInt64()).
    public static var exceptions: Set<Int64> {
        get {
            return self.peerSet(forKey: "MindGram.ghost.exceptions")
        }
        set {
            self.setPeerSet(newValue, forKey: "MindGram.ghost.exceptions")
        }
    }

    /// Whether `option` applies to `peerId` right now. Online status is account-wide, so pass nil for it.
    public static func applies(_ option: Option, peerId: Int64?) -> Bool {
        guard self.isEnabled, self.isSet(option) else {
            return false
        }
        if let peerId {
            if self.exceptions.contains(peerId) {
                return false
            }
            if self.onlySelectedChats && !self.ghostChats.contains(peerId) {
                return false
            }
        } else if self.onlySelectedChats {
            // Account-wide signals can't be limited to chats; with per-chat ghost they stay real.
            return false
        }
        return true
    }

    /// `applies`, for the place that actually keeps a request back: also counts it for the «Отчёт» screen.
    public static func blocks(_ option: Option, peerId: Int64?) -> Bool {
        let result = self.applies(option, peerId: peerId)
        if result {
            MindGramLog.count("ghost.\(option.rawValue)")
        }
        return result
    }

    private static func peerSet(forKey key: String) -> Set<Int64> {
        guard let values = self.defaults.array(forKey: key) as? [NSNumber] else {
            return Set()
        }
        return Set(values.map { $0.int64Value })
    }

    private static func setPeerSet(_ value: Set<Int64>, forKey key: String) {
        self.defaults.set(value.map { NSNumber(value: $0) }, forKey: key)
        self.notify()
    }

    private static func notify() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
            }
        }
    }
}
