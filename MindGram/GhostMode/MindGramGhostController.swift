import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import ItemListPeerItem
import ItemListPeerActionItem
import AccountContext
import MindGramCore

/// What the master switch expands into, in display order.
private let ghostOptions: [MindGramGhost.Option] = [
    .hideRead,
    .hideOnline,
    .hideTyping,
    .hideMediaActivity,
    .hideListening,
    .anonymousStories
]

private enum GhostRow: Int32 {
    case master = 0
    // 10..<10 + ghostOptions.count: the options
    case whereHeader = 20
    case onlySelected = 21
    case chats = 22
    case exceptions = 23
    case whereFooter = 24
    case chatListButton = 30
    case footer = 31
}

/// Режим призрака: what the server isn't told, and in which chats.
func mindGramGhostController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?

    let arguments = MindGramListArguments(toggle: { id, value in
        if id >= 10 && id < 10 + Int32(ghostOptions.count) {
            MindGramGhost.set(ghostOptions[Int(id - 10)], value)
            return
        }
        switch GhostRow(rawValue: id) {
        case .master:
            MindGramGhost.isEnabled = value
        case .onlySelected:
            MindGramGhost.onlySelectedChats = value
        case .chatListButton:
            MindGramGhost.set(.chatListButton, value)
        default:
            break
        }
    }, open: { id in
        switch GhostRow(rawValue: id) {
        case .chats:
            let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
            pushImpl?(mindGramPeersListController(context: context, title: strings.ghostChats, footer: strings.ghostChatsFooter, get: { MindGramGhost.ghostChats }, set: { MindGramGhost.ghostChats = $0 }))
        case .exceptions:
            let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
            pushImpl?(mindGramPeersListController(context: context, title: strings.ghostExceptions, footer: strings.ghostExceptionsFooter, get: { MindGramGhost.exceptions }, set: { MindGramGhost.exceptions = $0 }))
        default:
            break
        }
    }, icon: { name in
        switch name {
        case "chats":
            return PresentationResourcesSettings.chatFolders
        case "exceptions":
            return PresentationResourcesSettings.privateChats
        default:
            return nil
        }
    }, customItem: { _, presentationData, section in
        return MindGramPreviews.ghost(context: context, sectionId: section)
    })

    let controller = mindGramListController(context: context, title: { $0.ghostMode }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.custom(id: -10, section: -1, key: "preview", revision: 0))
        entries.append(.toggle(id: GhostRow.master.rawValue, section: 0, title: strings.ghostMode, info: strings.ghostModeInfo, value: MindGramGhost.isEnabled))
        if MindGramGhost.isEnabled {
            entries.append(.header(id: 9, section: 1, text: strings.ghostWhatHeader))
            for (index, option) in ghostOptions.enumerated() {
                entries.append(.toggle(id: 10 + Int32(index), section: 1, title: strings.ghostTitle(option), info: strings.ghostInfo(option), value: MindGramGhost.isSet(option)))
            }
            entries.append(.header(id: GhostRow.whereHeader.rawValue, section: 2, text: strings.ghostWhereHeader))
            entries.append(.toggle(id: GhostRow.onlySelected.rawValue, section: 2, title: strings.ghostOnlySelected, info: strings.ghostOnlySelectedInfo, value: MindGramGhost.onlySelectedChats))
            if MindGramGhost.onlySelectedChats {
                entries.append(.disclosure(id: GhostRow.chats.rawValue, section: 2, title: strings.ghostChats, icon: "chats"))
            }
            entries.append(.disclosure(id: GhostRow.exceptions.rawValue, section: 2, title: strings.ghostExceptions, icon: "exceptions"))
            entries.append(.footer(id: GhostRow.whereFooter.rawValue, section: 2, text: strings.ghostWhereFooter))
        }
        entries.append(.toggle(id: GhostRow.chatListButton.rawValue, section: 3, title: strings.ghostTitle(.chatListButton), info: strings.ghostInfo(.chatListButton), value: MindGramGhost.isSet(.chatListButton)))
        entries.append(.footer(id: GhostRow.footer.rawValue, section: 3, text: strings.ghostFooter))
        return entries
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

