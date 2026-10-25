import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import MindGramCore

func mindGramVisualController(context: AccountContext) -> ViewController {
    let accountPeerId = context.account.peerId.id._internalGetInt64Value()
    let options: [MindGramMarks.Kind?] = [nil] + MindGramMarks.Kind.allCases.map { Optional($0) }

    let arguments = MindGramListArguments(open: { id in
        let index = Int(id) - 10
        if index >= 0 && index < options.count {
            MindGramMarks.setMark(peerId: accountPeerId, options[index])
        }
    })

    return mindGramListController(context: context, title: { $0.t("Визуал", "Visual") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        let current = MindGramMarks.mark(peerId: accountPeerId)
        entries.append(.header(id: 9, section: 1, text: strings.t("МЕТКА", "MARK")))
        for (index, option) in options.enumerated() {
            entries.append(.check(id: 10 + Int32(index), section: 1, title: option?.title ?? strings.t("Без метки", "No Mark"), checked: option == current))
        }
        entries.append(.footer(id: 30, section: 1, text: strings.t("Видно только вам. Другим людям — через их профиль: ⋯ → MindGram.", "Only you see it. For other people: their profile, ⋯ → MindGram.")))
        return entries
    })
}
