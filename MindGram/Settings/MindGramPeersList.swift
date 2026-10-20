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

/// A list of chats with "Add Chat" on top; swipe a chat to remove it. Used by ghost mode (selected chats,
/// exceptions), auto-translate, translating own messages and self-destruct. `get`/`set` hold PeerId.toInt64().
func mindGramPeersListController(context: AccountContext, title: String, footer: String, get: @escaping () -> Set<Int64>, set: @escaping (Set<Int64>) -> Void) -> ViewController {
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
            var value = get()
            value.insert(peer.id.toInt64())
            set(value)
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
            var value = get()
            value.remove(peerId.toInt64())
            set(value)
        })
    })

    let peersSignal: Signal<Void, NoError> = mindGramSettingsUpdated()
    |> map { _ -> [Int64] in
        return get().sorted()
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

    let controller = mindGramListController(context: context, title: { _ in title }, arguments: arguments, extraUpdates: combineLatest(peersSignal, revealedUpdated.get()) |> map { _ in Void() }, entries: { _, _ in
        var entries: [MindGramListEntry] = []
        entries.append(.custom(id: 0, section: 0, key: "add", revision: 0))
        for (index, peer) in peers.enumerated() {
            let revealed = revealedPeerId == peer.id ? 1 : 0
            entries.append(.custom(id: 1 + Int32(index), section: 0, key: "peer:\(peer.id.toInt64())", revision: revealed))
        }
        entries.append(.footer(id: 100000, section: 0, text: footer))
        return entries
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

/// A list of choices with a checkmark on the current one; the screen stays open after a choice.
func mindGramPickerController(context: AccountContext, title: String, header: String? = nil, footer: String? = nil, options: [(id: String, title: String)], selected: @escaping () -> String, select: @escaping (String) -> Void) -> ViewController {
    let arguments = MindGramListArguments(open: { id in
        guard id >= 1, Int(id) <= options.count else {
            return
        }
        select(options[Int(id) - 1].id)
    })
    return mindGramListController(context: context, title: { _ in title }, arguments: arguments, entries: { _, _ in
        var entries: [MindGramListEntry] = []
        if let header {
            entries.append(.header(id: 0, section: 0, text: header))
        }
        let current = selected()
        for (index, option) in options.enumerated() {
            entries.append(.check(id: 1 + Int32(index), section: 0, title: option.title, checked: option.id == current))
        }
        if let footer {
            entries.append(.footer(id: 100000, section: 0, text: footer))
        }
        return entries
    })
}
