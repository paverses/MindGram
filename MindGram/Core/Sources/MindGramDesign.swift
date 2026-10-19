import Foundation
import UIKit

/// MindGram-specific switches that have to be known before the first screen is built.
///
/// The classic (pre-glass, Telegram 2019–2024) design is read once per launch: the bars, lists and
/// glass panels pick their style when they are created, so a change made in the MindGram settings
/// is stored for the next launch and the user is asked to restart the app.
public enum MindGramDesign {
    private static let classicDesignKey = "MindGram.classicDesign"

    /// The design the running process was started with. Never changes until the app is restarted.
    public static let isClassic: Bool = UserDefaults.standard.bool(forKey: MindGramDesign.classicDesignKey)

    /// The design that will be used after the next launch.
    public static var isClassicOnNextLaunch: Bool {
        return UserDefaults.standard.bool(forKey: MindGramDesign.classicDesignKey)
    }

    public static func setClassicOnNextLaunch(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: MindGramDesign.classicDesignKey)
    }
}

/// The MindGram logo: a bowl above two feet, drawn in a 69 x 54.5 unit box.
public enum MindGramLogo {
    public static let aspectRatio: CGFloat = 69.0 / 54.5

    public static func path(in rect: CGRect) -> UIBezierPath {
        let scale = min(rect.width / 69.0, rect.height / 54.5)
        let origin = CGPoint(x: rect.midX - 69.0 * scale * 0.5, y: rect.midY - 54.5 * scale * 0.5)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            return CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        let path = UIBezierPath()

        // Bowl: the lower half of a disc with a smaller half-disc notch cut from its top edge.
        path.move(to: point(0.0, 0.0))
        path.addLine(to: point(20.5, 0.0))
        path.addArc(withCenter: point(34.5, 0.0), radius: 14.0 * scale, startAngle: .pi, endAngle: 0.0, clockwise: false)
        path.addLine(to: point(69.0, 0.0))
        path.addArc(withCenter: point(34.5, 0.0), radius: 34.5 * scale, startAngle: 0.0, endAngle: .pi, clockwise: true)
        path.close()

        // Feet: quarter discs anchored at the bottom corners, cut to the width of the bowl's rim.
        let footRadius: CGFloat = 23.0
        let footCutY = 54.5 - sqrt(footRadius * footRadius - 20.0 * 20.0)

        path.move(to: point(0.0, 54.5 - footRadius))
        path.addArc(withCenter: point(0.0, 54.5), radius: footRadius * scale, startAngle: -.pi * 0.5, endAngle: -asin((54.5 - footCutY) / footRadius), clockwise: true)
        path.addLine(to: point(20.0, 54.5))
        path.addLine(to: point(0.0, 54.5))
        path.close()

        path.move(to: point(69.0, 54.5 - footRadius))
        path.addArc(withCenter: point(69.0, 54.5), radius: footRadius * scale, startAngle: -.pi * 0.5, endAngle: -.pi + asin((54.5 - footCutY) / footRadius), clockwise: false)
        path.addLine(to: point(49.0, 54.5))
        path.addLine(to: point(69.0, 54.5))
        path.close()

        return path
    }

    /// The logo filled with `color`, fitted into `size` with `inset` on every side.
    public static func image(size: CGSize, color: UIColor, inset: CGFloat = 0.0, backgroundColor: UIColor? = nil, cornerRadius: CGFloat = 0.0) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { _ in
            if let backgroundColor {
                backgroundColor.setFill()
                UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: cornerRadius).fill()
            }
            color.setFill()
            MindGramLogo.path(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset)).fill()
        }
    }
}

/// Branding switches for places where Telegram's own artwork would otherwise show up.
public enum MindGramBranding {
    /// Telegram's alternate app icons all carry the Telegram logo, so MindGram offers none.
    public static let offersTelegramAlternateIcons: Bool = false
}

/// Where MindGram keeps its data when Telegram's shared app group is unavailable.
public enum MindGramStorage {
    /// A build re-signed with a personal Apple ID (Sideloadly, AltStore) often has no access to the
    /// `group.<bundle id>` container, and Telegram then stops launching on a black screen. This folder in
    /// the app's own container takes its place; the share and notification extensions can't see it.
    public static func fallbackAppGroupUrl() -> URL? {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = library.appendingPathComponent("MindGramAppGroup", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
