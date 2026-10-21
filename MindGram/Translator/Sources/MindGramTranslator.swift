import Foundation

/// Translation in MindGram: which service translates, into which language, and which chats translate
/// themselves. Telegram's own translation needs Premium for whole chats; Google and Microsoft don't.
public enum MindGramTranslator {
    public enum Provider: String, CaseIterable {
        /// Telegram's server (messages.translateText).
        case telegram
        /// Google Translate (translate.googleapis.com, the free web client).
        case google
        /// Microsoft Translator (the Edge browser's free endpoint).
        case microsoft
        /// Apple Translation on the device (iOS 18+); falls back to Google when unavailable.
        case apple

        public func title(isRussian: Bool) -> String {
            switch self {
            case .telegram:
                return "Telegram"
            case .google:
                return "Google"
            case .microsoft:
                return "Microsoft"
            case .apple:
                return isRussian ? "Apple (на устройстве)" : "Apple (on device)"
            }
        }
    }

    public enum TranslationError: Error {
        case network(String)
        case badResponse(String)
    }

    // MARK: Settings

    private static func string(_ key: String, _ defaultValue: String) -> String {
        return UserDefaults.standard.string(forKey: key) ?? defaultValue
    }

    private static func bool(_ key: String, _ defaultValue: Bool) -> Bool {
        return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    private static func set(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        let name = Notification.Name("MindGramSettingsDidChange")
        if Thread.isMainThread {
            NotificationCenter.default.post(name: name, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: name, object: nil)
            }
        }
    }

    private static func peerSet(_ key: String) -> Set<Int64> {
        guard let values = UserDefaults.standard.array(forKey: key) as? [NSNumber] else {
            return Set()
        }
        return Set(values.map { $0.int64Value })
    }

    public static var provider: Provider {
        get { return Provider(rawValue: self.string("MindGram.translate.provider", Provider.google.rawValue)) ?? .google }
        set { self.set("MindGram.translate.provider", newValue.rawValue) }
    }

    /// Requests go through MindGram instead of Telegram's server.
    public static var usesExternalProvider: Bool {
        return self.provider != .telegram
    }

    /// Target language for "Translate"; empty means the app's language.
    public static var targetLanguage: String {
        get { return self.string("MindGram.translate.target", "") }
        set { self.set("MindGram.translate.target", newValue) }
    }

    /// The translation bar and whole-chat translation without Premium.
    public static var unlocksChatTranslation: Bool {
        get { return self.bool("MindGram.translate.unlock", true) }
        set { self.set("MindGram.translate.unlock", newValue) }
    }

    /// Translate every chat in a foreign language as soon as it opens.
    public static var autoTranslatesAllChats: Bool {
        get { return self.bool("MindGram.translate.autoAll", false) }
        set { self.set("MindGram.translate.autoAll", newValue) }
    }

    /// Chats translated as soon as they open (PeerId.toInt64()).
    public static var autoChats: Set<Int64> {
        get { return self.peerSet("MindGram.translate.autoChats") }
        set { self.set("MindGram.translate.autoChats", newValue.map { NSNumber(value: $0) }) }
    }

    public static func autoTranslates(peerId: Int64) -> Bool {
        return self.autoTranslatesAllChats || self.autoChats.contains(peerId)
    }

    /// Chats where own messages are translated before sending.
    public static var outgoingChats: Set<Int64> {
        get { return self.peerSet("MindGram.translate.outgoingChats") }
        set { self.set("MindGram.translate.outgoingChats", newValue.map { NSNumber(value: $0) }) }
    }

    /// The language own messages are translated into.
    public static var outgoingLanguage: String {
        get { return self.string("MindGram.translate.outgoingLanguage", "en") }
        set { self.set("MindGram.translate.outgoingLanguage", newValue) }
    }

    public static func translatesOutgoing(peerId: Int64) -> Bool {
        return self.outgoingChats.contains(peerId)
    }

    /// Languages offered in the pickers: code, Russian name, English name.
    public static let languages: [(code: String, ru: String, en: String)] = [
        ("en", "Английский", "English"),
        ("ru", "Русский", "Russian"),
        ("uk", "Украинский", "Ukrainian"),
        ("be", "Белорусский", "Belarusian"),
        ("kk", "Казахский", "Kazakh"),
        ("uz", "Узбекский", "Uzbek"),
        ("de", "Немецкий", "German"),
        ("fr", "Французский", "French"),
        ("es", "Испанский", "Spanish"),
        ("it", "Итальянский", "Italian"),
        ("pt", "Португальский", "Portuguese"),
        ("pl", "Польский", "Polish"),
        ("cs", "Чешский", "Czech"),
        ("nl", "Нидерландский", "Dutch"),
        ("sv", "Шведский", "Swedish"),
        ("fi", "Финский", "Finnish"),
        ("tr", "Турецкий", "Turkish"),
        ("az", "Азербайджанский", "Azerbaijani"),
        ("hy", "Армянский", "Armenian"),
        ("ka", "Грузинский", "Georgian"),
        ("he", "Иврит", "Hebrew"),
        ("ar", "Арабский", "Arabic"),
        ("fa", "Персидский", "Persian"),
        ("hi", "Хинди", "Hindi"),
        ("zh", "Китайский", "Chinese"),
        ("ja", "Японский", "Japanese"),
        ("ko", "Корейский", "Korean"),
        ("vi", "Вьетнамский", "Vietnamese"),
        ("th", "Тайский", "Thai"),
        ("id", "Индонезийский", "Indonesian")
    ]

    public static func languageName(_ code: String, isRussian: Bool) -> String {
        if let language = self.languages.first(where: { $0.code == code }) {
            return isRussian ? language.ru : language.en
        }
        return code
    }

    // MARK: Translating

    /// Translates `texts` into `toLang` with the chosen external provider. The result has one text per
    /// input, in order, and the detected source language when the service reports it.
    public static func translate(texts: [String], fromLang: String?, toLang: String, completion: @escaping (Result<(texts: [String], detected: String?), TranslationError>) -> Void) {
        let provider: Provider = self.provider == .microsoft ? .microsoft : .google
        if texts.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            completion(.success((texts, nil)))
            return
        }
        // An empty or unknown source language means "detect it"; an empty target falls back to the device language.
        let source: String? = fromLang.flatMap { $0.isEmpty || $0 == "und" ? nil : $0 }
        var target = toLang.isEmpty ? (Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en") : toLang
        if target.isEmpty {
            target = "en"
        }

        // Texts translated before come from memory at once; only the rest go to the network.
        let cached = texts.map { MindGramTranslationCache.get(text: $0, toLang: target) }
        if cached.allSatisfy({ $0 != nil }) {
            completion(.success((cached.map { $0 ?? "" }, nil)))
            return
        }
        let missingIndices = texts.indices.filter { cached[$0] == nil }
        let missingTexts = missingIndices.map { texts[$0] }
        let merge: (Result<(texts: [String], detected: String?), TranslationError>) -> Void = { result in
            switch result {
            case let .success(value):
                var merged = cached.map { $0 ?? "" }
                for (position, index) in missingIndices.enumerated() where position < value.texts.count {
                    merged[index] = value.texts[position]
                    if value.texts[position] != texts[index] {
                        MindGramTranslationCache.set(text: texts[index], toLang: target, translation: value.texts[position])
                    }
                }
                completion(.success((merged, value.detected)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
        self.translateUncached(texts: missingTexts, source: source, target: target, provider: provider, completion: merge)
    }

    private static func translateUncached(texts: [String], source: String?, target: String, provider: Provider, completion: @escaping (Result<(texts: [String], detected: String?), TranslationError>) -> Void) {
        switch provider {
        case .microsoft:
            MindGramMicrosoftTranslator.translate(texts: texts, fromLang: source, toLang: target, completion: completion)
        default:
            // Google's free client fails now and then; Microsoft takes over for that request.
            MindGramGoogleTranslator.translate(texts: texts, fromLang: source, toLang: target, completion: { result in
                if case .failure = result {
                    MindGramMicrosoftTranslator.translate(texts: texts, fromLang: source, toLang: target, completion: { fallback in
                        if case .success = fallback {
                            completion(fallback)
                        } else {
                            completion(result)
                        }
                    })
                } else {
                    completion(result)
                }
            })
        }
    }

    /// Telegram language codes to the codes the web services expect.
    static func serviceCode(_ code: String) -> String {
        let base = code.replacingOccurrences(of: "-raw", with: "")
        switch base {
        case "zh", "zh-hans":
            return "zh-CN"
        case "zh-hant":
            return "zh-TW"
        case "he":
            return "iw"
        default:
            return base
        }
    }
}

/// Google Translate through its free web client (client=gtx), one request per text.
enum MindGramGoogleTranslator {
    static func translate(texts: [String], fromLang: String?, toLang: String, completion: @escaping (Result<(texts: [String], detected: String?), MindGramTranslator.TranslationError>) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var results = [String](repeating: "", count: texts.count)
        var detected: String?
        var failure: MindGramTranslator.TranslationError?

        for (index, text) in texts.enumerated() {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                results[index] = text
                continue
            }
            group.enter()
            self.translateOne(text: text, fromLang: fromLang, toLang: toLang, completion: { result in
                lock.lock()
                switch result {
                case let .success((translated, language)):
                    results[index] = translated
                    if detected == nil {
                        detected = language
                    }
                case let .failure(error):
                    failure = error
                    results[index] = text
                }
                lock.unlock()
                group.leave()
            })
        }
        group.notify(queue: .global(qos: .userInitiated), execute: {
            if let failure, results == texts {
                completion(.failure(failure))
            } else {
                completion(.success((results, detected)))
            }
        })
    }

    private static func translateOne(text: String, fromLang: String?, toLang: String, completion: @escaping (Result<(String, String?), MindGramTranslator.TranslationError>) -> Void) {
        guard let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&ie=UTF-8&oe=UTF-8") else {
            completion(.failure(.badResponse("bad url")))
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 20.0)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        let source = fromLang.map(MindGramTranslator.serviceCode) ?? "auto"
        // Form encoding: only unreserved ASCII stays as is (CharacterSet.alphanumerics would let Cyrillic through raw).
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let body = "sl=\(source)&tl=\(MindGramTranslator.serviceCode(toLang))&q=\(text.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            if let error {
                completion(.failure(.network(error.localizedDescription)))
                return
            }
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [Any], let segments = json.first as? [Any] else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                completion(.failure(.badResponse("Google: HTTP \(status)")))
                return
            }
            var translated = ""
            for segment in segments {
                if let parts = segment as? [Any], let piece = parts.first as? String {
                    translated += piece
                }
            }
            let detected = json.count > 2 ? json[2] as? String : nil
            completion(.success((translated, detected)))
        }).resume()
    }
}

/// Microsoft Translator through the token the Edge browser uses; all texts in one request.
enum MindGramMicrosoftTranslator {
    private static let lock = NSLock()
    private static var token: (value: String, expires: Date)?

    private static func withToken(_ completion: @escaping (Result<String, MindGramTranslator.TranslationError>) -> Void) {
        self.lock.lock()
        if let token = self.token, token.expires > Date() {
            self.lock.unlock()
            completion(.success(token.value))
            return
        }
        self.lock.unlock()
        guard let url = URL(string: "https://edge.microsoft.com/translate/auth") else {
            completion(.failure(.badResponse("bad url")))
            return
        }
        URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 15.0), completionHandler: { data, response, error in
            if let error {
                completion(.failure(.network(error.localizedDescription)))
                return
            }
            guard let data, let value = String(data: data, encoding: .utf8), !value.isEmpty, (response as? HTTPURLResponse)?.statusCode == 200 else {
                completion(.failure(.badResponse("Microsoft auth: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")))
                return
            }
            self.lock.lock()
            self.token = (value, Date().addingTimeInterval(8 * 60))
            self.lock.unlock()
            completion(.success(value))
        }).resume()
    }

    static func translate(texts: [String], fromLang: String?, toLang: String, completion: @escaping (Result<(texts: [String], detected: String?), MindGramTranslator.TranslationError>) -> Void) {
        self.withToken({ tokenResult in
            switch tokenResult {
            case let .failure(error):
                completion(.failure(error))
            case let .success(token):
                var components = URLComponents(string: "https://api-edge.cognitive.microsofttranslator.com/translate")
                var items = [URLQueryItem(name: "api-version", value: "3.0"), URLQueryItem(name: "to", value: MindGramTranslator.serviceCode(toLang) == "iw" ? "he" : MindGramTranslator.serviceCode(toLang).replacingOccurrences(of: "zh-CN", with: "zh-Hans").replacingOccurrences(of: "zh-TW", with: "zh-Hant"))]
                if let fromLang {
                    items.append(URLQueryItem(name: "from", value: fromLang))
                }
                components?.queryItems = items
                guard let url = components?.url else {
                    completion(.failure(.badResponse("bad url")))
                    return
                }
                var request = URLRequest(url: url, timeoutInterval: 20.0)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.httpBody = try? JSONSerialization.data(withJSONObject: texts.map { ["Text": $0] })
                URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
                    if let error {
                        completion(.failure(.network(error.localizedDescription)))
                        return
                    }
                    guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], json.count == texts.count else {
                        completion(.failure(.badResponse("Microsoft: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")))
                        return
                    }
                    var results: [String] = []
                    var detected: String?
                    for (index, item) in json.enumerated() {
                        let translations = item["translations"] as? [[String: Any]]
                        results.append(translations?.first?["text"] as? String ?? texts[index])
                        if detected == nil, let language = (item["detectedLanguage"] as? [String: Any])?["language"] as? String {
                            detected = language
                        }
                    }
                    completion(.success((results, detected)))
                }).resume()
            }
        })
    }
}

/// Translations already received in this launch, so scrolling back or reopening a chat shows them at once.
enum MindGramTranslationCache {
    private static let lock = NSLock()
    private static var storage: [String: String] = [:]

    private static func key(_ text: String, _ toLang: String) -> String {
        return toLang + "\u{1}" + text
    }

    static func get(text: String, toLang: String) -> String? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.storage[self.key(text, toLang)]
    }

    static func set(text: String, toLang: String, translation: String) {
        self.lock.lock()
        if self.storage.count > 5000 {
            self.storage.removeAll()
        }
        self.storage[self.key(text, toLang)] = translation
        self.lock.unlock()
    }
}
