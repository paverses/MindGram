import Foundation
import UIKit

/// The masks menu under the circle while a round video is recorded: a row of round buttons, one per effect.
/// A tap switches the effect at once (preview and recording).
public final class MindGramRoundEffectsBar: UIView {
    private let scrollView = UIScrollView()
    private var buttons: [UIControl] = []
    private let effects: [MindGramRoundEffect]
    private let isRussian: Bool
    public var effectChanged: ((MindGramRoundEffect) -> Void)?

    public static let height: CGFloat = 82.0

    private static func symbol(_ effect: MindGramRoundEffect) -> String {
        switch effect {
        case .off:
            return "🚫"
        case .faceBlur:
            return "😶‍🌫️"
        case .facePixelate:
            return "👾"
        case .backgroundBlur:
            return "🌫"
        case .backgroundReplace:
            return "🌅"
        case .emojiMask:
            return MindGramRoundVideo.maskEmoji
        case .sunglasses:
            return "🕶️"
        case .crown:
            return "👑"
        case .halo:
            return "😇"
        case .horns:
            return "😈"
        case .noir:
            return "🖤"
        case .vintage:
            return "📷"
        case .comic:
            return "💥"
        case .thermal:
            return "🔥"
        case .xray:
            return "🩻"
        case .beauty:
            return "✨"
        case .glitch:
            return "📺"
        case .vhs:
            return "📼"
        case .kaleidoscope:
            return "🔮"
        }
    }

    public init(isRussian: Bool) {
        self.isRussian = isRussian
        self.effects = MindGramRoundVideo.swipeEffects
        super.init(frame: .zero)

        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.addSubview(self.scrollView)

        for (index, effect) in self.effects.enumerated() {
            let button = UIControl()
            button.tag = index
            button.addTarget(self, action: #selector(self.pressed(_:)), for: .touchUpInside)

            let circle = UIView()
            circle.isUserInteractionEnabled = false
            circle.backgroundColor = UIColor(white: 0.0, alpha: 0.35)
            circle.layer.cornerRadius = 27.0
            circle.layer.borderWidth = 2.0
            circle.layer.borderColor = UIColor.clear.cgColor
            circle.tag = 1
            button.addSubview(circle)

            let emoji = UILabel()
            emoji.text = MindGramRoundEffectsBar.symbol(effect)
            emoji.font = UIFont.systemFont(ofSize: 26.0)
            emoji.textAlignment = .center
            emoji.tag = 2
            circle.addSubview(emoji)

            let title = UILabel()
            title.text = effect.title(isRussian: isRussian)
            title.font = UIFont.systemFont(ofSize: 10.0, weight: .medium)
            title.textColor = .white
            title.textAlignment = .center
            title.adjustsFontSizeToFitWidth = true
            title.minimumScaleFactor = 0.7
            title.layer.shadowColor = UIColor.black.cgColor
            title.layer.shadowOpacity = 0.5
            title.layer.shadowRadius = 2.0
            title.layer.shadowOffset = .zero
            title.tag = 3
            button.addSubview(title)

            self.scrollView.addSubview(button)
            self.buttons.append(button)
        }
        self.updateSelection(animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.scrollView.frame = self.bounds
        let itemWidth: CGFloat = 66.0
        let sideInset: CGFloat = 12.0
        for (index, button) in self.buttons.enumerated() {
            button.frame = CGRect(x: sideInset + CGFloat(index) * itemWidth, y: 0.0, width: itemWidth, height: self.bounds.height)
            if let circle = button.viewWithTag(1) {
                circle.frame = CGRect(x: (itemWidth - 54.0) / 2.0, y: 4.0, width: 54.0, height: 54.0)
                circle.viewWithTag(2)?.frame = circle.bounds
            }
            button.viewWithTag(3)?.frame = CGRect(x: 2.0, y: 62.0, width: itemWidth - 4.0, height: 14.0)
        }
        self.scrollView.contentSize = CGSize(width: sideInset * 2.0 + CGFloat(self.buttons.count) * itemWidth, height: self.bounds.height)
    }

    /// Marks the effect the camera uses now (also after a swipe on the circle).
    public func updateSelection(animated: Bool) {
        let current = MindGramRoundVideo.current
        for (index, button) in self.buttons.enumerated() {
            let selected = self.effects[index] == current
            if let circle = button.viewWithTag(1) {
                circle.layer.borderColor = selected ? UIColor.white.cgColor : UIColor.clear.cgColor
                circle.backgroundColor = selected ? UIColor(white: 1.0, alpha: 0.25) : UIColor(white: 0.0, alpha: 0.35)
            }
            if selected && self.bounds.width > 0.0 {
                self.scrollView.scrollRectToVisible(button.frame.insetBy(dx: -60.0, dy: 0.0), animated: animated)
            }
        }
    }

    @objc private func pressed(_ sender: UIControl) {
        guard sender.tag < self.effects.count else {
            return
        }
        let effect = self.effects[sender.tag]
        MindGramRoundVideo.current = effect
        UISelectionFeedbackGenerator().selectionChanged()
        self.updateSelection(animated: true)
        self.effectChanged?(effect)
    }
}
