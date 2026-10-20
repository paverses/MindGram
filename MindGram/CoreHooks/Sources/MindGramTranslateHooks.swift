import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MindGramGhost
import MindGramTranslator

// MindGram hooks for translation: Telegram's translate requests go to the translator chosen in
// «Чат и перевод» instead of the server (which needs Premium for whole chats).

private func mindGramTranslateSignal(texts: [String], fromLang: String?, toLang: String) -> Signal<(texts: [String], detected: String?), TranslationError> {
    if MindGramTranslator.provider == .apple, let service = engineExperimentalInternalTranslationService, let fromLang, !fromLang.isEmpty {
        var keyed: [AnyHashable: String] = [:]
        for (index, text) in texts.enumerated() {
            keyed[AnyHashable(index)] = text
        }
        return service.translate(texts: keyed, fromLang: fromLang, toLang: toLang)
        |> castError(TranslationError.self)
        |> mapToSignal { result -> Signal<(texts: [String], detected: String?), TranslationError> in
            guard let result else {
                MindGramLog.error("Перевод", "Apple Translation не перевела текст (\(fromLang) → \(toLang)); переведите Google или скачайте язык в Настройках iOS → Перевод")
                return .fail(.generic)
            }
            return .single((texts.enumerated().map { result[AnyHashable($0.offset)] ?? $0.element }, fromLang))
        }
    }
    return Signal { subscriber in
        MindGramTranslator.translate(texts: texts, fromLang: fromLang, toLang: toLang, completion: { result in
            switch result {
            case let .success(value):
                subscriber.putNext(value)
                subscriber.putCompletion()
            case let .failure(error):
                MindGramLog.error("Перевод", "\(MindGramTranslator.provider.rawValue): \(error)")
                subscriber.putError(.generic)
            }
        })
        return EmptyDisposable
    }
}

/// One text («Перевести» in a message's menu, a transcription). nil: let Telegram's server do it.
func mindGramTranslate(text: String, toLang: String) -> Signal<(String, [MessageTextEntity])?, TranslationError>? {
    guard MindGramTranslator.usesExternalProvider else {
        return nil
    }
    // The language chosen in «Чат и перевод» wins over the app language.
    let effectiveLang = MindGramTranslator.targetLanguage.isEmpty ? toLang : MindGramTranslator.targetLanguage
    return mindGramTranslateSignal(texts: [text], fromLang: nil, toLang: effectiveLang)
    |> map { result -> (String, [MessageTextEntity])? in
        return (result.texts.first ?? text, [])
    }
}

/// Several texts (poll options). nil: let Telegram's server do it.
func mindGramTranslateTexts(_ texts: [(String, [MessageTextEntity])], toLang: String) -> Signal<[(String, [MessageTextEntity])], TranslationError>? {
    guard MindGramTranslator.usesExternalProvider else {
        return nil
    }
    return mindGramTranslateSignal(texts: texts.map(\.0), fromLang: nil, toLang: toLang)
    |> map { result -> [(String, [MessageTextEntity])] in
        return result.texts.map { ($0, []) }
    }
}

/// Messages of a chat being translated (the translation bar, auto-translate). Returns the same
/// `messages.translatedText` shape the server would, so Telegram stores the result as usual.
func mindGramTranslateMessages(postbox: Postbox, messageIds: [MessageId], fromLang: String?, toLang: String) -> Signal<Api.messages.TranslatedText?, TranslationError>? {
    guard MindGramTranslator.usesExternalProvider else {
        return nil
    }
    return postbox.transaction { transaction -> [String] in
        return messageIds.map { transaction.getMessage($0)?.text ?? "" }
    }
    |> castError(TranslationError.self)
    |> mapToSignal { texts -> Signal<Api.messages.TranslatedText?, TranslationError> in
        return mindGramTranslateSignal(texts: texts, fromLang: fromLang, toLang: toLang)
        |> map { result -> Api.messages.TranslatedText? in
            let items: [Api.TextWithEntities] = result.texts.map { .textWithEntities(.init(text: $0, entities: [])) }
            return .translateResult(.init(result: items))
        }
    }
}

/// Own messages in a chat from «Переводить мои сообщения»: translated into the chosen language before
/// they are sent. Formatting is dropped for translated texts, since its ranges no longer match.
func mindGramTranslateOutgoing(peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[EnqueueMessage], NoError>? {
    guard MindGramTranslator.translatesOutgoing(peerId: peerId.toInt64()) else {
        return nil
    }
    var texts: [String] = []
    for message in messages {
        if case let .message(text, _, _, _, _, _, _, _, _, _) = message {
            texts.append(text)
        } else {
            texts.append("")
        }
    }
    if texts.allSatisfy({ $0.isEmpty }) {
        return nil
    }
    return mindGramTranslateSignal(texts: texts, fromLang: nil, toLang: MindGramTranslator.outgoingLanguage)
    |> map { result -> [EnqueueMessage] in
        return messages.enumerated().map { index, message -> EnqueueMessage in
            guard index < result.texts.count, case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message, !text.isEmpty else {
                return message
            }
            let translated = result.texts[index]
            if translated == text {
                return message
            }
            let updatedAttributes = attributes.filter { !($0 is TextEntitiesMessageAttribute) }
            return .message(text: translated, attributes: updatedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        }
    }
    |> `catch` { _ -> Signal<[EnqueueMessage], NoError> in
        // Send the original rather than nothing.
        return .single(messages)
    }
}
