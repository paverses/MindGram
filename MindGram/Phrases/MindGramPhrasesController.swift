import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import MindGramCore

/// Быстрые фразы: the list (by folders), the trigger symbols, and the editor.
func mindGramPhrasesController(context: AccountContext) -> ViewController {
    var presentUIKitImpl: ((UIViewController) -> Void)?

    let openEditor: (MindGramPhrases.Phrase?) -> Void = { phrase in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let editor = MindGramPhraseEditorController(phrase: phrase, isRussian: MindGramStrings(presentationData).isRussian)
        let navigation = UINavigationController(rootViewController: editor)
        navigation.overrideUserInterfaceStyle = presentationData.theme.overallDarkAppearance ? .dark : .light
        presentUIKitImpl?(navigation)
    }

    let arguments = MindGramListArguments(toggle: { id, value in
        if id == 0 {
            MindGramPhrases.isEnabled = value
        }
    }, open: { id in
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        if id == 1 {
            let alert = UIAlertController(title: strings.t("Символы вызова", "Trigger Symbols"), message: strings.t("Любые символы через пробел, например: / ;; ! ..", "Any symbols separated by spaces, e.g. / ;; ! .."), preferredStyle: .alert)
            alert.addTextField { field in
                field.text = MindGramPhrases.triggers
                field.autocapitalizationType = .none
                field.autocorrectionType = .no
            }
            alert.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: strings.t("Сохранить", "Save"), style: .default, handler: { [weak alert] _ in
                let value = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                MindGramPhrases.triggers = value.isEmpty ? "/" : value
            }))
            presentUIKitImpl?(alert)
            return
        }
        if id == 3 {
            openEditor(nil)
            return
        }
        let phrases = MindGramPhrases.phrases
        let index = id >= 1_000_000 ? Int(id % 100000) - 1 : -1
        if index >= 0 && index < phrases.count {
            let phrase = phrases[index]
            let sheet = UIAlertController(title: phrase.name, message: String(phrase.text.prefix(200)), preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: strings.t("Изменить", "Edit"), style: .default, handler: { _ in
                openEditor(phrase)
            }))
            sheet.addAction(UIAlertAction(title: strings.t("Удалить", "Delete"), style: .destructive, handler: { _ in
                MindGramPhrases.delete(id: phrase.id)
            }))
            sheet.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
            presentUIKitImpl?(sheet)
        }
    }, customItem: { _, presentationData, section in
        return mindGramPreviewItem(presentationData: presentationData, sectionId: section, height: 150.0, revision: MindGramPhrases.phrases.count * 31 + MindGramPhrases.triggers.hashValue, build: { size, isDark in
            return MindGramPreviews.phrases(size: size, isDark: isDark, isRussian: MindGramStrings(context.sharedContext.currentPresentationData.with { $0 }).isRussian)
        })
    }))

    let controller = mindGramListController(context: context, title: { $0.t("Быстрые фразы", "Quick Phrases") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.custom(id: -10, section: -1, key: "preview", revision: MindGramPhrases.phrases.count * 31 + MindGramPhrases.triggers.hashValue))
        entries.append(.toggle(id: 0, section: 0, title: strings.t("Быстрые фразы", "Quick Phrases"), info: strings.t("Символ + название в любом чате", "Trigger + name in any chat"), value: MindGramPhrases.isEnabled))
        entries.append(.value(id: 1, section: 0, title: strings.t("Символы вызова", "Trigger Symbols"), value: MindGramPhrases.triggers))
        let example = (MindGramPhrases.triggerList.last ?? "/") + strings.t("адрес", "address")
        entries.append(.footer(id: 2, section: 0, text: strings.t("Наберите в поле ввода, например «\(example)», — над полем появится список фраз, как у инлайн-ботов. Нажмите фразу, и она встанет вместо набранного.", "Type, for example, \"\(example)\" in the message field: a list of phrases appears above it, like inline bots. Tap one to put it in place of what you typed.")))
        entries.append(.action(id: 3, section: 1, title: strings.t("Добавить фразу", "Add Phrase")))

        let phrases = MindGramPhrases.phrases
        var sectionIndex: ItemListSectionId = 2
        var headerId: Int32 = 10
        for folder in MindGramPhrases.folders {
            entries.append(.header(id: headerId * 100000, section: sectionIndex, text: folder.isEmpty ? strings.t("БЕЗ ПАПКИ", "NO FOLDER") : folder.uppercased()))
            for (index, phrase) in phrases.enumerated() where phrase.folder == folder {
                let preview = phrase.text.replacingOccurrences(of: "\n", with: " ")
                entries.append(.detail(id: headerId * 100000 + 1 + Int32(index), section: sectionIndex, title: (MindGramPhrases.triggerList.last ?? "/") + phrase.name, detail: String(preview.prefix(120))))
            }
            sectionIndex += 1
            headerId += 1
        }
        return entries.sorted(by: { $0.stableId < $1.stableId })
    })
    presentUIKitImpl = { [weak controller] c in
        controller?.present(c, animated: true)
    }
    return controller
}
