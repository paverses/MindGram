import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class MindGramTabsControllerArguments {
    let updateShowCallsTab: (Bool) -> Void

    init(updateShowCallsTab: @escaping (Bool) -> Void) {
        self.updateShowCallsTab = updateShowCallsTab
    }
}

private enum MindGramTabsSection: Int32 {
    case tabs
}

private enum MindGramTabsEntry: ItemListNodeEntry {
    case callsTab(title: String, text: String, value: Bool)

    var section: ItemListSectionId {
        return MindGramTabsSection.tabs.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .callsTab:
            return 0
        }
    }

    static func <(lhs: MindGramTabsEntry, rhs: MindGramTabsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MindGramTabsControllerArguments
        switch self {
        case let .callsTab(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateShowCallsTab(value)
            })
        }
    }
}

/// Вкладки: which tabs the bottom bar shows. Uses Telegram's own tab settings, so changes apply at once.
func mindGramTabsController(context: AccountContext) -> ViewController {
    let arguments = MindGramTabsControllerArguments(updateShowCallsTab: { value in
        let _ = updateCallListSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.showTab = value
            return settings
        }).start()
    })

    let callListSettings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.callListSettings])
    |> map { sharedData -> CallListSettings in
        return sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings]?.get(CallListSettings.self) ?? CallListSettings.defaultSettings
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        callListSettings
    )
    |> map { presentationData, callListSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = MindGramStrings(presentationData)
        let entries: [MindGramTabsEntry] = [
            .callsTab(title: strings.callsTab, text: strings.callsTabInfo, value: callListSettings.showTab)
        ]

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.tabs), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
