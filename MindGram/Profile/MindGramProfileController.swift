import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private enum MindGramProfileSection: Int32 {
    case info
}

private enum MindGramProfileEntry: ItemListNodeEntry {
    case soon(String)

    var section: ItemListSectionId {
        return MindGramProfileSection.info.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .soon:
            return 0
        }
    }

    static func <(lhs: MindGramProfileEntry, rhs: MindGramProfileEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .soon(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// Профиль: profile features. Empty for now; each new feature gets a row with a switch here.
func mindGramProfileController(context: AccountContext) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = MindGramStrings(presentationData)
        let entries: [MindGramProfileEntry] = [
            .soon(strings.profileSoon)
        ]

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.profile), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, 0))
    }

    return ItemListController(context: context, state: signal)
}
