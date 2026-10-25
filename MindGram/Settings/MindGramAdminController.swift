import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import ItemListPeerItem
import AccountContext
import PresentationDataUtils
import UndoUI
import MindGramCore

func mindGramAdminController(context: AccountContext) -> ViewController {
    var presentImpl: ((ViewController) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var peers: [Int64: EnginePeer] = [:]
    let peersUpdated = ValuePromise<Int>(0, ignoreRepeated: true)
    var peersRevision = 0
    let resolveDisposable = DisposableSet()
    var requested = Set<Int64>()

    let toast: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: 2.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
    }

    let sendCommand: (String, String) -> Void = { command, done in
        let _ = (context.engine.peers.resolvePeerByName(name: MindGramAdmin.botUsername, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            if case let .result(peer) = result {
                return .single(peer)
            }
            return .complete()
        }
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer else {
                toast("Бот @\(MindGramAdmin.botUsername) не найден")
                return
            }
            let _ = enqueueMessages(account: context.account, peerId: peer.id, messages: [.message(text: command, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).startStandalone()
            toast(done)
        })
    }

    let resolvePeers: ([MindGramBetaTesters.Member]) -> Void = { members in
        for member in members where !requested.contains(member.id) {
            requested.insert(member.id)
            let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(member.id))
            let signal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
                if let peer {
                    return .single(peer)
                }
                guard let username = member.username, !username.isEmpty else {
                    return .single(nil)
                }
                return context.engine.peers.resolvePeerByName(name: username, referrer: nil)
                |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                    if case let .result(peer) = result {
                        return .single(peer)
                    }
                    return .complete()
                }
                |> take(1)
            }
            |> deliverOnMainQueue
            resolveDisposable.add(signal.startStrict(next: { peer in
                if let peer {
                    peers[member.id] = peer
                    peersRevision += 1
                    peersUpdated.set(peersRevision)
                }
            }))
        }
    }

    let openMember: (MindGramBetaTesters.Member) -> Void = { member in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let palette = MindGramBetaTesters.palette
        let isBeta = palette.beta.contains(member.id)
        let isBlocked = palette.blocked.contains(member.id)
        let mark = palette.marks[member.id]
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        items.append(ActionSheetTextItem(title: "\(member.name ?? "—") · \(member.id)"))
        let item: (String, ActionSheetButtonColor, String, String, (inout MindGramBetaTesters.Palette) -> Void) -> ActionSheetButtonItem = { title, color, command, done, apply in
            return ActionSheetButtonItem(title: title, color: color, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                MindGramBetaTesters.applyLocally(apply)
                sendCommand(command, done)
            })
        }
        if isBeta {
            items.append(item("Убрать бета-доступ", .destructive, "/removebeta \(member.id)", "Бета-доступ убран", { $0.beta.remove(member.id) }))
        } else {
            items.append(item("Выдать бета-доступ (купил)", .accent, "/addbeta \(member.id) \(member.username ?? "")", "Бета-доступ выдан", { $0.beta.insert(member.id) }))
        }
        if isBlocked {
            items.append(item("Разблокировать", .accent, "/unblock \(member.id)", "Разблокирован", { $0.blocked.remove(member.id) }))
        } else {
            items.append(item("Заблокировать вход", .destructive, "/block \(member.id)", "Заблокирован", { $0.blocked.insert(member.id) }))
        }
        for kind in MindGramMarks.Kind.manualCases where kind.rawValue != mark {
            items.append(item("Метка \(kind.title)", .accent, "/mark \(member.id) \(kind.rawValue)", "Метка \(kind.title) выдана", { $0.marks[member.id] = kind.rawValue }))
        }
        if mark != nil {
            items.append(item("Убрать метку", .destructive, "/mark \(member.id) none", "Метка убрана", { $0.marks.removeValue(forKey: member.id) }))
        }
        items.append(ActionSheetButtonItem(title: "Скопировать ID", color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            UIPasteboard.general.string = "\(member.id)"
            toast("ID скопирован")
        }))
        if let username = member.username ?? peers[member.id]?.addressName, !username.isEmpty {
            items.append(ActionSheetButtonItem(title: "Скопировать @\(username)", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                UIPasteboard.general.string = "@\(username)"
                toast("Юзернейм скопирован")
            }))
        }
        if let peer = peers[member.id] {
            items.append(ActionSheetButtonItem(title: "Написать", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                }
            }))
            items.append(ActionSheetButtonItem(title: "Открыть профиль", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                    pushImpl?(controller)
                }
            }))
        }
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })])
        ])
        presentImpl?(actionSheet)
    }

    let arguments = MindGramListArguments(open: { id in
        if id == 1 {
            MindGramBetaTesters.reload(completion: {})
            return
        }
        let members = MindGramBetaTesters.palette.members
        let index = Int(id) - 100
        if index >= 0 && index < members.count {
            openMember(members[index])
        }
    }, customItem: { key, presentationData, section in
        let members = MindGramBetaTesters.palette.members
        guard key.hasPrefix("member:"), let index = Int(key.dropFirst(7)), index < members.count else {
            return ItemListTextItem(presentationData: presentationData, text: .plain(""), sectionId: section)
        }
        let member = members[index]
        let palette = MindGramBetaTesters.palette
        var status: [String] = []
        status.append(palette.beta.contains(member.id) ? "купил бету" : "не купил")
        if let mark = palette.marks[member.id] {
            status.append(mark.capitalized)
        }
        if palette.blocked.contains(member.id) {
            status.append("заблокирован")
        }
        if let build = member.build {
            status.append("сборка \(build)")
        }
        let statusText = status.joined(separator: " · ")
        let color: ItemListPeerItemText.TextColor = palette.blocked.contains(member.id) ? .secondary : (palette.beta.contains(member.id) ? .constructive : .accent)
        if let peer = peers[member.id] {
            return ItemListPeerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: context, peer: peer, presence: nil, text: .text(statusText, color), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: section, action: {
                openMember(member)
            }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
        }
        let title = member.name ?? member.username.map { "@\($0)" } ?? "\(member.id)"
        return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: statusText, labelStyle: .multilineDetailText, sectionId: section, style: .blocks, action: {
            openMember(member)
        })
    })

    let paletteSignal: Signal<Void, NoError> = mindGramSettingsUpdated()
    |> deliverOnMainQueue
    |> map { _ -> Void in
        resolvePeers(MindGramBetaTesters.palette.members)
        return Void()
    }

    let controller = mindGramListController(context: context, title: { $0.t("Админ-панель", "Admin Panel") }, arguments: arguments, extraUpdates: combineLatest(paletteSignal, peersUpdated.get()) |> map { _ in Void() }, entries: { _, strings in
        let palette = MindGramBetaTesters.palette
        var entries: [MindGramListEntry] = []
        let bought = palette.members.filter { palette.beta.contains($0.id) }.count
        entries.append(.header(id: 0, section: 0, text: strings.t("СКАЧАЛИ СБОРКУ: \(palette.members.count) · КУПИЛИ: \(bought)", "DOWNLOADED: \(palette.members.count) · BOUGHT: \(bought)")))
        entries.append(.action(id: 1, section: 0, title: strings.t("Обновить список", "Refresh")))
        for (index, member) in palette.members.enumerated() {
            let revision = (palette.beta.contains(member.id) ? 1 : 0) + (palette.blocked.contains(member.id) ? 2 : 0) + ((palette.marks[member.id]?.count ?? 0) << 2) + (peers[member.id] != nil ? 64 : 0)
            entries.append(.custom(id: 100 + Int32(index), section: 0, key: "member:\(index)", revision: revision))
        }
        entries.append(.footer(id: 100000, section: 0, text: strings.t("Список ведёт бот сборок. Действия уходят ему командами, список обновляется в течение пары минут.", "The builds bot keeps this list. Actions are sent to it as commands; the list updates within a couple of minutes.")))
        return entries
    })
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    let _ = resolveDisposable
    return controller
}
