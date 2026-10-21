import Foundation
import UIKit
import CoreImage
import Speech
import MindGramCore

// The «Отчёт» checks for the message, translation and round video features.
extension MindGramReport {
    private static func errorCount(_ feature: String) -> Int {
        return MindGramLog.entries.filter { $0.feature == feature }.count
    }

    static func deletedCheck() -> MindGramCheck {
        let records = MindGramDeleted.records
        let kinds = MindGramChatKind.allCases.filter { MindGramDeleted.saves($0) }.map(\.rawValue)
        let code = [
            "MindGramDeleted.isEnabled = \(MindGramDeleted.isEnabled), showsInChat = \(MindGramDeleted.showsInChat), mark = .\(MindGramDeleted.mark.rawValue)",
            "saves: \(kinds.joined(separator: ", ")), ownMessages = \(MindGramDeleted.savesOwnMessages)",
            "records = \(records.count) (Library/MindGram/deleted.json)",
            "MindGramEdits.isEnabled = \(MindGramEdits.isEnabled) (Library/MindGram/edits.json)",
            "Где: MindGram/CoreHooks/Sources/MindGramMessageHooks.swift mindGramFilterServerDeletions() ← AccountStateManagementUtils.swift (.DeleteMessages, .DeleteMessagesWithGlobalIds, .EditMessage), HistoryViewStateValidation.swift, ProcessSecretChatIncomingDecryptedOperations.swift"
        ]
        let edits = MindGramEdits.isEnabled ? "включена" : "выключена"
        guard MindGramDeleted.isEnabled else {
            return MindGramCheck(title: "Удалённые сообщения", tone: .off, status: "Выключено", words: "Удалённые сообщения исчезают, как в Telegram. История правок: \(edits).", code: code)
        }
        let place = MindGramDeleted.showsInChat ? "Они видны в чатах со значком." : "Они только в истории."
        return MindGramCheck(title: "Удалённые сообщения", tone: .ok, status: "\(records.count)", words: "Сохранено удалённых: \(records.count). \(place) История правок: \(edits).", code: code)
    }

    static func translatorCheck() -> MindGramCheck {
        let errors = self.errorCount("Перевод")
        let providerTitle = MindGramTranslator.provider.title(isRussian: true)
        var code = [
            "MindGramTranslator.provider = .\(MindGramTranslator.provider.rawValue), targetLanguage = \"\(MindGramTranslator.targetLanguage)\"",
            "unlocksChatTranslation = \(MindGramTranslator.unlocksChatTranslation), autoTranslatesAllChats = \(MindGramTranslator.autoTranslatesAllChats), autoChats = \(MindGramTranslator.autoChats.count)",
            "outgoingChats = \(MindGramTranslator.outgoingChats.count), outgoingLanguage = \(MindGramTranslator.outgoingLanguage)",
            "Где: MindGram/CoreHooks/Sources/MindGramTranslateHooks.swift ← TelegramCore Translate.swift (_internal_translate, _internal_translateTexts, _internal_translateMessagesByPeerId), EnqueueMessage.swift"
        ]
        if let last = MindGramLog.entries.last(where: { $0.feature == "Перевод" }) {
            code.append("Последняя ошибка: \(last.text) (\(last.location))")
        }
        if errors > 0 {
            return MindGramCheck(title: "Перевод", tone: .problem, status: "\(errors) ошиб.", words: "Переводчик \(providerTitle) отвечал ошибкой \(errors) раз. Попробуйте другой переводчик в «Чат и перевод».", code: code)
        }
        let unlock = MindGramTranslator.unlocksChatTranslation ? "да" : "нет"
        let auto = MindGramTranslator.autoTranslatesAllChats ? "все чаты" : "\(MindGramTranslator.autoChats.count) чатов"
        return MindGramCheck(title: "Перевод", tone: .ok, status: providerTitle, words: "Переводит \(providerTitle). Перевод чатов без Premium: \(unlock). Автоперевод: \(auto).", code: code)
    }

    static func selfDestructCheck() -> MindGramCheck {
        let pending = MindGramSelfDestruct.pending
        let duration = MindGramSelfDestruct.durationTitle(MindGramSelfDestruct.seconds, isRussian: true)
        let code = [
            "MindGramSelfDestruct.isEnabled = \(MindGramSelfDestruct.isEnabled), seconds = \(MindGramSelfDestruct.seconds), scope = .\(MindGramSelfDestruct.scope.rawValue)",
            "pending = \(pending.count) (Library/MindGram/selfdestruct.json)",
            "Где: MindGram/CoreHooks/Sources/MindGramMessageHooks.swift mindGramScheduleSelfDestruct() ← ApplyUpdateMessage.swift, mindGramManagedSelfDestruct() ← Account.swift"
        ]
        guard MindGramSelfDestruct.isEnabled else {
            return MindGramCheck(title: "Самоуничтожение", tone: .off, status: "Выключено", words: "Ваши сообщения остаются, как обычно.", code: code)
        }
        return MindGramCheck(title: "Самоуничтожение", tone: .ok, status: duration, words: "Ваши сообщения удаляются у всех через \(duration). Ждут удаления: \(pending.count).", code: code)
    }

    static func transcriptionCheck() -> MindGramCheck {
        let status = SFSpeechRecognizer.authorizationStatus()
        let statusText: String
        switch status {
        case .authorized:
            statusText = "разрешено"
        case .denied:
            statusText = "запрещено"
        case .restricted:
            statusText = "ограничено"
        case .notDetermined:
            statusText = "ещё не спрашивали"
        @unknown default:
            statusText = "неизвестно"
        }
        let recognizer = SFSpeechRecognizer()
        let available = recognizer?.isAvailable ?? false
        let onDevice = recognizer?.supportsOnDeviceRecognition ?? false
        let code = [
            "MindGramTranscription.isEnabled = \(MindGramTranscription.isEnabled), alwaysLocal = \(MindGramTranscription.alwaysLocal)",
            "SFSpeechRecognizer.authorizationStatus() = \(status.rawValue) (\(statusText))",
            "SFSpeechRecognizer(locale: \(Locale.current.identifier)): available = \(available), supportsOnDeviceRecognition = \(onDevice)",
            "Ошибок расшифровки: \(self.errorCount("Расшифровка"))",
            "Где: ChatMessageInteractiveFileNode.swift, ChatMessageInteractiveInstantVideoNode.swift (LocalAudioTranscription)"
        ]
        guard MindGramTranscription.isEnabled else {
            return MindGramCheck(title: "Расшифровка голосовых", tone: .off, status: "Выключено", words: "Без Premium голосовые не расшифровываются.", code: code)
        }
        if status == .denied || status == .restricted {
            return MindGramCheck(title: "Расшифровка голосовых", tone: .problem, status: "Нет доступа", words: "iOS запретила распознавание речи. Включите: Настройки iOS → MindGram → Распознавание речи.", code: code)
        }
        if !available {
            return MindGramCheck(title: "Расшифровка голосовых", tone: .problem, status: "Нет языка", words: "Распознавание речи iOS недоступно для языка \(Locale.current.identifier).", code: code)
        }
        return MindGramCheck(title: "Расшифровка голосовых", tone: .ok, status: "Работает", words: "Голосовые и кружки расшифровываются на iPhone (\(Locale.current.identifier)). Разрешение: \(statusText).", code: code)
    }

}
