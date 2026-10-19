import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import MindGramCore

private final class MindGramAppearanceControllerArguments {
    let updateClassicDesign: (Bool) -> Void

    init(updateClassicDesign: @escaping (Bool) -> Void) {
        self.updateClassicDesign = updateClassicDesign
    }
}

private enum MindGramAppearanceSection: Int32 {
    case design
}

private enum MindGramAppearanceEntry: ItemListNodeEntry {
    case classicDesign(title: String, text: String, value: Bool)
    case classicDesignFooter(String)

    var section: ItemListSectionId {
        return MindGramAppearanceSection.design.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .classicDesign:
            return 0
        case .classicDesignFooter:
            return 1
        }
    }

    static func <(lhs: MindGramAppearanceEntry, rhs: MindGramAppearanceEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MindGramAppearanceControllerArguments
        switch self {
        case let .classicDesign(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateClassicDesign(value)
            })
        case let .classicDesignFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// Оформление: the classic (pre-glass) Telegram design switch.
func mindGramAppearanceController(context: AccountContext) -> ViewController {
    let classicDesignValue = ValuePromise<Bool>(MindGramDesign.isClassicOnNextLaunch, ignoreRepeated: true)
    var presentRestartToastImpl: (() -> Void)?

    let arguments = MindGramAppearanceControllerArguments(updateClassicDesign: { value in
        MindGramDesign.setClassicOnNextLaunch(value)
        classicDesignValue.set(value)
        presentRestartToastImpl?()
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        classicDesignValue.get()
    )
    |> map { presentationData, classicDesign -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = MindGramStrings(presentationData)
        let entries: [MindGramAppearanceEntry] = [
            .classicDesign(title: strings.classicDesign, text: strings.classicDesignInfo, value: classicDesign),
            .classicDesignFooter(strings.classicDesignFooter)
        ]

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.appearance), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentRestartToastImpl = { [weak controller] in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = MindGramStrings(presentationData)
        // The same bottom toast Telegram uses for its own "action needed" notices, with a restart button.
        controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: strings.restartTitle, text: strings.restartText, timeout: 8.0, customUndoText: strings.restartAction), elevatedLayout: false, action: { action in
            if case .undo = action {
                // iOS has no API to relaunch an app; closing it applies the new design on the next start.
                exit(0)
            }
            return false
        }), in: .current)
    }
    return controller
}
