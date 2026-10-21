import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ItemListUI

/// A built-in colour palette for a settings row: circles to tap, the first one meaning "no colour of its own".
/// Colours are stored as "#RRGGBB"; "" is the first circle.
func mindGramColorPaletteItem(presentationData: ItemListPresentationData, sectionId: ItemListSectionId, selected: String, select: @escaping (String) -> Void) -> ListViewItem {
    return MindGramComponentItem(theme: presentationData.theme, height: 116.0, component: AnyComponent(MindGramColorPaletteComponent(theme: presentationData.theme, selected: selected, select: select)), sectionId: sectionId)
}

let mindGramPaletteColors: [String] = [
    "",
    "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
    "#32ADE6", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#8E8E93"
]

final class MindGramColorPaletteComponent: Component {
    let theme: PresentationTheme
    let selected: String
    let select: (String) -> Void

    init(theme: PresentationTheme, selected: String, select: @escaping (String) -> Void) {
        self.theme = theme
        self.selected = selected
        self.select = select
    }

    static func ==(lhs: MindGramColorPaletteComponent, rhs: MindGramColorPaletteComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.selected == rhs.selected
    }

    final class View: UIView {
        private var buttons: [UIButton] = []
        private var rings: [UIView] = []
        private var component: MindGramColorPaletteComponent?

        func update(component: MindGramColorPaletteComponent, availableSize: CGSize) -> CGSize {
            self.component = component
            if self.buttons.isEmpty {
                for (index, hex) in mindGramPaletteColors.enumerated() {
                    let ring = UIView()
                    ring.isUserInteractionEnabled = false
                    ring.layer.borderWidth = 2.0
                    self.addSubview(ring)
                    self.rings.append(ring)

                    let button = UIButton(type: .custom)
                    button.tag = index
                    if let color = UIColor(mindGramHex: hex) {
                        button.backgroundColor = color
                    } else {
                        button.setImage(UIImage(systemName: "clock", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)), for: .normal)
                    }
                    button.addTarget(self, action: #selector(self.pressed(_:)), for: .touchUpInside)
                    self.addSubview(button)
                    self.buttons.append(button)
                }
            }

            let perRow = 6
            let diameter: CGFloat = 34.0
            let rowHeight: CGFloat = 48.0
            let sideInset: CGFloat = 20.0
            let spacing = (availableSize.width - sideInset * 2.0 - diameter * CGFloat(perRow)) / CGFloat(perRow - 1)
            let rows = (self.buttons.count + perRow - 1) / perRow
            let topInset = floor((availableSize.height - CGFloat(rows) * rowHeight) / 2.0)
            for (index, button) in self.buttons.enumerated() {
                let row = index / perRow
                let column = index % perRow
                let frame = CGRect(x: sideInset + CGFloat(column) * (diameter + spacing), y: topInset + CGFloat(row) * rowHeight + (rowHeight - diameter) / 2.0, width: diameter, height: diameter)
                button.frame = frame
                button.layer.cornerRadius = diameter / 2.0
                let hex = mindGramPaletteColors[index]
                if hex.isEmpty {
                    button.backgroundColor = component.theme.list.itemBlocksSeparatorColor
                    button.tintColor = component.theme.list.itemSecondaryTextColor
                }
                let ring = self.rings[index]
                ring.frame = frame.insetBy(dx: -5.0, dy: -5.0)
                ring.layer.cornerRadius = ring.frame.width / 2.0
                ring.layer.borderColor = component.theme.list.itemAccentColor.cgColor
                ring.isHidden = hex.lowercased() != component.selected.lowercased()
            }
            return availableSize
        }

        @objc private func pressed(_ sender: UIButton) {
            guard let component = self.component, sender.tag < mindGramPaletteColors.count else {
                return
            }
            UISelectionFeedbackGenerator().selectionChanged()
            component.select(mindGramPaletteColors[sender.tag])
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

extension UIColor {
    /// "#RRGGBB" or "RRGGBB"; nil otherwise.
    convenience init?(mindGramHex hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let number = UInt32(value, radix: 16) else {
            return nil
        }
        self.init(red: CGFloat((number >> 16) & 0xff) / 255.0, green: CGFloat((number >> 8) & 0xff) / 255.0, blue: CGFloat(number & 0xff) / 255.0, alpha: 1.0)
    }
}
