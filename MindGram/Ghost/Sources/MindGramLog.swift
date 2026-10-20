import Foundation

/// MindGram's own journal for the «Отчёт» screen: errors with the exact place in the code, and counters of
/// what MindGram did (for example, how many read receipts ghost mode kept back). Foundation-only, so
/// TelegramCore can write to it. Errors are kept in Library/MindGramErrors.log across launches (last 200).
public enum MindGramLog {
    public struct Entry {
        public let date: Date
        /// The feature in plain words: "Режим призрака", "Бейдж"...
        public let feature: String
        /// What happened, in plain words, with the system's own error text.
        public let text: String
        /// Where in the code: File.swift:123 function().
        public let location: String
    }

    private static let lock = NSLock()
    private static var loaded = false
    private static var storedEntries: [Entry] = []
    private static var storedCounters: [String: Int] = [:]
    private static let maxEntries = 200

    private static var url: URL? {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("MindGramErrors.log")
    }

    /// Records an error. `feature` and `text` are for people; the file, function and line are filled in for the developer.
    public static func error(_ feature: String, _ text: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let entry = Entry(date: Date(), feature: feature, text: text, location: "\(fileName):\(line) \(function)")
        self.lock.lock()
        self.loadIfNeeded()
        self.storedEntries.append(entry)
        if self.storedEntries.count > self.maxEntries {
            self.storedEntries.removeFirst(self.storedEntries.count - self.maxEntries)
        }
        let snapshot = self.storedEntries
        self.lock.unlock()
        self.save(snapshot)
    }

    /// All recorded errors, oldest first.
    public static var entries: [Entry] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        self.loadIfNeeded()
        return self.storedEntries
    }

    public static func clear() {
        self.lock.lock()
        self.storedEntries = []
        self.loaded = true
        self.lock.unlock()
        self.save([])
    }

    /// Counts an event since launch, e.g. "ghost.hideRead".
    public static func count(_ key: String) {
        self.lock.lock()
        self.storedCounters[key, default: 0] += 1
        self.lock.unlock()
    }

    public static var counters: [String: Int] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.storedCounters
    }

    // One entry per line: time<TAB>feature<TAB>location<TAB>text, tabs and newlines in fields escaped.
    private static func loadIfNeeded() {
        guard !self.loaded else {
            return
        }
        self.loaded = true
        guard let url = self.url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        for line in text.split(separator: "\n") {
            let parts = line.components(separatedBy: "\t")
            guard parts.count == 4, let time = Double(parts[0]) else {
                continue
            }
            self.storedEntries.append(Entry(date: Date(timeIntervalSince1970: time), feature: self.unescape(parts[1]), text: self.unescape(parts[3]), location: self.unescape(parts[2])))
        }
    }

    private static func save(_ entries: [Entry]) {
        guard let url = self.url else {
            return
        }
        let text = entries.map { entry in
            return "\(entry.date.timeIntervalSince1970)\t\(self.escape(entry.feature))\t\(self.escape(entry.location))\t\(self.escape(entry.text))"
        }.joined(separator: "\n")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func escape(_ value: String) -> String {
        return value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\t", with: "\\t").replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func unescape(_ value: String) -> String {
        var result = ""
        var escaping = false
        for character in value {
            if escaping {
                switch character {
                case "t":
                    result.append("\t")
                case "n":
                    result.append("\n")
                default:
                    result.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}
