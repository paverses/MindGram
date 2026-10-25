import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TextFormat
import ComponentFlow

/// How a status row is colored: works, off, problem.
enum MindGramStatusTone: Int {
    case ok
    case off
    case problem
}

/// One row of a MindGram settings screen. Every screen is a list of these, built from the current settings.
enum MindGramListEntry: ItemListNodeEntry {
    case header(id: Int32, section: ItemListSectionId, text: String)
    case toggle(id: Int32, section: ItemListSectionId, title: String, info: String, value: Bool)
    case disclosure(id: Int32, section: ItemListSectionId, title: String, icon: String)
    case footer(id: Int32, section: ItemListSectionId, text: String)
    /// A row whose item the screen builds itself (sliders, previews); `revision` changes when it must redraw.
    case custom(id: Int32, section: ItemListSectionId, key: String, revision: Int)
    /// A title with a colored status on the right; tapping calls `open`.
    case status(id: Int32, section: ItemListSectionId, title: String, value: String, tone: MindGramStatusTone)
    /// A button row; tapping calls `open`.
    case action(id: Int32, section: ItemListSectionId, title: String)
    /// Multiline text: plain words, or monospaced code such as an error with its place in the code.
    case text(id: Int32, section: ItemListSectionId, text: String, monospace: Bool)
    /// A choice with a checkmark; tapping calls `open`.
    case check(id: Int32, section: ItemListSectionId, title: String, checked: Bool)
    /// A title with the current value on the right and an arrow; tapping calls `open`.
    case value(id: Int32, section: ItemListSectionId, title: String, value: String)
    /// A title with a few lines of detail under it (history rows); tapping calls `open`.
    case detail(id: Int32, section: ItemListSectionId, title: String, detail: String)
    case betaDisclosure(id: Int32, section: ItemListSectionId, title: String, icon: String)
    case toggleEx(id: Int32, section: ItemListSectionId, title: String, info: String, value: Bool, enabled: Bool, beta: Bool)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _), let .disclosure(_, section, _, _), let .footer(_, section, _), let .custom(_, section, _, _), let .status(_, section, _, _, _), let .action(_, section, _), let .text(_, section, _, _), let .check(_, section, _, _), let .value(_, section, _, _), let .detail(_, section, _, _), let .betaDisclosure(_, section, _, _), let .toggleEx(_, section, _, _, _, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .disclosure(id, _, _, _), let .footer(id, _, _), let .custom(id, _, _, _), let .status(id, _, _, _, _), let .action(id, _, _), let .text(id, _, _, _), let .check(id, _, _, _), let .value(id, _, _, _), let .detail(id, _, _, _), let .betaDisclosure(id, _, _, _), let .toggleEx(id, _, _, _, _, _, _):
            return id
        }
    }

    static func <(lhs: MindGramListEntry, rhs: MindGramListEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MindGramListArguments
        switch self {
        case let .header(_, section, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .toggle(id, section, title, info, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: info, value: value, sectionId: section, style: .blocks, updated: { value in
                arguments.toggle(id, value)
            })
        case let .disclosure(id, section, title, icon):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: arguments.icon(icon), title: title, label: "", sectionId: section, style: .blocks, action: {
                arguments.open(id)
            })
        case let .betaDisclosure(id, section, title, icon):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: arguments.icon(icon), title: title, titleBadge: "BETA", titleBadgeAction: {
                arguments.presentBeta?()
            }, label: "", sectionId: section, style: .blocks, action: {
                arguments.open(id)
            })
        case let .toggleEx(id, section, title, info, value, enabled, beta):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: info.isEmpty ? nil : info, titleBadgeComponent: beta ? AnyComponent(MindGramBetaBadgeComponent(theme: presentationData.theme, action: {
                arguments.presentBeta?()
            })) : nil, value: value && enabled, enabled: enabled, sectionId: section, style: .blocks, updated: { value in
                arguments.toggle(id, value)
            })
        case let .footer(_, section, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        case let .custom(_, section, key, _):
            return arguments.customItem(key, presentationData, section)
        case let .status(id, section, title, value, tone):
            let color: UIColor
            switch tone {
            case .ok:
                color = UIColor(rgb: 0x34c759)
            case .off:
                color = presentationData.theme.list.itemSecondaryTextColor
            case .problem:
                color = presentationData.theme.list.itemDestructiveColor
            }
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, labelStyle: .coloredText(color), sectionId: section, style: .blocks, action: {
                arguments.open(id)
            })
        case let .action(id, section, title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: section, style: .blocks, action: {
                arguments.open(id)
            })
        case let .text(_, section, text, monospace):
            return ItemListMultilineTextItem(presentationData: presentationData, text: text, enabledEntityTypes: [], font: monospace ? .monospace : .default, sectionId: section, style: .blocks)
        case let .check(id, section, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: section, action: {
                arguments.open(id)
            })
        case let .value(id, section, title, value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, sectionId: section, style: .blocks, action: {
                arguments.open(id)
            })
        case let .detail(id, section, title, detail):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: detail, labelStyle: .multilineDetailText, sectionId: section, style: .blocks, disclosureStyle: .none, action: {
                arguments.open(id)
            })
        }
    }
}

final class MindGramListArguments {
    let toggle: (Int32, Bool) -> Void
    let open: (Int32) -> Void
    let icon: (String) -> UIImage?
    let customItem: (String, ItemListPresentationData, ItemListSectionId) -> ListViewItem
    var presentBeta: (() -> Void)?

    init(
        toggle: @escaping (Int32, Bool) -> Void = { _, _ in },
        open: @escaping (Int32) -> Void = { _ in },
        icon: @escaping (String) -> UIImage? = { _ in nil },
        customItem: @escaping (String, ItemListPresentationData, ItemListSectionId) -> ListViewItem = { _, presentationData, section in
            return ItemListTextItem(presentationData: presentationData, text: .plain(""), sectionId: section)
        }
    ) {
        self.toggle = toggle
        self.open = open
        self.icon = icon
        self.customItem = customItem
    }
}

/// A MindGram settings screen: `entries` is rebuilt whenever the presentation data or a MindGram setting changes.
func mindGramListController(
    context: AccountContext,
    title: @escaping (MindGramStrings) -> String,
    arguments: MindGramListArguments,
    extraUpdates: Signal<Void, NoError> = .single(Void()),
    entries: @escaping (PresentationData, MindGramStrings) -> [MindGramListEntry]
) -> ViewController {
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        mindGramSettingsUpdated(),
        extraUpdates
    )
    |> map { presentationData, _, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = MindGramStrings(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title(strings)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries(presentationData, strings), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    arguments.presentBeta = { [weak controller] in
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        controller?.present(textAlertController(context: context, title: "BETA", text: strings.betaText, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window(.root))
    }
    return controller
}
