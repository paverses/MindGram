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

/// Experimental design switches, in display order; only the owner account sees them.
private let experimentToggles: [MindGramToggle] = [
    .plusAttachMenu,
    .quickActionsMenu,
    .noContextBlur,
    .largerReactions,
    .roundProfileButtons,
    .squareProfileAvatar,
    .avatarBackdrop
]

/// Оформление: the classic (pre-glass) Telegram design switch, and the owner's design experiments.
func mindGramAppearanceController(context: AccountContext) -> ViewController {
    var presentImpl: ((ViewController) -> Void)?
    var username: String?

    let accountPeer: Signal<Void, NoError> = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
    |> map { peer -> String? in
        return peer?.addressName
    }
    |> distinctUntilChanged
    |> deliverOnMainQueue
    |> map { value -> Void in
        username = value
        return Void()
    }

    let presentRestartToast = {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = MindGramStrings(presentationData)
        // The same bottom toast Telegram uses for its own "action needed" notices, with a restart button.
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: strings.restartTitle, text: strings.restartText, timeout: 8.0, customUndoText: strings.restartAction), elevatedLayout: false, action: { action in
            if case .undo = action {
                // iOS has no API to relaunch an app; closing it applies the new design on the next start.
                exit(0)
            }
            return false
        }))
    }

    let arguments = MindGramListArguments(toggle: { id, value in
        if id == 0 {
            MindGramDesign.setClassicOnNextLaunch(value)
            NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
            presentRestartToast()
            return
        }
        let index = Int(id) - 12
        if index >= 0 && index < experimentToggles.count {
            MindGramSettings.set(experimentToggles[index], value)
        }
    }, customItem: { _, presentationData, section in
        return MindGramPreviews.appearance(context: context, sectionId: section)
    })

    let controller = mindGramListController(context: context, title: { $0.appearance }, arguments: arguments, extraUpdates: accountPeer, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.toggle(id: 0, section: 0, title: strings.classicDesign, info: strings.classicDesignInfo, value: MindGramDesign.isClassicOnNextLaunch))
        entries.append(.footer(id: 1, section: 0, text: strings.classicDesignFooter))

        if MindGramOwner.isOwner(userId: context.account.peerId.id._internalGetInt64Value(), username: username) {
            entries.append(.header(id: 10, section: 1, text: strings.t("ЭКСПЕРИМЕНТЫ", "EXPERIMENTS")))
            entries.append(.custom(id: 11, section: 1, key: "preview", revision: experimentToggles.reduce(0, { $0 * 2 + (MindGramSettings.isOn($1) ? 1 : 0) })))
            for (index, toggle) in experimentToggles.enumerated() {
                entries.append(.toggle(id: 12 + Int32(index), section: 1, title: strings.toggleTitle(toggle), info: strings.toggleInfo(toggle), value: MindGramSettings.isOn(toggle)))
            }
            entries.append(.footer(id: 20, section: 1, text: strings.t("Этот раздел видите только вы. Круглые кнопки работают вместе с «Liquid Glass в профиле».", "Only you see this section. Round buttons work together with Liquid Glass Profile.")))
        }
        return entries
    })
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .current)
    }
    return controller
}
