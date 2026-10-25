import Foundation
import UIKit

public enum MindGramMarks {
    public enum Kind: String, CaseIterable {
        case hold
        case major
        case mind

        public var title: String {
            switch self {
            case .hold:
                return "Hold"
            case .major:
                return "Major"
            case .mind:
                return "Mind"
            }
        }

        public func confirmedText(isRussian: Bool) -> String {
            return isRussian ? "Подтверждено \(self.title)" : "Verified by \(self.title)"
        }
    }

    private static let key = "MindGram.marks"
    private static var cache: [String: UIImage] = [:]

    public static func mark(peerId: Int64) -> Kind? {
        guard let values = UserDefaults.standard.dictionary(forKey: self.key) as? [String: String], let raw = values["\(peerId)"] else {
            return nil
        }
        return Kind(rawValue: raw)
    }

    public static func setMark(peerId: Int64, _ kind: Kind?) {
        var values = UserDefaults.standard.dictionary(forKey: self.key) as? [String: String] ?? [:]
        values["\(peerId)"] = kind?.rawValue
        UserDefaults.standard.set(values, forKey: self.key)
        NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
    }

    private static func lottiePath(_ points: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)], transform: (CGPoint) -> CGPoint, scale: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        guard let first = points.first else {
            return path
        }
        path.move(to: transform(CGPoint(x: first.0, y: first.1)))
        for index in 0 ..< points.count {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let to = transform(CGPoint(x: next.0, y: next.1))
            let from = transform(CGPoint(x: current.0, y: current.1))
            let control1 = CGPoint(x: from.x + current.4 * scale, y: from.y + current.5 * scale)
            let control2 = CGPoint(x: to.x + next.2 * scale, y: to.y + next.3 * scale)
            path.addCurve(to: to, controlPoint1: control1, controlPoint2: control2)
        }
        path.close()
        return path
    }

    private static func crownPath(transform: (CGPoint) -> CGPoint) -> UIBezierPath {
        let points: [CGPoint] = [CGPoint(x: -105.0, y: 70.0), CGPoint(x: 105.0, y: 70.0), CGPoint(x: 122.0, y: -60.0), CGPoint(x: 55.0, y: -2.0), CGPoint(x: 0.0, y: -92.0), CGPoint(x: -55.0, y: -2.0), CGPoint(x: -122.0, y: -60.0)]
        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            if index == 0 {
                path.move(to: transform(point))
            } else {
                path.addLine(to: transform(point))
            }
        }
        path.close()
        return path
    }

    public static func image(_ kind: Kind, size: CGFloat) -> UIImage {
        let cacheKey = "\(kind.rawValue)-\(size)"
        if let image = self.cache[cacheKey] {
            return image
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            let scale = size / 512.0
            let transform: (CGPoint) -> CGPoint = { point in
                return CGPoint(x: (point.x + 256.0) * scale, y: (point.y + 256.0) * scale)
            }
            let path = self.lottiePath(MindGramMarkGeometry.rosette, transform: transform, scale: scale)
            switch kind {
            case .hold:
                path.append(self.lottiePath(MindGramMarkGeometry.star, transform: transform, scale: scale))
            case .major:
                path.append(self.crownPath(transform: transform))
            case .mind:
                let glyphWidth = 0.46 * 512.0 * scale
                let glyphHeight = glyphWidth / MindGramLogo.aspectRatio
                path.append(MindGramLogo.path(in: CGRect(x: (size - glyphWidth) / 2.0, y: (size - glyphHeight) / 2.0, width: glyphWidth, height: glyphHeight)))
            }
            path.usesEvenOddFillRule = true
            UIColor.white.setFill()
            path.fill()
        }.withRenderingMode(.alwaysTemplate)
        self.cache[cacheKey] = image
        return image
    }
}
