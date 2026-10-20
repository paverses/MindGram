import Foundation

/// A message as MindGram stores it: the chat (PeerId.toInt64()), the message namespace and id.
public struct MindGramMessageKey: Hashable, Codable {
    public let peerId: Int64
    public let namespace: Int32
    public let id: Int32

    public init(peerId: Int64, namespace: Int32, id: Int32) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
    }
}

/// What kind of chat a message is in; the deleted-message filters work by it.
public enum MindGramChatKind: String, Codable, CaseIterable {
    case privateChat
    case secretChat
    case group
    case channel
    case bot
}

/// Posts the shared "MindGram settings changed" notification on the main thread.
func mindGramNotifyChanged() {
    let name = Notification.Name("MindGramSettingsDidChange")
    if Thread.isMainThread {
        NotificationCenter.default.post(name: name, object: nil)
    } else {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: nil)
        }
    }
}

/// A Codable value kept in Library/MindGram/<name>.json: read once, written in the background after changes.
final class MindGramJSONFile<Value: Codable> {
    private let url: URL?
    private let lock = NSLock()
    private var value: Value
    private let queue: DispatchQueue
    private var writeScheduled = false

    init(name: String, defaultValue: Value) {
        let directory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("MindGram", isDirectory: true)
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.url = directory?.appendingPathComponent("\(name).json")
        self.queue = DispatchQueue(label: "MindGram.\(name)", qos: .utility)
        if let url = self.url, let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(Value.self, from: data) {
            self.value = decoded
        } else {
            self.value = defaultValue
        }
    }

    func read<T>(_ f: (Value) -> T) -> T {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return f(self.value)
    }

    func modify(_ f: (inout Value) -> Void) {
        self.lock.lock()
        f(&self.value)
        let shouldSchedule = !self.writeScheduled
        self.writeScheduled = true
        self.lock.unlock()
        if shouldSchedule {
            self.queue.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                self?.write()
            })
        }
    }

    private func write() {
        self.lock.lock()
        let value = self.value
        self.writeScheduled = false
        self.lock.unlock()
        guard let url = self.url, let data = try? JSONEncoder().encode(value) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }
}

/// UserDefaults helpers shared by the MindGram message settings.
enum MindGramDefaults {
    static func bool(_ key: String, default defaultValue: Bool) -> Bool {
        if let value = UserDefaults.standard.object(forKey: key) as? Bool {
            return value
        }
        return defaultValue
    }

    static func setBool(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        mindGramNotifyChanged()
    }

    static func int(_ key: String, default defaultValue: Int) -> Int {
        if let value = UserDefaults.standard.object(forKey: key) as? Int {
            return value
        }
        return defaultValue
    }

    static func setInt(_ key: String, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key)
        mindGramNotifyChanged()
    }

    static func string(_ key: String, default defaultValue: String) -> String {
        return UserDefaults.standard.string(forKey: key) ?? defaultValue
    }

    static func setString(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
        mindGramNotifyChanged()
    }

    static func peerSet(_ key: String) -> Set<Int64> {
        guard let values = UserDefaults.standard.array(forKey: key) as? [NSNumber] else {
            return Set()
        }
        return Set(values.map { $0.int64Value })
    }

    static func setPeerSet(_ key: String, _ value: Set<Int64>) {
        UserDefaults.standard.set(value.map { NSNumber(value: $0) }, forKey: key)
        mindGramNotifyChanged()
    }
}
