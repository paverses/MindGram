import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import MindGramCore

/// The icon of the "MindGram" row in Settings: the logo on a black rounded square, sized like the other settings icons.
public let mindGramSettingsIcon: UIImage = MindGramLogo.image(size: CGSize(width: 30.0, height: 30.0), color: .white, inset: 6.5, backgroundColor: .black, cornerRadius: 8.0)

private final class MindGramSettingsControllerArguments {
    let openAppearance: () -> Void
    let openTabs: () -> Void
    let openProfile: () -> Void

    init(openAppearance: @escaping () -> Void, openTabs: @escaping () -> Void, openProfile: @escaping () -> Void) {
        self.openAppearance = openAppearance
        self.openTabs = openTabs
        self.openProfile = openProfile
    }
}

private enum MindGramSettingsSection: Int32 {
    case features
}

private enum MindGramSettingsEntry: ItemListNodeEntry {
    case appearance(String)
    case tabs(String)
    case profile(String)
    case footer(String)

    var section: ItemListSectionId {
        return MindGramSettingsSection.features.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .appearance:
            return 0
        case .tabs:
            return 1
        case .profile:
            return 2
        case .footer:
            return 3
        }
    }

    static func <(lhs: MindGramSettingsEntry, rhs: MindGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MindGramSettingsControllerArguments
        switch self {
        case let .appearance(title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.appearance, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openAppearance()
            })
        case let .tabs(title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.chatFolders, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openTabs()
            })
        case let .profile(title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.myProfile, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openProfile()
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// The "MindGram" screen opened from Settings: one row per MindGram section.
public func mindGramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = MindGramSettingsControllerArguments(
        openAppearance: {
            pushControllerImpl?(mindGramAppearanceController(context: context))
        },
        openTabs: {
            pushControllerImpl?(mindGramTabsController(context: context))
        },
        openProfile: {
            pushControllerImpl?(mindGramProfileController(context: context))
        }
    )

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = MindGramStrings(presentationData)
        let entries: [MindGramSettingsEntry] = [
            .appearance(strings.appearance),
            .tabs(strings.tabs),
            .profile(strings.profile),
            .footer(strings.menuFooter)
        ]

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
