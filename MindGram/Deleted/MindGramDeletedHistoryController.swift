import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import ItemListPeerItem
import AccountContext
import UndoUI
import MindGramCore

/// История удалённых: every kept deleted message, newest first, with the author's avatar on the left.
/// A tap offers the author's profile, the message in its chat, or a copy of the text.
func mindGramDeletedHistoryController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?
    var presentImpl: ((ViewController) -> Void)?
    var presentUIKitImpl: ((UIViewController) -> Void)?
    var navigationImpl: (() -> NavigationController?)?
    var kindFilter: MindGramChatKind?
    var peers: [Int64: EnginePeer] = [:]
    let filterUpdated = ValuePromise<Int>(0, ignoreRepeated: true)
    var filterRevision = 0
    let maxShown = 300

    let visibleRecords: () -> [MindGramDeleted.Record] = {
        let records = MindGramDeleted.records
        if let kindFilter {
            return records.filter { $0.chatKind == kindFilter }
        }
        return records
    }

    let showToast: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: 2.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
    }

    let openMessage: (MindGramDeleted.Record) -> Void = { record in
        let peerId = EnginePeer.Id(record.key.peerId)
        let messageId = EngineMessage.Id(peerId: peerId, namespace: record.key.namespace, id: record.key.id)
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer, let navigationController = navigationImpl?() else {
                return
            }
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always))
        })
    }

    let openActions: (MindGramDeleted.Record) -> Void = { record in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = MindGramStrings(presentationData)
        let sheet = UIAlertController(title: record.author.isEmpty ? record.chatTitle : record.author, message: record.text.isEmpty ? record.media : String(record.text.prefix(200)), preferredStyle: .actionSheet)
        if let authorId = record.authorId ?? (record.chatKind == .privateChat ? record.key.peerId : nil), let peer = peers[authorId] {
            sheet.addAction(UIAlertAction(title: strings.t("Открыть профиль", "Open Profile"), style: .default, handler: { _ in
                if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                    pushImpl?(controller)
                }
            }))
        }
        if MindGramDeleted.showsInChat {
            sheet.addAction(UIAlertAction(title: strings.t("Перейти к сообщению", "Go to Message"), style: .default, handler: { _ in
                openMessage(record)
            }))
        }
        if !record.text.isEmpty {
            sheet.addAction(UIAlertAction(title: strings.t("Скопировать текст", "Copy Text"), style: .default, handler: { _ in
                UIPasteboard.general.string = record.text
                showToast(strings.copiedText)
            }))
        }
        sheet.addAction(UIAlertAction(title: strings.t("Убрать из истории", "Remove from History"), style: .destructive, handler: { _ in
            MindGramDeleted.remove(record.key)
        }))
        sheet.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
        presentUIKitImpl?(sheet)
    }

    let arguments = MindGramListArguments(open: { id in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = MindGramStrings(presentationData)
        if id == 1 {
            var options: [(id: String, title: String)] = [("all", strings.t("Все чаты", "All Chats"))]
            options.append(contentsOf: savedKinds.map { ($0.rawValue, kindTitle($0, strings)) })
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Показывать", "Show"), options: options, selected: { kindFilter?.rawValue ?? "all" }, select: { value in
                kindFilter = MindGramChatKind(rawValue: value)
                NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
                filterRevision += 1
                filterUpdated.set(filterRevision)
            }))
            return
        }
        if id == 1_000_000 {
            MindGramDeleted.clear()
            showToast(strings.t("История очищена", "History cleared"))
            return
        }
        let records = visibleRecords()
        let index = Int(id) - 100
        if index >= 0 && index < records.count {
            openActions(records[index])
        }
    }, customItem: { key, presentationData, section in
        let records = visibleRecords()
        guard key.hasPrefix("rec:"), let index = Int(key.dropFirst(4)), index < records.count else {
            return ItemListTextItem(presentationData: presentationData, text: .plain(""), sectionId: section)
        }
        let record = records[index]
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        var body = record.text
        if !record.media.isEmpty {
            body = body.isEmpty ? "[\(record.media)]" : "[\(record.media)] \(body)"
        }
        let place = record.author.isEmpty || record.author == record.chatTitle || record.chatKind == .privateChat ? "" : "\(kindMark(record.chatKind)) \(record.chatTitle) · "
        let time = mindGramDateString(record.deletedAt)
        let peerKey = record.authorId ?? record.key.peerId
        guard let peer = peers[peerKey] ?? peers[record.key.peerId] else {
            let line2 = strings.t("удалено", "deleted") + " \(time)"
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "\(kindMark(record.chatKind)) \(record.chatTitle)", label: "\(body)\n\(line2)", labelStyle: .multilineDetailText, sectionId: section, style: .blocks, disclosureStyle: .none, action: {
                openActions(record)
            })
        }
        return ItemListPeerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: .firstLast, context: context, peer: peer, presence: nil, text: .text(place + body, .secondary), label: .text(time, .standard, nil, false), editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: section, action: {
            openActions(record)
        }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
    })

    // Avatars: the authors (and chats) of the shown records.
    let peersSignal: Signal<Void, NoError> = combineLatest(mindGramSettingsUpdated(), filterUpdated.get())
    |> map { _ -> [Int64] in
        var ids = Set<Int64>()
        for record in visibleRecords().prefix(maxShown) {
            ids.insert(record.key.peerId)
            if let authorId = record.authorId {
                ids.insert(authorId)
            }
        }
        return ids.sorted()
    }
    |> distinctUntilChanged
    |> mapToSignal { ids -> Signal<[Int64: EnginePeer], NoError> in
        return context.engine.data.get(EngineDataMap(
            ids.map { TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id($0)) }
        ))
        |> map { result -> [Int64: EnginePeer] in
            var mapped: [Int64: EnginePeer] = [:]
            for (id, peer) in result {
                if let peer {
                    mapped[id.toInt64()] = peer
                }
            }
            return mapped
        }
    }
    |> deliverOnMainQueue
    |> map { result -> Void in
        peers = result
        return Void()
    }

    let controller = mindGramListController(context: context, title: { $0.t("История удалённых", "Deleted History") }, arguments: arguments, extraUpdates: peersSignal, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.value(id: 1, section: 0, title: strings.t("Показывать", "Show"), value: kindFilter.map { kindTitle($0, strings) } ?? strings.t("Все чаты", "All Chats")))
        let records = visibleRecords()
        if records.isEmpty {
            entries.append(.footer(id: 3, section: 0, text: strings.t("Пока ничего не удалили. Включите «Сохранять удалённые», и удалённые сообщения появятся здесь.", "Nothing deleted yet. Turn on \"Keep Deleted Messages\" and deleted messages will appear here.")))
        } else {
            for (index, record) in records.prefix(maxShown).enumerated() {
                let hasPeer = peers[record.authorId ?? record.key.peerId] != nil || peers[record.key.peerId] != nil
                entries.append(.custom(id: 100 + Int32(index), section: 1, key: "rec:\(index)", revision: hasPeer ? Int(record.deletedAt) : -Int(record.deletedAt)))
            }
            if records.count > maxShown {
                entries.append(.footer(id: 100 + Int32(maxShown) + 1, section: 1, text: strings.t("Показаны последние \(maxShown) из \(records.count).", "Showing the last \(maxShown) of \(records.count).")))
            }
            entries.append(.action(id: 1_000_000, section: 2, title: strings.t("Очистить историю", "Clear History")))
        }
        return entries
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .current)
    }
    presentUIKitImpl = { [weak controller] c in
        controller?.present(c, animated: true)
    }
    navigationImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}
