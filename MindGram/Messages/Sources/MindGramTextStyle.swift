import Foundation

/// «Оформление текста»: formatting added to every message you send (bold, italic, quote…) and a «шрифт» —
/// letters swapped for look-alike or decorative Unicode characters before sending.
public enum MindGramTextStyle {
    /// Telegram formatting that can cover the whole message.
    public enum Format: String, CaseIterable, Codable {
        case bold
        case italic
        case underline
        case strikethrough
        case monospace
        case spoiler
        case quote

        public func title(isRussian: Bool) -> String {
            switch self {
            case .bold:
                return isRussian ? "Жирный" : "Bold"
            case .italic:
                return isRussian ? "Курсив" : "Italic"
            case .underline:
                return isRussian ? "Подчёркнутый" : "Underline"
            case .strikethrough:
                return isRussian ? "Зачёркнутый" : "Strikethrough"
            case .monospace:
                return isRussian ? "Моноширинный" : "Monospace"
            case .spoiler:
                return isRussian ? "Скрытый (спойлер)" : "Spoiler"
            case .quote:
                return isRussian ? "Цитата" : "Quote"
            }
        }
    }

    /// Character sets the letters are swapped into.
    public enum Font: String, CaseIterable {
        case normal
        /// Cyrillic letters replaced by Latin/Greek look-alikes: «Καк οтπραвлять οфф3ρ?»
        case lookalike
        case boldSans
        case italicSans
        case script
        case fraktur
        case doubleStruck
        case monospace
        case smallCaps
        case circled
        case squared
        case wide

        public func title(isRussian: Bool) -> String {
            switch self {
            case .normal:
                return isRussian ? "Обычный" : "Normal"
            case .lookalike:
                return isRussian ? "Похожие буквы" : "Look-alike Letters"
            case .boldSans:
                return "𝗕𝗼𝗹𝗱"
            case .italicSans:
                return "𝘐𝘵𝘢𝘭𝘪𝘤"
            case .script:
                return "𝓢𝓬𝓻𝓲𝓹𝓽"
            case .fraktur:
                return "𝔉𝔯𝔞𝔨𝔱𝔲𝔯"
            case .doubleStruck:
                return "𝔻𝕠𝕦𝕓𝕝𝕖"
            case .monospace:
                return "𝙼𝚘𝚗𝚘"
            case .smallCaps:
                return "ꜱᴍᴀʟʟ ᴄᴀᴘꜱ"
            case .circled:
                return "Ⓒⓘⓡⓒⓛⓔⓓ"
            case .squared:
                return "🅂🅀🅄🄰🅁🄴"
            case .wide:
                return "Ｗｉｄｅ"
            }
        }
    }

    public static var formats: Set<Format> {
        get {
            let raw = UserDefaults.standard.stringArray(forKey: "MindGram.textStyle.formats") ?? []
            return Set(raw.compactMap(Format.init(rawValue:)))
        }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue), forKey: "MindGram.textStyle.formats")
            mindGramNotifyChanged()
        }
    }

    public static var font: Font {
        get { return Font(rawValue: UserDefaults.standard.string(forKey: "MindGram.textStyle.font") ?? "") ?? .normal }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "MindGram.textStyle.font")
            mindGramNotifyChanged()
        }
    }

    public static var isActive: Bool {
        return !self.formats.isEmpty || self.font != .normal
    }

    public static func letterFormats(for text: String, formats: Set<Format>) -> [(range: Range<Int>, format: Format)] {
        let pool = Format.allCases.filter { formats.contains($0) && $0 != .quote }
        guard pool.count >= 2 else {
            return []
        }
        var result: [(range: Range<Int>, format: Format)] = []
        var offset = 0
        var previous: Format?
        for character in text {
            let length = String(character).utf16.count
            if !character.isWhitespace {
                let choices = pool.filter { $0 != previous }
                if let format = choices.randomElement() {
                    result.append((offset ..< offset + length, format))
                    previous = format
                }
            }
            offset += length
        }
        return result
    }

    // MARK: Fonts

    private static let lookalikes: [Character: Character] = [
        "а": "a", "А": "A", "в": "ʙ", "В": "B", "е": "e", "Е": "E", "ё": "ë", "Ё": "Ë", "к": "κ", "К": "K",
        "м": "ᴍ", "М": "M", "н": "ʜ", "Н": "H", "о": "ο", "О": "O", "р": "ρ", "Р": "P", "с": "c", "С": "C",
        "т": "τ", "Т": "T", "у": "y", "У": "Y", "х": "x", "Х": "X", "п": "π", "П": "Π", "л": "λ", "Л": "Λ",
        "д": "∂", "з": "3", "З": "3", "и": "u", "ф": "φ", "Ф": "Φ", "г": "ɼ", "Г": "Γ", "ш": "ɯ", "Ш": "Ш",
        "ь": "ь", "б": "6", "ч": "4", "я": "ᴙ", "Я": "ᴙ", "ы": "ы", "ж": "ж", "э": "϶", "ю": "ю", "й": "ŭ"
    ]

    /// Unicode "Mathematical Alphanumeric Symbols" for Latin letters and digits; nil leaves the character as is.
    private static func mathCharacter(_ scalar: Unicode.Scalar, upper: UInt32, lower: UInt32, digit: UInt32?, exceptions: [UInt32: UInt32] = [:]) -> String? {
        let value = scalar.value
        var mapped: UInt32?
        if value >= 0x41 && value <= 0x5A {
            mapped = upper + (value - 0x41)
        } else if value >= 0x61 && value <= 0x7A {
            mapped = lower + (value - 0x61)
        } else if let digit, value >= 0x30 && value <= 0x39 {
            mapped = digit + (value - 0x30)
        }
        guard var result = mapped else {
            return nil
        }
        if let exception = exceptions[result] {
            result = exception
        }
        return Unicode.Scalar(result).map { String(Character($0)) }
    }

    private static let smallCapsMap: [Character: String] = [
        "a": "ᴀ", "b": "ʙ", "c": "ᴄ", "d": "ᴅ", "e": "ᴇ", "f": "ꜰ", "g": "ɢ", "h": "ʜ", "i": "ɪ", "j": "ᴊ", "k": "ᴋ", "l": "ʟ", "m": "ᴍ",
        "n": "ɴ", "o": "ᴏ", "p": "ᴘ", "q": "ǫ", "r": "ʀ", "s": "ꜱ", "t": "ᴛ", "u": "ᴜ", "v": "ᴠ", "w": "ᴡ", "x": "x", "y": "ʏ", "z": "ᴢ"
    ]

    /// `text` in the chosen font. Links, @mentions, #tags and /commands keep their letters so they still work.
    public static func apply(font: Font, to text: String) -> String {
        if font == .normal {
            return text
        }
        var result = ""
        var keep = false
        for character in text {
            if character == " " || character == "\n" {
                keep = false
            } else if character == "@" || character == "#" || character == "/" {
                keep = true
            }
            if keep {
                result.append(character)
                continue
            }
            result += self.convert(character, font: font)
        }
        if text.contains("http://") || text.contains("https://") || text.contains("t.me/") {
            // Look-alike letters would break links; leave messages with links alone.
            return text
        }
        return result
    }

    private static func convert(_ character: Character, font: Font) -> String {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return String(character)
        }
        switch font {
        case .normal:
            return String(character)
        case .lookalike:
            return self.lookalikes[character].map(String.init) ?? String(character)
        case .boldSans:
            return self.mathCharacter(scalar, upper: 0x1D5D4, lower: 0x1D5EE, digit: 0x1D7EC) ?? String(character)
        case .italicSans:
            return self.mathCharacter(scalar, upper: 0x1D608, lower: 0x1D622, digit: nil) ?? String(character)
        case .script:
            return self.mathCharacter(scalar, upper: 0x1D4D0, lower: 0x1D4EA, digit: nil) ?? String(character)
        case .fraktur:
            return self.mathCharacter(scalar, upper: 0x1D56C, lower: 0x1D586, digit: nil) ?? String(character)
        case .doubleStruck:
            return self.mathCharacter(scalar, upper: 0x1D538, lower: 0x1D552, digit: 0x1D7D8, exceptions: [0x1D53A: 0x2102, 0x1D53F: 0x210D, 0x1D545: 0x2115, 0x1D547: 0x2119, 0x1D548: 0x211A, 0x1D549: 0x211D, 0x1D551: 0x2124]) ?? String(character)
        case .monospace:
            return self.mathCharacter(scalar, upper: 0x1D670, lower: 0x1D68A, digit: 0x1D7F6) ?? String(character)
        case .smallCaps:
            return self.smallCapsMap[Character(String(character).lowercased())] ?? String(character)
        case .circled:
            let value = scalar.value
            if value >= 0x41 && value <= 0x5A {
                return Unicode.Scalar(0x24B6 + value - 0x41).map { String(Character($0)) } ?? String(character)
            } else if value >= 0x61 && value <= 0x7A {
                return Unicode.Scalar(0x24D0 + value - 0x61).map { String(Character($0)) } ?? String(character)
            }
            return String(character)
        case .squared:
            let value = String(character).uppercased().unicodeScalars.first?.value ?? 0
            if value >= 0x41 && value <= 0x5A {
                return Unicode.Scalar(0x1F130 + value - 0x41).map { String(Character($0)) } ?? String(character)
            }
            return String(character)
        case .wide:
            let value = scalar.value
            if value >= 0x21 && value <= 0x7E {
                return Unicode.Scalar(0xFF01 + value - 0x21).map { String(Character($0)) } ?? String(character)
            }
            return String(character)
        }
    }
}
