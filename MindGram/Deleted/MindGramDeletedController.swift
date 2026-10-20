import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import UndoUI
import MindGramCore

private let savedKinds: [MindGramChatKind] = [.privateChat, .group, .channel, .secretChat, .bot]

private func kindTitle(_ kind: MindGramChatKind, _ strings: MindGramStrings) -> String {
    switch kind {
    case .privateChat:
        return strings.t("Личные чаты", "Private Chats")
    case .group:
        return strings.t("Группы", "Groups")
    case .channel:
        return strings.t("Каналы", "Channels")
    case .secretChat:
        return strings.t("Секретные чаты", "Secret Chats")
    case .bot:
        return strings.t("Боты", "Bots")
    }
}

private func kindMark(_ kind: MindGramChatKind) -> String {
    switch kind {
    case .privateChat:
        return "👤"
    case .group:
        return "👥"
    case .channel:
        return "📢"
    case .secretChat:
        return "🔒"
    case .bot:
        return "🤖"
    }
}

private func markTitle(_ mark: MindGramDeleted.Mark, _ strings: MindGramStrings) -> String {
    switch mark {
    case .trash:
        return strings.t("🗑 Корзина", "🗑 Trash")
    case .cross:
        return strings.t("✕ Крестик", "✕ Cross")
    case .ghost:
        return strings.t("👻 Призрак", "👻 Ghost")
    case .prohibited:
        return strings.t("⊘ Запрет", "⊘ Prohibited")
    case .word:
        return strings.t("Только слово «удалено»", "Only the word \"deleted\"")
    }
}

func mindGramDateString(_ timestamp: Int32) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy HH:mm"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
}

/// Удалённые и правки: saved deleted messages, how they look, their history, and edit history.
func mindGramDeletedController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?

    let arguments = MindGramListArguments(toggle: { id, value in
        switch id {
        case 0:
            MindGramDeleted.isEnabled = value
        case 11 ..< 11 + Int32(savedKinds.count):
            MindGramDeleted.setSaves(savedKinds[Int(id - 11)], value)
        case 19:
            MindGramDeleted.savesOwnMessages = value
        case 21:
            MindGramDeleted.showsInChat = value
        case 23:
            MindGramDeleted.showsWord = value
        case 41:
            MindGramEdits.isEnabled = value
        default:
            break
        }
    }, open: { id in
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        switch id {
        case 22:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Значок", "Mark"), footer: strings.t("Значок стоит перед временем удалённого сообщения.", "The mark goes before the time of a deleted message."), options: MindGramDeleted.Mark.allCases.map { ($0.rawValue, markTitle($0, strings)) }, selected: { MindGramDeleted.mark.rawValue }, select: { value in
                if let mark = MindGramDeleted.Mark(rawValue: value) {
                    MindGramDeleted.mark = mark
                }
            }))
        case 30:
            pushImpl?(mindGramDeletedHistoryController(context: context))
        default:
            break
        }
    })

    let controller = mindGramListController(context: context, title: { $0.t("Удалённые и правки", "Deleted & Edited") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.toggle(id: 0, section: 0, title: strings.t("Сохранять удалённые", "Keep Deleted Messages"), info: strings.t("Удалённое не исчезает у вас", "Deleted messages stay with you"), value: MindGramDeleted.isEnabled))
        if MindGramDeleted.isEnabled {
            entries.append(.header(id: 10, section: 1, text: strings.t("ГДЕ СОХРАНЯТЬ", "WHERE TO KEEP")))
            for (index, kind) in savedKinds.enumerated() {
                entries.append(.toggle(id: 11 + Int32(index), section: 1, title: kindTitle(kind, strings), info: strings.t("Сохранять удалённое здесь", "Keep deleted messages here"), value: MindGramDeleted.saves(kind)))
            }
            entries.append(.toggle(id: 19, section: 1, title: strings.t("Мои сообщения", "My Messages"), info: strings.t("Удалённые с другого устройства", "Deleted from another device"), value: MindGramDeleted.savesOwnMessages))

            entries.append(.header(id: 20, section: 2, text: strings.t("В ЧАТЕ", "IN CHAT")))
            entries.append(.toggle(id: 21, section: 2, title: strings.t("Показывать в чате", "Show in Chat"), info: strings.t("Иначе только в истории", "Otherwise only in the history"), value: MindGramDeleted.showsInChat))
            if MindGramDeleted.showsInChat {
                entries.append(.value(id: 22, section: 2, title: strings.t("Значок", "Mark"), value: MindGramDeleted.mark.prefix.isEmpty ? strings.t("Слово", "Word") : MindGramDeleted.mark.prefix))
                if MindGramDeleted.mark != .word {
                    entries.append(.toggle(id: 23, section: 2, title: strings.t("Подпись «удалено»", "\"Deleted\" Label"), info: strings.t("Слово рядом со значком", "A word next to the mark"), value: MindGramDeleted.showsWord))
                }
            }
        }
        entries.append(.value(id: 30, section: 3, title: strings.t("История удалённых", "Deleted History"), value: "\(MindGramDeleted.records.count)"))
        entries.append(.footer(id: 31, section: 3, text: strings.t("Все сохранённые удалённые сообщения из всех чатов. Нажмите, чтобы открыть сообщение в чате.", "Every kept deleted message from every chat. Tap one to open it in its chat.")))

        entries.append(.header(id: 40, section: 4, text: strings.t("ПРАВКИ", "EDITS")))
        entries.append(.toggle(id: 41, section: 4, title: strings.t("История правок", "Edit History"), info: strings.t("Прошлые версии сообщений", "Earlier versions of messages"), value: MindGramEdits.isEnabled))
        entries.append(.footer(id: 42, section: 4, text: strings.t("Когда сообщение изменят, зажмите его и нажмите «История правок», чтобы увидеть, что было раньше.", "When a message is edited, press and hold it and tap \"Edit History\" to see what it said before.")))
        return entries
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

/// История удалённых: every kept deleted message, newest first, filtered by chat kind.
private func mindGramDeletedHistoryController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?
    var presentImpl: ((ViewController) -> Void)?
    var navigationImpl: (() -> NavigationController?)?
    var kindFilter: MindGramChatKind?
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
            presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: strings.t("История очищена", "History cleared"), timeout: 2.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
            return
        }
        let records = visibleRecords()
        let index = Int(id) - 100
        guard index >= 0, index < records.count else {
            return
        }
        let record = records[index]
        if !MindGramDeleted.showsInChat {
            UIPasteboard.general.string = record.text
            presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: strings.copiedText, timeout: 2.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
            return
        }
        let peerId = EnginePeer.Id(record.key.peerId)
        let messageId = EngineMessage.Id(peerId: peerId, namespace: record.key.namespace, id: record.key.id)
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer, let navigationController = navigationImpl?() else {
                return
            }
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always))
        })
    })

    let controller = mindGramListController(context: context, title: { $0.t("История удалённых", "Deleted History") }, arguments: arguments, extraUpdates: filterUpdated.get() |> map { _ in Void() }, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.value(id: 1, section: 0, title: strings.t("Показывать", "Show"), value: kindFilter.map { kindTitle($0, strings) } ?? strings.t("Все чаты", "All Chats")))
        let records = visibleRecords()
        if records.isEmpty {
            entries.append(.footer(id: 3, section: 0, text: strings.t("Пока ничего не удалили. Включите «Сохранять удалённые», и удалённые сообщения появятся здесь.", "Nothing deleted yet. Turn on \"Keep Deleted Messages\" and deleted messages will appear here.")))
        } else {
            for (index, record) in records.prefix(maxShown).enumerated() {
                var body = record.text
                if !record.media.isEmpty {
                    body = body.isEmpty ? "[\(record.media)]" : "[\(record.media)] \(body)"
                }
                if body.count > 160 {
                    body = String(body.prefix(160)) + "…"
                }
                let author = record.isOutgoing ? strings.t("Вы", "You") : record.author
                let line1 = author.isEmpty || author == record.chatTitle ? body : "\(author): \(body)"
                let line2 = strings.t("Отправлено", "Sent") + " \(mindGramDateString(record.date)) · " + strings.t("удалено", "deleted") + " \(mindGramDateString(record.deletedAt))"
                entries.append(.detail(id: 100 + Int32(index), section: 1, title: "\(kindMark(record.chatKind)) \(record.chatTitle)", detail: "\(line1)\n\(line2)"))
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
    navigationImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}

/// История правок: every earlier text of a message, oldest first, then the current one.
public func mindGramEditHistoryController(context: AccountContext, versions: [MindGramEdits.Version], currentText: String) -> ViewController {
    let arguments = MindGramListArguments()
    return mindGramListController(context: context, title: { $0.t("История правок", "Edit History") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        for (index, version) in versions.enumerated() {
            let section = ItemListSectionId(index)
            let title = index == 0 ? strings.t("ОРИГИНАЛ", "ORIGINAL") : strings.t("ВЕРСИЯ \(index + 1)", "VERSION \(index + 1)")
            entries.append(.header(id: Int32(index * 2), section: section, text: "\(title) · \(mindGramDateString(version.date))"))
            entries.append(.text(id: Int32(index * 2 + 1), section: section, text: version.text.isEmpty ? "—" : version.text, monospace: false))
        }
        let last = versions.count
        entries.append(.header(id: Int32(last * 2), section: ItemListSectionId(last), text: strings.t("СЕЙЧАС", "NOW")))
        entries.append(.text(id: Int32(last * 2 + 1), section: ItemListSectionId(last), text: currentText.isEmpty ? "—" : currentText, monospace: false))
        return entries
    })
}
