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
    })

    let controller = mindGramListController(context: context, title: { $0.t("Чат и перевод", "Chat & Translation") }, arguments: arguments, extraUpdates: translationSettings, entries: { _, strings in
        var entries: [MindGramListEntry] = []

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
        entries.append(.footer(id: 32, section: 3, text: strings.t("С тройным тапом двойной срабатывает с задержкой 0,3 с.", "With a triple tap set, the double tap waits 0.3 s.")))

        entries.append(.header(id: 39, section: 4, text: strings.t("РАСШИФРОВКА ГОЛОСОВЫХ", "VOICE TO TEXT")))
        entries.append(.toggle(id: 40, section: 4, title: strings.t("Расшифровка без Premium", "Voice to Text Without Premium"), info: strings.t("Голосовые и кружки в текст", "Voice and round messages to text"), value: MindGramTranscription.isEnabled))
        if MindGramTranscription.isEnabled {
            entries.append(.toggle(id: 41, section: 4, title: strings.t("Всегда на устройстве", "Always on Device"), info: strings.t("Даже с Premium, звук не уходит", "Even with Premium, audio stays here"), value: MindGramTranscription.alwaysLocal))
        }
        entries.append(.footer(id: 42, section: 4, text: strings.t("Распознавание речи iOS на телефоне. В первый раз iOS спросит разрешение. Язык — язык iPhone.", "iOS speech recognition on the phone. iOS asks for permission the first time. The language is the iPhone's.")))
        return entries
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
