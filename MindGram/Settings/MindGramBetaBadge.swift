import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

final class MindGramBetaBadgeComponent: Component {
    let theme: PresentationTheme
    let action: () -> Void

    init(theme: PresentationTheme, action: @escaping () -> Void) {
        self.theme = theme
        self.action = action
    }

    static func ==(lhs: MindGramBetaBadgeComponent, rhs: MindGramBetaBadgeComponent) -> Bool {
        return lhs.theme === rhs.theme
    }

    final class View: UIView {
        private let label = UILabel()
        private var component: MindGramBetaBadgeComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.layer.cornerRadius = 5.0
            self.clipsToBounds = true
            self.addSubview(self.label)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func tapped() {
            self.component?.action()
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return self.bounds.insetBy(dx: -10.0, dy: -12.0).contains(point)
        }

        func update(component: MindGramBetaBadgeComponent, availableSize: CGSize) -> CGSize {
            self.component = component
            self.backgroundColor = component.theme.list.itemCheckColors.fillColor
            self.label.attributedText = NSAttributedString(string: "BETA", attributes: [.font: UIFont.systemFont(ofSize: 11.0, weight: .semibold), .foregroundColor: component.theme.list.itemCheckColors.foregroundColor])
            let textSize = self.label.sizeThatFits(CGSize(width: 100.0, height: 100.0))
            let size = CGSize(width: ceil(textSize.width) + 10.0, height: 16.0)
            self.label.frame = CGRect(x: 5.0, y: floor((size.height - textSize.height) / 2.0), width: ceil(textSize.width), height: ceil(textSize.height))
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}
