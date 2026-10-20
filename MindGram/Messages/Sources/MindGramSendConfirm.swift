import Foundation

/// «Подтверждение перед отправкой»: ask before sending what is easy to send by accident.
public enum MindGramSendConfirm {
    public enum Kind: String, CaseIterable {
        case sticker
        case gif
        case voice
        case round
        case call

        public func title(isRussian: Bool) -> String {
            switch self {
            case .sticker:
                return isRussian ? "Стикеры" : "Stickers"
            case .gif:
                return "GIF"
            case .voice:
                return isRussian ? "Голосовые" : "Voice Messages"
            case .round:
                return isRussian ? "Кружки" : "Round Videos"
            case .call:
                return isRussian ? "Звонки" : "Calls"
            }
        }

        public func question(isRussian: Bool) -> String {
            switch self {
            case .sticker:
                return isRussian ? "Отправить стикер?" : "Send the sticker?"
            case .gif:
                return isRussian ? "Отправить GIF?" : "Send the GIF?"
            case .voice:
                return isRussian ? "Отправить голосовое?" : "Send the voice message?"
            case .round:
                return isRussian ? "Отправить кружок?" : "Send the round video?"
            case .call:
                return isRussian ? "Позвонить?" : "Start the call?"
            }
        }
    }

    public static func isOn(_ kind: Kind) -> Bool {
        return MindGramDefaults.bool("MindGram.confirm.\(kind.rawValue)", default: false)
    }

    public static func set(_ kind: Kind, _ value: Bool) {
        MindGramDefaults.setBool("MindGram.confirm.\(kind.rawValue)", value)
    }
}
