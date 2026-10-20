import Foundation
import UIKit

/// An effect for round videos («кружки»). Chosen in MindGram → Кружки or by swiping the circle while
/// recording; applied both to what the camera shows and to the recorded video.
public enum MindGramRoundEffect: String, CaseIterable {
    case off
    // Privacy
    case faceBlur
    case facePixelate
    case backgroundBlur
    case backgroundReplace
    // Masks on the face
    case emojiMask
    case sunglasses
    case crown
    case halo
    case horns
    // Filters
    case noir
    case vintage
    case comic
    case thermal
    case xray
    case beauty
    case glitch
    case vhs
    case kaleidoscope

    public enum Group: CaseIterable {
        case privacy
        case masks
        case filters
    }

    public var group: Group? {
        switch self {
        case .off:
            return nil
        case .faceBlur, .facePixelate, .backgroundBlur, .backgroundReplace:
            return .privacy
        case .emojiMask, .sunglasses, .crown, .halo, .horns:
            return .masks
        default:
            return .filters
        }
    }

    public func title(isRussian: Bool) -> String {
        switch self {
        case .off:
            return isRussian ? "Без эффекта" : "No Effect"
        case .faceBlur:
            return isRussian ? "Размытие лица" : "Face Blur"
        case .facePixelate:
            return isRussian ? "Пиксели на лице" : "Pixelated Face"
        case .backgroundBlur:
            return isRussian ? "Размытие фона" : "Background Blur"
        case .backgroundReplace:
            return isRussian ? "Замена фона" : "Background Replace"
        case .emojiMask:
            return isRussian ? "Эмодзи-маска" : "Emoji Mask"
        case .sunglasses:
            return isRussian ? "Очки" : "Sunglasses"
        case .crown:
            return isRussian ? "Корона" : "Crown"
        case .halo:
            return isRussian ? "Нимб" : "Halo"
        case .horns:
            return isRussian ? "Рожки" : "Horns"
        case .noir:
            return isRussian ? "Ч/Б" : "Noir"
        case .vintage:
            return isRussian ? "Винтаж" : "Vintage"
        case .comic:
            return isRussian ? "Комикс" : "Comic"
        case .thermal:
            return isRussian ? "Тепловизор" : "Thermal"
        case .xray:
            return isRussian ? "Рентген" : "X-Ray"
        case .beauty:
            return isRussian ? "Красота" : "Beauty"
        case .glitch:
            return isRussian ? "Глитч" : "Glitch"
        case .vhs:
            return "VHS"
        case .kaleidoscope:
            return isRussian ? "Калейдоскоп" : "Kaleidoscope"
        }
    }

    public func info(isRussian: Bool) -> String {
        switch self {
        case .off:
            return isRussian ? "Обычное видео" : "Plain video"
        case .faceBlur:
            return isRussian ? "Лицо не узнать" : "Your face can't be recognized"
        case .facePixelate:
            return isRussian ? "Крупные пиксели на лице" : "Large pixels over the face"
        case .backgroundBlur:
            return isRussian ? "Портретный режим" : "Portrait mode"
        case .backgroundReplace:
            return isRussian ? "Градиент вместо фона" : "A gradient instead of the background"
        case .emojiMask:
            return isRussian ? "Эмодзи вместо лица" : "An emoji instead of your face"
        case .sunglasses:
            return isRussian ? "Тёмные очки на глазах" : "Shades on your eyes"
        case .crown:
            return isRussian ? "Корона над головой" : "A crown above your head"
        case .halo:
            return isRussian ? "Светящийся нимб" : "A glowing halo"
        case .horns:
            return isRussian ? "Дьявольские рожки" : "Devil horns"
        case .noir:
            return isRussian ? "Контрастное чёрно-белое" : "High-contrast black and white"
        case .vintage:
            return isRussian ? "Тёплая плёнка с виньеткой" : "Warm film with a vignette"
        case .comic:
            return isRussian ? "Рисунок как в комиксе" : "Comic book drawing"
        case .thermal:
            return isRussian ? "Камера тепловизора" : "Thermal camera"
        case .xray:
            return isRussian ? "Негатив как снимок" : "Negative like a scan"
        case .beauty:
            return isRussian ? "Гладкая кожа, мягкий свет" : "Smooth skin, soft light"
        case .glitch:
            return isRussian ? "Сбой цифрового сигнала" : "Digital signal glitch"
        case .vhs:
            return isRussian ? "Старая видеокассета" : "Old video tape"
        case .kaleidoscope:
            return isRussian ? "Зеркальный узор" : "Mirrored pattern"
        }
    }

    public var usesFaces: Bool {
        switch self {
        case .faceBlur, .facePixelate, .emojiMask, .sunglasses, .crown, .halo, .horns, .beauty:
            return true
        default:
            return false
        }
    }

    public var usesSegmentation: Bool {
        switch self {
        case .backgroundBlur, .backgroundReplace:
            return true
        default:
            return false
        }
    }
}

/// Settings of the round video effects.
public enum MindGramRoundVideo {
    public static let didChangeNotification = Notification.Name("MindGramSettingsDidChange")

    private static func notify() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
            }
        }
    }

    /// Effects in round videos at all; off means the camera works exactly as in Telegram.
    public static var isEnabled: Bool {
        get { return UserDefaults.standard.object(forKey: "MindGram.round.enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "MindGram.round.enabled")
            self.notify()
        }
    }

    /// The effect the camera starts with.
    public static var effect: MindGramRoundEffect {
        get {
            guard self.isEnabled else {
                return .off
            }
            return MindGramRoundEffect(rawValue: UserDefaults.standard.string(forKey: "MindGram.round.effect") ?? "") ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "MindGram.round.effect")
            self.notify()
        }
    }

    /// Effects offered by swiping the circle, in order.
    public static var swipeEffects: [MindGramRoundEffect] {
        return MindGramRoundEffect.allCases.filter { $0 == .off || !self.isHiddenFromSwipe($0) }
    }

    public static func isHiddenFromSwipe(_ effect: MindGramRoundEffect) -> Bool {
        return UserDefaults.standard.bool(forKey: "MindGram.round.hidden.\(effect.rawValue)")
    }

    public static func setHiddenFromSwipe(_ effect: MindGramRoundEffect, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: "MindGram.round.hidden.\(effect.rawValue)")
        self.notify()
    }

    /// Switch effects by swiping the circle left and right while recording.
    public static var swipeToSwitch: Bool {
        get { return UserDefaults.standard.object(forKey: "MindGram.round.swipe") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "MindGram.round.swipe")
            self.notify()
        }
    }

    /// Strength of blurs and pixels, 0...1.
    public static var strength: Double {
        get { return UserDefaults.standard.object(forKey: "MindGram.round.strength") as? Double ?? 0.7 }
        set {
            UserDefaults.standard.set(max(0.0, min(1.0, newValue)), forKey: "MindGram.round.strength")
            self.notify()
        }
    }

    /// The emoji of «Эмодзи-маска».
    public static let maskEmojis: [String] = ["🤡", "😎", "👽", "🐶", "🐱", "🐸", "🐼", "🦊", "💀", "🎃", "🤖", "👻", "😺", "🙈"]

    public static var maskEmoji: String {
        get { return UserDefaults.standard.string(forKey: "MindGram.round.emoji") ?? "🤡" }
        set {
            UserDefaults.standard.set(newValue, forKey: "MindGram.round.emoji")
            self.notify()
        }
    }

    /// Gradients for «Замена фона»: name and two colors.
    public static let backgrounds: [(ru: String, en: String, top: UIColor, bottom: UIColor)] = [
        ("Закат", "Sunset", UIColor(red: 1.0, green: 0.55, blue: 0.3, alpha: 1.0), UIColor(red: 0.55, green: 0.15, blue: 0.55, alpha: 1.0)),
        ("Океан", "Ocean", UIColor(red: 0.2, green: 0.75, blue: 0.95, alpha: 1.0), UIColor(red: 0.05, green: 0.2, blue: 0.5, alpha: 1.0)),
        ("Лес", "Forest", UIColor(red: 0.55, green: 0.85, blue: 0.45, alpha: 1.0), UIColor(red: 0.05, green: 0.35, blue: 0.2, alpha: 1.0)),
        ("Ночь", "Night", UIColor(red: 0.2, green: 0.2, blue: 0.35, alpha: 1.0), UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1.0)),
        ("Студия", "Studio", UIColor(white: 0.95, alpha: 1.0), UIColor(white: 0.7, alpha: 1.0)),
        ("Неон", "Neon", UIColor(red: 0.95, green: 0.2, blue: 0.75, alpha: 1.0), UIColor(red: 0.2, green: 0.3, blue: 1.0, alpha: 1.0))
    ]

    public static var backgroundIndex: Int {
        get { return min(max(0, UserDefaults.standard.integer(forKey: "MindGram.round.background")), self.backgrounds.count - 1) }
        set {
            UserDefaults.standard.set(newValue, forKey: "MindGram.round.background")
            self.notify()
        }
    }

    /// The effect currently applied by the camera; changes with swipes, starts at `effect`.
    public static var current: MindGramRoundEffect {
        get {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            return self.currentValue ?? self.effect
        }
        set {
            self.lock.lock()
            self.currentValue = newValue
            self.lock.unlock()
        }
    }

    private static let lock = NSLock()
    private static var currentValue: MindGramRoundEffect?

    /// Called when the camera opens: start from the chosen effect again.
    public static func resetCurrent() {
        self.lock.lock()
        self.currentValue = nil
        self.lock.unlock()
    }

    /// The next or previous effect for a swipe.
    public static func cycle(forward: Bool) -> MindGramRoundEffect {
        let list = self.swipeEffects
        let current = self.current
        let index = list.firstIndex(of: current) ?? 0
        let next = list[(index + (forward ? 1 : list.count - 1)) % list.count]
        self.current = next
        return next
    }
}
