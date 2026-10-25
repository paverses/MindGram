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
    var pushImpl: ((ViewController) -> Void)?
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
            let apply = {
                MindGramDesign.setClassicOnNextLaunch(value)
                NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
                presentRestartToast()
            }
            if value && !UserDefaults.standard.bool(forKey: "MindGram.classicConflictShown") {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let strings = MindGramStrings(presentationData)
                presentImpl?(textAlertController(context: context, title: strings.classicConflictTitle, text: strings.classicConflictText, actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                        NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
                    }),
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                        UserDefaults.standard.set(true, forKey: "MindGram.classicConflictShown")
                        apply()
                    })
                ]))
            } else {
                apply()
            }
            return
        }
        let index = Int(id) - 12
        if index >= 0 && index < experimentToggles.count {
            MindGramSettings.set(experimentToggles[index], value)
        }
    }, open: { id in
        if id == 50 {
            pushImpl?(mindGramBadgeController(context: context))
        }
    }, customItem: { key, presentationData, section in
        return MindGramPreviews.appearance(context: context, sectionId: section)
    })

    let controller = mindGramListController(context: context, title: { $0.appearance }, arguments: arguments, extraUpdates: accountPeer, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.toggleEx(id: 0, section: 0, title: strings.classicDesign, info: strings.classicDesignInfo, value: MindGramDesign.isClassicOnNextLaunch, enabled: true, beta: true))
        entries.append(.footer(id: 1, section: 0, text: strings.classicDesignFooter))

        if MindGramOwner.isOwner(userId: context.account.peerId.id._internalGetInt64Value(), username: username) {
            entries.append(.header(id: 10, section: 1, text: strings.t("ЭКСПЕРИМЕНТЫ", "EXPERIMENTS")))
            entries.append(.custom(id: 11, section: 1, key: "preview", revision: experimentToggles.reduce(0, { $0 * 2 + (MindGramSettings.isOn($1) ? 1 : 0) })))
            for (index, toggle) in experimentToggles.enumerated() {
                entries.append(.toggleEx(id: 12 + Int32(index), section: 1, title: strings.toggleTitle(toggle), info: strings.toggleInfo(toggle), value: MindGramSettings.storedValue(toggle), enabled: !MindGramSettings.isLockedByClassicDesign(toggle), beta: false))
            }
            entries.append(.footer(id: 20, section: 1, text: strings.t("Этот раздел видите только вы. Круглые кнопки работают вместе с «Liquid Glass в профиле».", "Only you see this section. Round buttons work together with Liquid Glass Profile.")))
        }

        entries.append(.disclosure(id: 50, section: 5, title: strings.t("Бейдж в вырезе", "Notch Badge"), icon: ""))
        return entries
    })
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .current)
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

func mindGramBadgeController(context: AccountContext) -> ViewController {
    let styles = MindGramBadge.Style.allCases
    let arguments = MindGramListArguments(open: { id in
        let index = Int(id - 1) / 2
        if index >= 0 && index < styles.count {
            MindGramBadge.style = styles[index]
        }
    }, customItem: { key, presentationData, section in
        let style = styles.first(where: { $0.rawValue == key }) ?? .classic
        return mindGramPreviewItem(presentationData: presentationData, sectionId: section, height: 78.0, revision: 0, build: { size, _ in
            let root = UIView(frame: CGRect(origin: CGPoint(), size: size))
            root.backgroundColor = UIColor(white: 0.06, alpha: 1.0)
            let island = UIView(frame: CGRect(x: (size.width - 124.0) / 2.0, y: 6.0, width: 124.0, height: 18.0))
            island.backgroundColor = .black
            island.layer.cornerRadius = 9.0
            root.addSubview(island)
            if let image = MindGramBadge.image(style) {
                let badge = UIImageView(image: image)
                badge.frame = CGRect(x: (size.width - image.size.width) / 2.0, y: 28.0, width: image.size.width, height: image.size.height)
                root.addSubview(badge)
            }
            return root
        })
    })
    return mindGramListController(context: context, title: { $0.t("Бейдж в вырезе", "Notch Badge") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        let current = MindGramBadge.style
        for (index, style) in styles.enumerated() {
            entries.append(.custom(id: Int32(index * 2), section: ItemListSectionId(index), key: style.rawValue, revision: 0))
            entries.append(.check(id: Int32(index * 2 + 1), section: ItemListSectionId(index), title: style.title(isRussian: strings.isRussian), checked: current == style))
        }
        entries.append(.footer(id: 100, section: ItemListSectionId(styles.count - 1), text: strings.t("Бейдж под чёлкой или Dynamic Island.", "The badge under the notch or Dynamic Island.")))
        return entries
    })
}
