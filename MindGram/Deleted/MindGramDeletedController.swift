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

let savedKinds: [MindGramChatKind] = [.privateChat, .group, .channel, .secretChat, .bot]

func kindTitle(_ kind: MindGramChatKind, _ strings: MindGramStrings) -> String {
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

func kindMark(_ kind: MindGramChatKind) -> String {
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
        switch id {
        case 24:
            pushImpl?(mindGramDeletedLookController(context: context))
        case 30:
            pushImpl?(mindGramDeletedHistoryController(context: context))
        default:
            break
        }
    }, customItem: { _, presentationData, section in
        return MindGramPreviews.deleted(context: context, sectionId: section)
    })

    let controller = mindGramListController(context: context, title: { $0.t("Удалённые и правки", "Deleted & Edited") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.header(id: -11, section: -1, text: strings.t("ПРЕВЬЮ", "PREVIEW")))
        entries.append(.custom(id: -10, section: -1, key: "preview", revision: mindGramDeletedPreviewRevision()))
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
                entries.append(.toggle(id: 23, section: 2, title: strings.t("Подпись «удалено»", "\"Deleted\" Label"), info: strings.t("Слово рядом с корзиной", "A word next to the trash"), value: MindGramDeleted.showsWord))
                entries.append(.value(id: 24, section: 2, title: strings.t("Вид удалённых сообщений", "Deleted Message Look"), value: strings.t("цвет, размер", "colour, size")))
            }
        }
        entries.append(.value(id: 30, section: 3, title: strings.t("История удалённых", "Deleted History"), value: "\(MindGramDeleted.records.count)"))
        entries.append(.footer(id: 31, section: 3, text: strings.t("Все сохранённые удалённые сообщения из всех чатов, с аватаркой автора. Нажмите — профиль, сообщение в чате или копия текста.", "Every kept deleted message from every chat, with the author's avatar. Tap for the profile, the message in its chat, or a copy of the text.")))

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

private func mindGramDeletedPreviewRevision() -> Int {
    var hasher = Hasher()
    hasher.combine(MindGramDeleted.markColor)
    hasher.combine(MindGramDeleted.markScalePercent)
    hasher.combine(MindGramDeleted.opacityPercent)
    hasher.combine(MindGramDeleted.mark.prefix)
    hasher.combine(MindGramDeleted.showsWord)
    return hasher.finalize()
}
