import Foundation
import UIKit

public enum MindGramBadge {
    public enum Style: String, CaseIterable {
        case classic
        case dark
        case darkPurple
        case purple
        case green
        case pink
        case red
        case gold

        public func title(isRussian: Bool) -> String {
            switch self {
            case .classic:
                return isRussian ? "Классический" : "Classic"
            case .dark:
                return isRussian ? "Тёмный" : "Dark"
            case .darkPurple:
                return isRussian ? "Тёмно-фиолетовый" : "Dark Purple"
            case .purple:
                return isRussian ? "Фиолетовый" : "Purple"
            case .green:
                return isRussian ? "Зелёный" : "Green"
            case .pink:
                return isRussian ? "Розовый" : "Pink"
            case .red:
                return isRussian ? "Красный" : "Red"
            case .gold:
                return isRussian ? "Золотой" : "Gold"
            }
        }

        var colors: (top: UIColor, bottom: UIColor, glow: UIColor)? {
            func rgb(_ value: UInt32) -> UIColor {
                return UIColor(red: CGFloat((value >> 16) & 0xff) / 255.0, green: CGFloat((value >> 8) & 0xff) / 255.0, blue: CGFloat(value & 0xff) / 255.0, alpha: 1.0)
            }
            switch self {
            case .classic:
                return nil
            case .dark:
                return (rgb(0x2a2a2e), rgb(0x0a0a0c), rgb(0x8e8e93))
            case .darkPurple:
                return (rgb(0x2b1a4a), rgb(0x0d0718), rgb(0x7b4dff))
            case .purple:
                return (rgb(0x5b3bc4), rgb(0x241458), rgb(0xb18cff))
            case .green:
                return (rgb(0x16613a), rgb(0x062414), rgb(0x3ee08a))
            case .pink:
                return (rgb(0xa8336f), rgb(0x3d0f28), rgb(0xff7ac2))
            case .red:
                return (rgb(0xa32626), rgb(0x3a0909), rgb(0xff5a4f))
            case .gold:
                return (rgb(0x8a5a12), rgb(0x2e1c04), rgb(0xffc64a))
            }
        }
    }

    public static var style: Style {
        get { return Style(rawValue: UserDefaults.standard.string(forKey: "MindGram.badge.style") ?? "") ?? .classic }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "MindGram.badge.style")
            NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
        }
    }

    public static let size = CGSize(width: 186.0, height: 44.0)

    private static var cache: [Style: UIImage] = [:]

    public static func image(_ style: Style) -> UIImage? {
        if let image = self.cache[style] {
            return image
        }
        let image = UIImage(named: "Components/MindGramBadge_\(style.rawValue)", in: Bundle.main, compatibleWith: nil) ?? self.render(style)
        self.cache[style] = image
        return image
    }

    public static var currentImage: UIImage? {
        return self.image(self.style)
    }

    private static func render(_ style: Style) -> UIImage {
        let size = self.size
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let pillRect = CGRect(origin: CGPoint(), size: size).insetBy(dx: 2.0, dy: 2.0)
            let pill = UIBezierPath(roundedRect: pillRect, cornerRadius: pillRect.height / 2.0)
            let colors = style.colors

            if let colors {
                cg.saveGState()
                pill.addClip()
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [colors.top.cgColor, colors.bottom.cgColor] as CFArray, locations: [0.0, 1.0]) {
                    cg.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: pillRect.minY), end: CGPoint(x: 0.0, y: pillRect.maxY), options: [])
                }
                cg.restoreGState()
                cg.saveGState()
                colors.glow.withAlphaComponent(0.85).setStroke()
                pill.lineWidth = 1.5
                pill.stroke()
                cg.restoreGState()
            } else {
                UIColor.black.setFill()
                pill.fill()
            }

            let font = UIFont(name: "Unbounded-Bold", size: 20.0) ?? UIFont.systemFont(ofSize: 21.0, weight: .heavy)
            let text = NSAttributedString(string: "indGram", attributes: [.font: font, .foregroundColor: UIColor.white, .kern: 0.3])
            let textSize = text.size()
            let logoHeight: CGFloat = 16.0
            let logoSize = CGSize(width: logoHeight * MindGramLogo.aspectRatio, height: logoHeight)
            let spacing: CGFloat = 4.5
            let totalWidth = logoSize.width + spacing + textSize.width
            let originX = floor((size.width - totalWidth) / 2.0)

            cg.saveGState()
            UIColor.white.setFill()
            MindGramLogo.path(in: CGRect(x: originX, y: floor((size.height - logoSize.height) / 2.0), width: logoSize.width, height: logoSize.height)).fill()
            text.draw(at: CGPoint(x: originX + logoSize.width + spacing, y: floor((size.height - textSize.height) / 2.0)))
            cg.restoreGState()
        }
    }
}
