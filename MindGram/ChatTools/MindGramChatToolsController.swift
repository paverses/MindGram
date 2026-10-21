import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import MindGramCore
import MindGramBleep
import MindGramFileTools

private func languageOptions(_ strings: MindGramStrings, includeAppLanguage: Bool) -> [(id: String, title: String)] {
    var options: [(id: String, title: String)] = []
    if includeAppLanguage {
        options.append(("", strings.t("Язык приложения", "App Language")))
    }
    options.append(contentsOf: MindGramTranslator.languages.map { ($0.code, strings.isRussian ? $0.ru : $0.en) })
    return options
}

private func scopeTitle(_ scope: MindGramSelfDestruct.Scope, _ strings: MindGramStrings) -> String {
    switch scope {
    case .all:
        return strings.t("Все чаты, кроме каналов", "All chats except channels")
    case .privateChats:
        return strings.t("Только личные", "Private chats only")
    case .selectedChats:
        return strings.t("Выбранные чаты", "Selected chats")
    }
}

/// Чат и перевод: translators and auto-translation, self-destructing messages, tap actions, transcription.
func mindGramChatToolsController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?
    var presentUIKitImpl: ((UIViewController) -> Void)?
    var showTranslateButton = false

    let translationSettings: Signal<Void, NoError> = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
    |> map { sharedData -> Bool in
        return (sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) ?? TranslationSettings.defaultSettings).showTranslate
    }
    |> distinctUntilChanged
    |> deliverOnMainQueue
    |> map { value -> Void in
        showTranslateButton = value
        return Void()
    }

    let arguments = MindGramListArguments(toggle: { id, value in
        switch id {
        case 3:
            MindGramTranslator.unlocksChatTranslation = value
        case 4:
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                return settings.withUpdatedShowTranslate(value)
            }).startStandalone()
        case 5:
            MindGramTranslator.autoTranslatesAllChats = value
            if value {
                let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                    return settings.withUpdatedTranslateChats(true)
                }).startStandalone()
            }
        case 20:
            MindGramSelfDestruct.isEnabled = value
        case 24:
            MindGramSelfDestruct.showsCountdown = value
        case 40:
            MindGramTranscription.isEnabled = value
        case 50 ..< 50 + Int32(MindGramSendConfirm.Kind.allCases.count):
            MindGramSendConfirm.set(MindGramSendConfirm.Kind.allCases[Int(id - 50)], value)
        case 70:
            MindGramForward.showsMenuItem = value
        case 71:
            MindGramForward.alwaysHideAuthor = value
        case 43:
            MindGramTranscription.translates = value
        case 80:
            MindGramBleep.voiceEnabled = value
        case 81:
            MindGramBleep.roundEnabled = value
        case 82:
            MindGramBleep.usesBeep = value
        case 92:
            MindGramFileTools.longTextAsFile = value
        case 90:
            MindGramFileTools.isEnabled = value
        case 41:
            MindGramTranscription.alwaysLocal = value
        default:
            break
        }
    }, open: { id in
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        switch id {
        case 1:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Переводчик", "Translator"), footer: strings.t("Google и Microsoft переводят бесплатно и без Premium. Apple переводит на устройстве (iOS 18), языки скачиваются в Настройках iOS. Telegram — перевод сервера Telegram.", "Google and Microsoft translate for free, without Premium. Apple translates on the device (iOS 18); languages download in iOS Settings. Telegram uses Telegram's server."), options: MindGramTranslator.Provider.allCases.map { ($0.rawValue, $0.title(isRussian: strings.isRussian)) }, selected: { MindGramTranslator.provider.rawValue }, select: { value in
                if let provider = MindGramTranslator.Provider(rawValue: value) {
                    MindGramTranslator.provider = provider
                }
            }))
        case 2:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Язык перевода", "Translate To"), options: languageOptions(strings, includeAppLanguage: true), selected: { MindGramTranslator.targetLanguage }, select: { MindGramTranslator.targetLanguage = $0 }))
        case 6:
            pushImpl?(mindGramPeersListController(context: context, title: strings.t("Автоперевод", "Auto-Translate"), footer: strings.t("Эти чаты переводятся сразу при открытии.", "These chats are translated as soon as they open."), get: { MindGramTranslator.autoChats }, set: { MindGramTranslator.autoChats = $0 }))
        case 10:
            pushImpl?(mindGramPeersListController(context: context, title: strings.t("Мои сообщения", "My Messages"), footer: strings.t("В этих чатах ваши сообщения переводятся перед отправкой.", "In these chats your messages are translated before sending."), get: { MindGramTranslator.outgoingChats }, set: { MindGramTranslator.outgoingChats = $0 }))
        case 11:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Язык моих сообщений", "My Messages Language"), options: languageOptions(strings, includeAppLanguage: false), selected: { MindGramTranslator.outgoingLanguage }, select: { MindGramTranslator.outgoingLanguage = $0 }))
        case 21:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Таймер", "Timer"), options: MindGramSelfDestruct.durations.map { ("\($0)", MindGramSelfDestruct.durationTitle($0, isRussian: strings.isRussian)) }, selected: { "\(MindGramSelfDestruct.seconds)" }, select: { value in
                if let seconds = Int(value) {
                    MindGramSelfDestruct.seconds = seconds
                }
            }))
        case 22:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Где", "Where"), options: MindGramSelfDestruct.Scope.allCases.map { ($0.rawValue, scopeTitle($0, strings)) }, selected: { MindGramSelfDestruct.scope.rawValue }, select: { value in
                if let scope = MindGramSelfDestruct.Scope(rawValue: value) {
                    MindGramSelfDestruct.scope = scope
                }
            }))
        case 23:
            pushImpl?(mindGramPeersListController(context: context, title: strings.t("Самоуничтожение", "Self-Destruct"), footer: strings.t("В этих чатах ваши сообщения удаляются у всех по таймеру.", "In these chats your messages are deleted for everyone on a timer."), get: { MindGramSelfDestruct.selectedChats }, set: { MindGramSelfDestruct.selectedChats = $0 }))
        case 33, 34:
            let isLeft = id == 33
            let options: [(id: String, title: String)] = MindGramTapAction.allCases.map { ($0.rawValue, $0.title(isRussian: strings.isRussian)) }
            pushImpl?(mindGramPickerController(context: context, title: isLeft ? strings.t("Свайп влево", "Swipe Left") : strings.t("Свайп вправо", "Swipe Right"), options: options, selected: { (isLeft ? MindGramSwipe.leftAction : MindGramSwipe.rightAction).rawValue }, select: { value in
                guard let action = MindGramTapAction(rawValue: value) else {
                    return
                }
                if isLeft {
                    MindGramSwipe.leftAction = action
                } else {
                    MindGramSwipe.rightAction = action
                }
            }))
        case 83:
            let alert = UIAlertController(title: strings.t("Свои слова", "Own Words"), message: strings.t("Через запятую. Слово запикается, если с него начинается сказанное.", "Comma-separated. A spoken word that starts with one is beeped."), preferredStyle: .alert)
            alert.addTextField { field in
                field.text = MindGramBleep.customWords
                field.autocapitalizationType = .none
            }
            alert.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: strings.t("Сохранить", "Save"), style: .default, handler: { [weak alert] _ in
                MindGramBleep.customWords = alert?.textFields?.first?.text ?? ""
            }))
            presentUIKitImpl?(alert)
        case 30, 31:
            let isDouble = id == 30
            let options: [(id: String, title: String)] = MindGramTapAction.allCases.map { ($0.rawValue, $0.title(isRussian: strings.isRussian)) }
            pushImpl?(mindGramPickerController(context: context, title: isDouble ? strings.t("Двойной тап", "Double Tap") : strings.t("Тройной тап", "Triple Tap"), options: options, selected: { (isDouble ? MindGramTapAction.doubleTap : MindGramTapAction.tripleTap).rawValue }, select: { value in
                guard let action = MindGramTapAction(rawValue: value) else {
                    return
                }
                if isDouble {
                    MindGramTapAction.doubleTap = action
                } else {
                    MindGramTapAction.tripleTap = action
                }
            }))
        default:
            break
        }
    }, customItem: { _, presentationData, section in
        return mindGramPreviewItem(presentationData: presentationData, sectionId: section, height: 150.0, revision: 0, build: { size, isDark in
            return MindGramPreviews.chatTools(size: size, isDark: isDark, isRussian: MindGramStrings(context.sharedContext.currentPresentationData.with { $0 }).isRussian)
        })
    })

    let controller = mindGramListController(context: context, title: { $0.t("Чат и перевод", "Chat & Translation") }, arguments: arguments, extraUpdates: translationSettings, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.custom(id: -10, section: -1, key: "preview", revision: 0))

        entries.append(.header(id: 0, section: 0, text: strings.t("ПЕРЕВОД", "TRANSLATION")))
        entries.append(.value(id: 1, section: 0, title: strings.t("Переводчик", "Translator"), value: MindGramTranslator.provider.title(isRussian: strings.isRussian)))
        entries.append(.value(id: 2, section: 0, title: strings.t("Язык перевода", "Translate To"), value: MindGramTranslator.targetLanguage.isEmpty ? strings.t("Язык приложения", "App Language") : MindGramTranslator.languageName(MindGramTranslator.targetLanguage, isRussian: strings.isRussian)))
        entries.append(.toggle(id: 3, section: 0, title: strings.t("Перевод чатов без Premium", "Chat Translation Without Premium"), info: strings.t("Панель перевода в любом чате", "The translation bar in any chat"), value: MindGramTranslator.unlocksChatTranslation))
        entries.append(.toggle(id: 4, section: 0, title: strings.t("Кнопка «Перевести»", "\"Translate\" Button"), info: strings.t("В меню каждого сообщения", "In every message's menu"), value: showTranslateButton))
        entries.append(.toggle(id: 5, section: 0, title: strings.t("Автоперевод всех чатов", "Auto-Translate All Chats"), info: strings.t("Чужой язык переводится сам", "Foreign languages translate themselves"), value: MindGramTranslator.autoTranslatesAllChats))
        if !MindGramTranslator.autoTranslatesAllChats {
            entries.append(.value(id: 6, section: 0, title: strings.t("Чаты с автопереводом", "Auto-Translated Chats"), value: "\(MindGramTranslator.autoChats.count)"))
        }
        entries.append(.footer(id: 7, section: 0, text: strings.t("Двойной тап «Перевести» и кнопка в меню используют выбранный переводчик и язык.", "The \"Translate\" button and tap action use the chosen translator and language.")))

        entries.append(.header(id: 9, section: 1, text: strings.t("МОИ СООБЩЕНИЯ", "MY MESSAGES")))
        entries.append(.value(id: 10, section: 1, title: strings.t("Переводить в чатах", "Translate in Chats"), value: "\(MindGramTranslator.outgoingChats.count)"))
        entries.append(.value(id: 11, section: 1, title: strings.t("Язык моих сообщений", "My Messages Language"), value: MindGramTranslator.languageName(MindGramTranslator.outgoingLanguage, isRussian: strings.isRussian)))
        entries.append(.footer(id: 12, section: 1, text: strings.t("Пишете по-русски — собеседник получает уже переведённый текст.", "You write in your language, the other person gets the translated text.")))

        entries.append(.header(id: 19, section: 2, text: strings.t("САМОУНИЧТОЖЕНИЕ", "SELF-DESTRUCT")))
        entries.append(.toggle(id: 20, section: 2, title: strings.t("Самоуничтожение сообщений", "Self-Destructing Messages"), info: strings.t("Мои сообщения удалятся у всех", "My messages delete for everyone"), value: MindGramSelfDestruct.isEnabled))
        if MindGramSelfDestruct.isEnabled {
            entries.append(.value(id: 21, section: 2, title: strings.t("Таймер", "Timer"), value: MindGramSelfDestruct.durationTitle(MindGramSelfDestruct.seconds, isRussian: strings.isRussian)))
            entries.append(.value(id: 22, section: 2, title: strings.t("Где", "Where"), value: scopeTitle(MindGramSelfDestruct.scope, strings)))
            if MindGramSelfDestruct.scope == .selectedChats {
                entries.append(.value(id: 23, section: 2, title: strings.t("Чаты", "Chats"), value: "\(MindGramSelfDestruct.selectedChats.count)"))
            }
            entries.append(.toggle(id: 24, section: 2, title: strings.t("Обратный отсчёт", "Countdown"), info: strings.t("⏱ 0:42 рядом со временем", "⏱ 0:42 next to the time"), value: MindGramSelfDestruct.showsCountdown))
        }
        entries.append(.footer(id: 25, section: 2, text: strings.t("Таймер начинается, когда сообщение отправлено. Удаление идёт у всех, пока MindGram открыт или работает в фоне.", "The timer starts once a message is sent. It is deleted for everyone while MindGram is open or running in the background.")))

        entries.append(.header(id: 29, section: 3, text: strings.t("ТАПЫ ПО СООБЩЕНИЮ", "TAPS ON A MESSAGE")))
        entries.append(.value(id: 30, section: 3, title: strings.t("Двойной тап", "Double Tap"), value: MindGramTapAction.doubleTap.title(isRussian: strings.isRussian)))
        entries.append(.value(id: 31, section: 3, title: strings.t("Тройной тап", "Triple Tap"), value: MindGramTapAction.tripleTap.title(isRussian: strings.isRussian)))
        entries.append(.value(id: 33, section: 3, title: strings.t("Свайп влево", "Swipe Left"), value: MindGramSwipe.leftAction.title(isRussian: strings.isRussian)))
        entries.append(.value(id: 34, section: 3, title: strings.t("Свайп вправо", "Swipe Right"), value: MindGramSwipe.rightAction.title(isRussian: strings.isRussian)))
        entries.append(.footer(id: 36, section: 3, text: strings.t("С тройным тапом двойной срабатывает с задержкой 0,3 с. Свайп вправо по сообщению заменяет «назад» свайпом по пузырю; «Ничего» — как в Telegram.", "With a triple tap set, the double tap waits 0.3 s. A right swipe on a message replaces going back from that bubble; \"Nothing\" keeps Telegram's behavior.")))

        entries.append(.header(id: 39, section: 4, text: strings.t("РАСШИФРОВКА ГОЛОСОВЫХ", "VOICE TO TEXT")))
        entries.append(.toggle(id: 40, section: 4, title: strings.t("Расшифровка без Premium", "Voice to Text Without Premium"), info: strings.t("Голосовые и кружки в текст", "Voice and round messages to text"), value: MindGramTranscription.isEnabled))
        if MindGramTranscription.isEnabled {
            entries.append(.toggle(id: 41, section: 4, title: strings.t("Всегда на устройстве", "Always on Device"), info: strings.t("Даже с Premium, звук не уходит", "Even with Premium, audio stays here"), value: MindGramTranscription.alwaysLocal))
            entries.append(.toggle(id: 43, section: 4, title: strings.t("Переводить расшифровку", "Translate Transcriptions"), info: strings.t("Голосовые сразу на вашем языке", "Voice messages in your language"), value: MindGramTranscription.translates))
        }
        entries.append(.footer(id: 45, section: 4, text: strings.t("Распознавание речи iOS на телефоне. В первый раз iOS спросит разрешение. Язык — язык iPhone.", "iOS speech recognition on the phone. iOS asks for permission the first time. The language is the iPhone's.")))

        entries.append(.header(id: 49, section: 5, text: strings.t("ПОДТВЕРЖДЕНИЕ ПЕРЕД ОТПРАВКОЙ", "CONFIRM BEFORE SENDING")))
        for (index, kind) in MindGramSendConfirm.Kind.allCases.enumerated() {
            entries.append(.toggle(id: 50 + Int32(index), section: 5, title: kind.title(isRussian: strings.isRussian), info: kind.question(isRussian: strings.isRussian), value: MindGramSendConfirm.isOn(kind)))
        }
        entries.append(.footer(id: 60, section: 5, text: strings.t("Перед отправкой появится вопрос, чтобы не отправить случайно.", "A question appears before sending, so nothing goes out by accident.")))

        entries.append(.header(id: 69, section: 6, text: strings.t("ПЕРЕСЫЛКА", "FORWARDING")))
        entries.append(.toggle(id: 70, section: 6, title: strings.t("«Переслать без автора»", "\"Forward Without Author\""), info: strings.t("Пункт в меню сообщения", "An item in the message menu"), value: MindGramForward.showsMenuItem))
        entries.append(.toggle(id: 71, section: 6, title: strings.t("Всегда без автора", "Always Without Author"), info: strings.t("И для выбранных сообщений", "Also for selected messages"), value: MindGramForward.alwaysHideAuthor))

        entries.append(.header(id: 79, section: 7, text: strings.t("ЗАПИКИВАНИЕ МАТА", "BLEEP SWEARING")))
        entries.append(.toggle(id: 80, section: 7, title: strings.t("В голосовых", "In Voice Messages"), info: strings.t("Мат заменяется писком", "Swearing becomes a beep"), value: MindGramBleep.voiceEnabled))
        entries.append(.toggle(id: 81, section: 7, title: strings.t("В кружках", "In Round Videos"), info: strings.t("Звук кружка без мата", "Round video sound without swearing"), value: MindGramBleep.roundEnabled))
        entries.append(.toggle(id: 82, section: 7, title: strings.t("Писк", "Beep"), info: strings.t("Выкл. — тишина вместо писка", "Off: silence instead of a beep"), value: MindGramBleep.usesBeep))
        entries.append(.value(id: 83, section: 7, title: strings.t("Свои слова", "Own Words"), value: MindGramBleep.customWords.isEmpty ? strings.t("нет", "none") : MindGramBleep.customWords))
        entries.append(.footer(id: 84, section: 7, text: strings.t("Речь распознаётся на iPhone перед отправкой (1–3 с), найденные слова заменяются писком. Русский и английский мат уже в списке.", "Speech is recognized on the iPhone before sending (1–3 s) and the words found are beeped. Russian and English swearing is already listed.")))

        entries.append(.header(id: 89, section: 8, text: strings.t("ФАЙЛЫ", "FILES")))
        entries.append(.toggle(id: 90, section: 8, title: strings.t("Редактор файлов", "File Editor"), info: strings.t("Имя, формат, теги перед отправкой", "Name, format, tags before sending"), value: MindGramFileTools.isEnabled))
        entries.append(.toggle(id: 92, section: 8, title: strings.t("Длинный текст — файлом", "Long Text as File"), info: strings.t("Больше 4096 символов — одним файлом", "Over 4096 characters: one file"), value: MindGramFileTools.longTextAsFile))
        entries.append(.footer(id: 93, section: 8, text: strings.t("Файл из «Файлов» открывается в редакторе: переименовать, сменить расширение, изменить код (py, ts, js, mjs и ещё ~80 форматов), теги и обложку музыки, конвертировать звук (MP3, M4A, WAV, AIFF, CAF), видео и картинки.", "A file from Files opens in the editor: rename it, change its extension, edit code (py, ts, js, mjs and ~80 more), music tags and cover, convert audio (MP3, M4A, WAV, AIFF, CAF), video and images.")))
        return entries
    })
    presentUIKitImpl = { [weak controller] c in
        controller?.present(c, animated: true)
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
