import Foundation
import UIKit

/// «Бейдж в вырезе»: the small label under the notch or Dynamic Island. Telegram's own artwork, or one of
/// MindGram's, drawn here at the same 93 x 22 pt so it sits in the same place.
public enum MindGramBadge {
    public enum Style: String, CaseIterable {
        case telegram
        case logo
        case logoText
        case text
        case gradient
        case neon
        case gold
        case aurora
        case monogram
        case sparkles

        public func title(isRussian: Bool) -> String {
            switch self {
            case .telegram:
                return isRussian ? "Как в Telegram" : "Telegram's"
            case .logo:
                return isRussian ? "Логотип" : "Logo"
            case .logoText:
                return isRussian ? "Логотип и имя" : "Logo and Name"
            case .text:
                return "MindGram"
            case .gradient:
                return isRussian ? "Градиент" : "Gradient"
            case .neon:
                return isRussian ? "Неон" : "Neon"
            case .gold:
                return isRussian ? "Золото" : "Gold"
            case .aurora:
                return isRussian ? "Северное сияние" : "Aurora"
            case .monogram:
                return isRussian ? "Монограмма MG" : "MG Monogram"
            case .sparkles:
                return isRussian ? "Искры" : "Sparkles"
            }
        }
    }

    public static var style: Style {
        get { return Style(rawValue: UserDefaults.standard.string(forKey: "MindGram.badge.style") ?? "") ?? .telegram }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "MindGram.badge.style")
            NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
        }
    }

    public static let size = CGSize(width: 93.0, height: 22.0)

    /// The badge for `style`; nil for `.telegram` (the app keeps its bundled image).
    public static func image(_ style: Style) -> UIImage? {
        let size = self.size
        switch style {
        case .telegram:
            return nil
        case .logo:
            return MindGramLogo.image(size: size, color: .white, inset: 4.0)
        case .logoText:
            return UIGraphicsImageRenderer(size: size).image { _ in
                let text = self.attributed("MindGram", size: 13.0, color: .white)
                let logoSize = CGSize(width: 12.0 * MindGramLogo.aspectRatio, height: 12.0)
                let totalWidth = logoSize.width + 5.0 + text.size().width
                let x = (size.width - totalWidth) / 2.0
                UIColor.white.setFill()
                MindGramLogo.path(in: CGRect(x: x, y: (size.height - logoSize.height) / 2.0, width: logoSize.width, height: logoSize.height)).fill()
                text.draw(at: CGPoint(x: x + logoSize.width + 5.0, y: (size.height - text.size().height) / 2.0))
            }
        case .text:
            return self.textBadge("MindGram", fill: { _ in UIColor.white.setFill() })
        case .gradient:
            return self.gradientText("MindGram", colors: [UIColor(red: 0.62, green: 0.4, blue: 1.0, alpha: 1.0), UIColor(red: 0.25, green: 0.6, blue: 1.0, alpha: 1.0)])
        case .gold:
            return self.gradientText("MindGram", colors: [UIColor(red: 1.0, green: 0.86, blue: 0.45, alpha: 1.0), UIColor(red: 0.85, green: 0.6, blue: 0.2, alpha: 1.0)])
        case .aurora:
            return self.gradientText("MindGram", colors: [UIColor(red: 0.3, green: 1.0, blue: 0.75, alpha: 1.0), UIColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 1.0), UIColor(red: 0.85, green: 0.45, blue: 1.0, alpha: 1.0)])
        case .neon:
            return UIGraphicsImageRenderer(size: size).image { context in
                let color = UIColor(red: 0.3, green: 0.95, blue: 1.0, alpha: 1.0)
                context.cgContext.setShadow(offset: .zero, blur: 4.0, color: color.cgColor)
                let text = self.attributed("MindGram", size: 13.0, color: color)
                text.draw(at: CGPoint(x: (size.width - text.size().width) / 2.0, y: (size.height - text.size().height) / 2.0))
            }
        case .monogram:
            return UIGraphicsImageRenderer(size: size).image { _ in
                let pill = CGRect(x: (size.width - 34.0) / 2.0, y: 2.0, width: 34.0, height: size.height - 4.0)
                UIColor(white: 1.0, alpha: 0.18).setFill()
                UIBezierPath(roundedRect: pill, cornerRadius: pill.height / 2.0).fill()
                let text = self.attributed("MG", size: 12.0, color: .white, weight: .heavy)
                text.draw(at: CGPoint(x: pill.midX - text.size().width / 2.0, y: pill.midY - text.size().height / 2.0))
            }
        case .sparkles:
            return UIGraphicsImageRenderer(size: size).image { _ in
                let text = self.attributed("✦ MindGram ✦", size: 12.0, color: UIColor(red: 1.0, green: 0.92, blue: 0.6, alpha: 1.0))
                text.draw(at: CGPoint(x: (size.width - text.size().width) / 2.0, y: (size.height - text.size().height) / 2.0))
                UIColor(white: 1.0, alpha: 0.7).setFill()
                for point in [CGPoint(x: 6.0, y: 4.0), CGPoint(x: 86.0, y: 16.0), CGPoint(x: 14.0, y: 17.0), CGPoint(x: 80.0, y: 5.0)] {
                    UIBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: 1.6, height: 1.6)).fill()
                }
            }
        }
    }

    /// The image the window shows now.
    public static var currentImage: UIImage? {
        return self.image(self.style)
    }

    private static func attributed(_ text: String, size: CGFloat, color: UIColor, weight: UIFont.Weight = .semibold) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: 0.2])
    }

    private static func textBadge(_ text: String, fill: (CGContext) -> Void) -> UIImage {
        let size = self.size
        return UIGraphicsImageRenderer(size: size).image { context in
            fill(context.cgContext)
            let string = self.attributed(text, size: 13.0, color: .white)
            string.draw(at: CGPoint(x: (size.width - string.size().width) / 2.0, y: (size.height - string.size().height) / 2.0))
        }
    }

    /// Text filled with a horizontal gradient (drawn as a mask).
    private static func gradientText(_ text: String, colors: [UIColor]) -> UIImage? {
        let size = self.size
        let mask = UIGraphicsImageRenderer(size: size).image { _ in
            let string = self.attributed(text, size: 13.0, color: .white, weight: .bold)
            string.draw(at: CGPoint(x: (size.width - string.size().width) / 2.0, y: (size.height - string.size().height) / 2.0))
        }
        guard let maskImage = mask.cgImage else {
            return mask
        }
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.translateBy(x: 0.0, y: size.height)
            cg.scaleBy(x: 1.0, y: -1.0)
            cg.clip(to: CGRect(origin: CGPoint(), size: size), mask: maskImage)
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil) {
                cg.drawLinearGradient(gradient, start: CGPoint(x: 10.0, y: 0.0), end: CGPoint(x: size.width - 10.0, y: 0.0), options: [])
            }
        }
    }
}
