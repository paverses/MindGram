import Foundation
import UIKit

/// "Фон из аватарки" (Оформление → Эксперименты): the profile photo, blurred, continues below the photo behind
/// the buttons and the first rows, and fades into the screen colour further down.
public final class MindGramAvatarBackdropView: UIView {
    private let imageView = UIImageView()
    private let blurView: UIVisualEffectView
    private let fadeMask = CAGradientLayer()

    /// The resource the current image came from, so the same photo is not loaded twice.
    public var imageKey: String?

    public init(isDark: Bool) {
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: isDark ? .systemThickMaterialDark : .systemThickMaterialLight))
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true

        self.imageView.contentMode = .scaleAspectFill
        self.imageView.clipsToBounds = true
        self.addSubview(self.imageView)
        self.addSubview(self.blurView)

        self.fadeMask.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        self.fadeMask.locations = [0.0, 0.62, 1.0]
        self.layer.mask = self.fadeMask
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

    public func updateIsDark(_ isDark: Bool) {
        self.blurView.effect = UIBlurEffect(style: isDark ? .systemThickMaterialDark : .systemThickMaterialLight)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.bounds
        self.blurView.frame = self.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fadeMask.frame = self.bounds
        CATransaction.commit()
    }

    /// Loads a photo file off the main queue, shrunk (the blur hides detail anyway).
    public static func loadImage(path: String, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var result: UIImage?
            if let image = UIImage(contentsOfFile: path) {
                let side: CGFloat = 240.0
                let scale = min(1.0, side / max(image.size.width, image.size.height))
                let size = CGSize(width: max(1.0, floor(image.size.width * scale)), height: max(1.0, floor(image.size.height * scale)))
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1.0
                result = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
