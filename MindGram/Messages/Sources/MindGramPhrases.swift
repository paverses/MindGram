import Foundation

/// «Быстрые фразы»: saved texts with formatting, called up by typing a trigger symbol in any chat.
public enum MindGramPhrases {
    /// A formatting range inside a phrase, in UTF-16 units.
    public struct Format: Codable, Equatable {
        public enum Kind: String, Codable, CaseIterable {
            case bold
            case italic
            case underline
            case strikethrough
            case monospace
            case spoiler
            case link
        }

        public var kind: Kind
        public var location: Int
        public var length: Int
        public var url: String?

        public init(kind: Kind, location: Int, length: Int, url: String? = nil) {
            self.kind = kind
            self.location = location
            self.length = length
            self.url = url
        }
    }

    public struct Phrase: Codable, Equatable {
        public var id: String
        /// What is typed after the trigger: "адрес" for ";;адрес".
        public var name: String
        public var folder: String
        public var text: String
        public var formats: [Format]

        public init(id: String = UUID().uuidString, name: String, folder: String, text: String, formats: [Format]) {
            self.id = id
            self.name = name
            self.folder = folder
            self.text = text
            self.formats = formats
        }
    }

    private static let file = MindGramJSONFile<[Phrase]>(name: "phrases", defaultValue: [])

    public static var isEnabled: Bool {
        get { return MindGramDefaults.bool("MindGram.phrases.enabled", default: true) }
        set { MindGramDefaults.setBool("MindGram.phrases.enabled", newValue) }
    }

    /// Trigger symbols separated by spaces: "/ ;; !" — any of them starts a phrase search.
    public static var triggers: String {
        get { return MindGramDefaults.string("MindGram.phrases.triggers", default: "/") }
        set { MindGramDefaults.setString("MindGram.phrases.triggers", newValue) }
    }

    public static var triggerList: [String] {
        let list = self.triggers.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        return list.isEmpty ? ["/"] : list.sorted(by: { $0.count > $1.count })
    }

    public static var phrases: [Phrase] {
        return self.file.read { $0 }
    }

    public static func save(_ phrase: Phrase) {
        self.file.modify { phrases in
            if let index = phrases.firstIndex(where: { $0.id == phrase.id }) {
                phrases[index] = phrase
            } else {
                phrases.append(phrase)
            }
        }
        mindGramNotifyChanged()
    }

    public static func delete(id: String) {
        self.file.modify { phrases in
            phrases.removeAll(where: { $0.id == id })
        }
        mindGramNotifyChanged()
    }

    /// Folders in use, sorted; "" (no folder) first.
    public static var folders: [String] {
        return Array(Set(self.phrases.map(\.folder))).sorted()
    }

    /// The trigger query at the end of `text`: the trigger and what follows it, when the user is typing one.
    public static func query(in text: String) -> (trigger: String, query: String, range: NSRange)? {
        guard self.isEnabled, !self.phrases.isEmpty else {
            return nil
        }
        let ns = text as NSString
        // The last word (since the last space or line break).
        var start = ns.length
        while start > 0 {
            let character = ns.character(at: start - 1)
            if character == 0x20 || character == 0x0A || character == 0x09 {
                break
            }
            start -= 1
        }
        let word = ns.substring(from: start)
        for trigger in self.triggerList where word.hasPrefix(trigger) {
            let query = String(word.dropFirst(trigger.count))
            return (trigger, query, NSRange(location: start, length: ns.length - start))
        }
        return nil
    }

    /// Phrases whose name (or text) matches `query`, best first.
    public static func matches(_ query: String) -> [Phrase] {
        let query = query.lowercased()
        let phrases = self.phrases
        if query.isEmpty {
            return phrases.sorted(by: { ($0.folder, $0.name) < ($1.folder, $1.name) })
        }
        let byName = phrases.filter { $0.name.lowercased().hasPrefix(query) }
        let contains = phrases.filter { !$0.name.lowercased().hasPrefix(query) && ($0.name.lowercased().contains(query) || $0.text.lowercased().contains(query) || $0.folder.lowercased().contains(query)) }
        return byName + contains
    }

    /// {имя} {name} {дата} {date} {время} {time} replaced; formats are shifted to the new positions.
    public static func expand(_ phrase: Phrase, peerName: String) -> (text: String, formats: [Format]) {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let replacements: [String: String] = [
            "{имя}": peerName, "{name}": peerName,
            "{дата}": dateFormatter.string(from: date), "{date}": dateFormatter.string(from: date),
            "{время}": timeFormatter.string(from: date), "{time}": timeFormatter.string(from: date)
        ]
        var text = phrase.text as NSString
        var formats = phrase.formats
        for (key, value) in replacements {
            while true {
                let range = text.range(of: key)
                if range.location == NSNotFound {
                    break
                }
                let delta = (value as NSString).length - range.length
                text = text.replacingCharacters(in: range, with: value) as NSString
                for index in formats.indices {
                    if formats[index].location >= range.location + range.length {
                        formats[index].location += delta
                    } else if formats[index].location + formats[index].length > range.location {
                        formats[index].length = max(0, formats[index].length + delta)
                    }
                }
            }
        }
        return (text as String, formats)
    }
}
