import Foundation
import UIKit
import CoreImage

/// "Фон из аватарки" (Оформление → Эксперименты): the profile photo, softly blurred, fills the whole screen behind
/// the profile; the large photo at the top fades into it instead of ending on a hard edge.
public final class MindGramAvatarBackdropView: UIView {
    private let imageView = UIImageView()
    private let dimView = UIView()

    /// The resource the current image came from, so the same photo is not loaded twice.
    public var imageKey: String?

    public init(isDark: Bool) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true

        self.imageView.contentMode = .scaleAspectFill
        self.imageView.clipsToBounds = true
        self.addSubview(self.imageView)
        self.addSubview(self.dimView)
        self.updateIsDark(isDark)
        self.alpha = 0.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setImage(_ image: UIImage?) {
        self.imageView.image = image
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = image == nil ? 0.0 : 1.0
        })
    }

    /// A light shade over the picture keeps text readable.
    public func updateIsDark(_ isDark: Bool) {
        self.dimView.backgroundColor = isDark ? UIColor(white: 0.0, alpha: 0.32) : UIColor(white: 1.0, alpha: 0.28)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.bounds
        self.dimView.frame = self.bounds
    }

    /// Loads a photo off the main queue and blurs it lightly: the picture stays recognisable.
    public static func loadImage(path: String, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = UIImage(contentsOfFile: path).flatMap { self.softlyBlurred($0) }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private static func softlyBlurred(_ image: UIImage) -> UIImage? {
        // Small copy first: the blur then costs little and still looks smooth when stretched.
        let side: CGFloat = 320.0
        let scale = min(1.0, side / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1.0, floor(image.size.width * scale)), height: max(1.0, floor(image.size.height * scale)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let input = CIImage(image: small), let filter = CIFilter(name: "CIGaussianBlur") else {
            return small
        }
        // Clamped so the edges don't turn transparent.
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(7.0, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent), let cgImage = CIContext(options: nil).createCGImage(output, from: input.extent) else {
            return small
        }
        return UIImage(cgImage: cgImage)
    }

    /// The fade on the large photo: opaque at the top, dissolving into the backdrop over its lower third.
    public static func makePhotoFadeMask() -> CAGradientLayer {
        let mask = CAGradientLayer()
        mask.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        mask.locations = [0.0, 0.66, 1.0]
        mask.startPoint = CGPoint(x: 0.5, y: 0.0)
        mask.endPoint = CGPoint(x: 0.5, y: 1.0)
        return mask
    }
}
