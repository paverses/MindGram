import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ContextUI
import MindGramCore

/// "Новое меню сообщения" (Оформление → Эксперименты): Выбрать · Скопировать · Удалить as a row of three
/// buttons on top of every message menu. Takes Telegram's own items with these titles out of the list and
/// runs their actions from the row; a button whose item the message doesn't have is shown dimmed.
public func mindGramApplyQuickActions(_ items: [ContextMenuItem], selectTitle: String, copyTitle: String, deleteTitles: [String]) -> [ContextMenuItem] {
    guard MindGramSettings.isOn(.quickActionsMenu), !items.isEmpty else {
        return items
    }
    var select: ContextMenuActionItem?
    var copy: ContextMenuActionItem?
    var delete: ContextMenuActionItem?
    var rest: [ContextMenuItem] = []
    for item in items {
        if case let .action(action) = item {
            if select == nil && action.text == selectTitle {
                select = action
                continue
            }
            if copy == nil && action.text == copyTitle {
                copy = action
                continue
            }
            if delete == nil && deleteTitles.contains(action.text) {
                delete = action
                continue
            }
        }
        rest.append(item)
    }

    // No separators at the edges or twice in a row after removing items.
    var cleaned: [ContextMenuItem] = []
    for item in rest {
        if case .separator = item {
            if cleaned.isEmpty {
                continue
            }
            if let last = cleaned.last, case .separator = last {
                continue
            }
        }
        cleaned.append(item)
    }
    while let last = cleaned.last, case .separator = last {
        cleaned.removeLast()
    }

    let row = MindGramQuickActionsItem(buttons: [
        MindGramQuickActionsItem.Button(title: selectTitle, iconName: "checkmark.circle.fill", isDestructive: false, item: select),
        MindGramQuickActionsItem.Button(title: copyTitle, iconName: "doc.on.doc.fill", isDestructive: false, item: copy),
        MindGramQuickActionsItem.Button(title: deleteTitles.first ?? "", iconName: "trash.fill", isDestructive: true, item: delete)
    ])
    var result: [ContextMenuItem] = [.custom(row, false)]
    if !cleaned.isEmpty {
        result.append(.separator)
        result.append(contentsOf: cleaned)
    }
    return result
}

private final class MindGramQuickActionsItem: ContextMenuCustomItem {
    struct Button {
        let title: String
        let iconName: String
        let isDestructive: Bool
        let item: ContextMenuActionItem?
    }

    let buttons: [Button]

    init(buttons: [Button]) {
        self.buttons = buttons
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return MindGramQuickActionsNode(presentationData: presentationData, buttons: self.buttons, getController: getController, actionSelected: actionSelected)
    }
}

private final class MindGramQuickActionsNode: ASDisplayNode, ContextMenuCustomNode {
    private let buttons: [MindGramQuickActionsItem.Button]
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    private var presentationData: PresentationData

    private var controls: [UIControl] = []
    private var icons: [UIImageView] = []
    private var labels: [UILabel] = []
    private var dividers: [UIView] = []

    var needsSeparator: Bool {
        return false
    }

    var needsPadding: Bool {
        return false
    }

    init(presentationData: PresentationData, buttons: [MindGramQuickActionsItem.Button], getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.presentationData = presentationData
        self.buttons = buttons
        self.getController = getController
        self.actionSelected = actionSelected
        super.init()
    }

    override func didLoad() {
        super.didLoad()
        for (index, button) in self.buttons.enumerated() {
            let control = UIControl()
            control.tag = index
            control.isEnabled = button.item != nil
            control.addTarget(self, action: #selector(self.pressed(_:)), for: .touchUpInside)
            control.addTarget(self, action: #selector(self.highlight(_:)), for: [.touchDown, .touchDragEnter])
            control.addTarget(self, action: #selector(self.unhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            self.view.addSubview(control)
            self.controls.append(control)

            let icon = UIImageView()
            icon.contentMode = .center
            icon.isUserInteractionEnabled = false
            control.addSubview(icon)
            self.icons.append(icon)

            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 13.0, weight: .regular)
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            label.text = button.title
            control.addSubview(label)
            self.labels.append(label)

            if index > 0 {
                let divider = UIView()
                divider.isUserInteractionEnabled = false
                self.view.addSubview(divider)
                self.dividers.append(divider)
            }
        }
        self.applyTheme()
    }

    private func applyTheme() {
        let theme = self.presentationData.theme.contextMenu
        for (index, button) in self.buttons.enumerated() where index < self.icons.count {
            var color = button.isDestructive ? theme.destructiveColor : theme.primaryColor
            if button.item == nil {
                color = color.withAlphaComponent(0.35)
            }
            // Filled SF Symbols: the outline icons left their insides empty.
            self.icons[index].image = UIImage(systemName: button.iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22.0, weight: .medium))?.withRenderingMode(.alwaysTemplate)
            self.icons[index].tintColor = color
            self.labels[index].textColor = color
        }
        for divider in self.dividers {
            divider.backgroundColor = theme.itemSeparatorColor
        }
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let height: CGFloat = 68.0
        let width = max(constrainedWidth, 250.0)
        return (CGSize(width: width, height: height), { [weak self] size, _ in
            guard let self, !self.controls.isEmpty else {
                return
            }
            let count = CGFloat(self.controls.count)
            let buttonWidth = size.width / count
            for (index, control) in self.controls.enumerated() {
                control.frame = CGRect(x: CGFloat(index) * buttonWidth, y: 0.0, width: buttonWidth, height: size.height)
                self.icons[index].frame = CGRect(x: 0.0, y: 10.0, width: buttonWidth, height: 28.0)
                self.labels[index].frame = CGRect(x: 4.0, y: 40.0, width: buttonWidth - 8.0, height: 18.0)
            }
            for (index, divider) in self.dividers.enumerated() {
                divider.frame = CGRect(x: CGFloat(index + 1) * buttonWidth - UIScreenPixel / 2.0, y: 12.0, width: UIScreenPixel, height: size.height - 24.0)
            }
        })
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        if self.isNodeLoaded {
            self.applyTheme()
        }
    }

    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func performAction() {
    }

    @objc private func highlight(_ sender: UIControl) {
        sender.backgroundColor = self.presentationData.theme.contextMenu.itemHighlightedBackgroundColor
    }

    @objc private func unhighlight(_ sender: UIControl) {
        UIView.animate(withDuration: 0.2, animations: {
            sender.backgroundColor = .clear
        })
    }

    @objc private func pressed(_ sender: UIControl) {
        guard sender.tag < self.buttons.count, let item = self.buttons[sender.tag].item, let action = item.action else {
            return
        }
        action(ContextMenuActionItem.Action(controller: self.getController(), dismissWithResult: self.actionSelected, updateAction: { _, _ in }))
    }
}
