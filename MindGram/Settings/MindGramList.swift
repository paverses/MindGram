import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

/// One row of a MindGram settings screen. Every screen is a list of these, built from the current settings.
enum MindGramListEntry: ItemListNodeEntry {
    case header(id: Int32, section: ItemListSectionId, text: String)
    case toggle(id: Int32, section: ItemListSectionId, title: String, info: String, value: Bool)
    case disclosure(id: Int32, section: ItemListSectionId, title: String, icon: String)
    case footer(id: Int32, section: ItemListSectionId, text: String)
    /// A row whose item the screen builds itself (sliders, previews); `revision` changes when it must redraw.
    case custom(id: Int32, section: ItemListSectionId, key: String, revision: Int)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _), let .disclosure(_, section, _, _), let .footer(_, section, _), let .custom(_, section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .disclosure(id, _, _, _), let .footer(id, _, _), let .custom(id, _, _, _):
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
        case let .footer(_, section, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        case let .custom(_, section, key, _):
            return arguments.customItem(key, presentationData, section)
        }
    }
}

final class MindGramListArguments {
    let toggle: (Int32, Bool) -> Void
    let open: (Int32) -> Void
    let icon: (String) -> UIImage?
    let customItem: (String, ItemListPresentationData, ItemListSectionId) -> ListViewItem

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
    return ItemListController(context: context, state: signal)
}
