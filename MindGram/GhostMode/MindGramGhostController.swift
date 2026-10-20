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
            pushImpl?(mindGramGhostPeersController(context: context, kind: .ghostChats))
        case .exceptions:
            pushImpl?(mindGramGhostPeersController(context: context, kind: .exceptions))
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
    })

    let controller = mindGramListController(context: context, title: { $0.ghostMode }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
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

private enum GhostPeersKind {
    case ghostChats
    case exceptions

    var peerIds: Set<Int64> {
        switch self {
        case .ghostChats:
            return MindGramGhost.ghostChats
        case .exceptions:
            return MindGramGhost.exceptions
        }
    }

    func update(_ f: (inout Set<Int64>) -> Void) {
        var value = self.peerIds
        f(&value)
        switch self {
        case .ghostChats:
            MindGramGhost.ghostChats = value
        case .exceptions:
            MindGramGhost.exceptions = value
        }
    }
}

/// «Чаты с призраком» and «Исключения»: a list of chats with "Add Chat" on top; swipe a chat to remove it.
private func mindGramGhostPeersController(context: AccountContext, kind: GhostPeersKind) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?
    var peers: [EnginePeer] = []
    var revealedPeerId: EnginePeer.Id?
    let revealedUpdated = ValuePromise<Int>(0, ignoreRepeated: true)
    var revealRevision = 0

    let addChat = {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = MindGramStrings(presentationData)
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeRecent, .doNotSearchMessages, .removeSearchHeader], hasContactSelector: false, title: strings.ghostAddChat))
        controller.peerSelected = { [weak controller] peer, _ in
            kind.update { _ = $0.insert(peer.id.toInt64()) }
            controller?.dismiss()
        }
        pushImpl?(controller)
    }

    let arguments = MindGramListArguments(customItem: { key, presentationData, section in
        if key == "add" {
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: MindGramStrings(context.sharedContext.currentPresentationData.with { $0 }).ghostAddChat, sectionId: section, height: .compactPeerList, editing: false, action: {
                addChat()
            })
        }
        guard key.hasPrefix("peer:"), let value = Int64(key.dropFirst(5)), let peer = peers.first(where: { $0.id.toInt64() == value }) else {
            return ItemListTextItem(presentationData: presentationData, text: .plain(""), sectionId: section)
        }
        return ItemListPeerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: context, peer: peer, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: revealedPeerId == peer.id), switchValue: nil, enabled: true, selectable: false, sectionId: section, action: nil, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
            if !((peerId == nil && fromPeerId == revealedPeerId) || (peerId != nil && fromPeerId == nil)) {
                return
            }
            revealedPeerId = peerId
            revealRevision += 1
            revealedUpdated.set(revealRevision)
        }, removePeer: { peerId in
            revealedPeerId = nil
            kind.update { _ = $0.remove(peerId.toInt64()) }
        })
    })

    let peersSignal: Signal<Void, NoError> = mindGramSettingsUpdated()
    |> map { _ -> [Int64] in
        return kind.peerIds.sorted()
    }
    |> distinctUntilChanged
    |> mapToSignal { ids -> Signal<[EnginePeer], NoError> in
        return context.engine.data.get(EngineDataMap(
            ids.map { TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id($0)) }
        ))
        |> map { result -> [EnginePeer] in
            return ids.compactMap { id -> EnginePeer? in
                if let peer = result[EnginePeer.Id(id)] {
                    return peer
                }
                return nil
            }
        }
    }
    |> deliverOnMainQueue
    |> map { result -> Void in
        peers = result
        return Void()
    }

    let controller = mindGramListController(context: context, title: { strings in
        switch kind {
        case .ghostChats:
            return strings.ghostChats
        case .exceptions:
            return strings.ghostExceptions
        }
    }, arguments: arguments, extraUpdates: combineLatest(peersSignal, revealedUpdated.get()) |> map { _ in Void() }, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.custom(id: 0, section: 0, key: "add", revision: 0))
        for (index, peer) in peers.enumerated() {
            let revealed = revealedPeerId == peer.id ? 1 : 0
            entries.append(.custom(id: 1 + Int32(index), section: 0, key: "peer:\(peer.id.toInt64())", revision: revealed))
        }
        let footer: String
        switch kind {
        case .ghostChats:
            footer = strings.ghostChatsFooter
        case .exceptions:
            footer = strings.ghostExceptionsFooter
        }
        entries.append(.footer(id: 100000, section: 0, text: footer))
        return entries
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
