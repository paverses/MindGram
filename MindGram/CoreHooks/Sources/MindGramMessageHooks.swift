import Foundation
import Postbox
import SwiftSignalKit
import MindGramGhost
import MindGramMessages

// MindGram hooks for messages: keeping deleted messages, edit history, self-destructing own messages.

func mindGramMessageKey(_ id: MessageId) -> MindGramMessageKey {
    return MindGramMessageKey(peerId: id.peerId.toInt64(), namespace: id.namespace, id: id.id)
}

func mindGramChatKind(transaction: Transaction, peerId: PeerId) -> MindGramChatKind {
    let peer = transaction.getPeer(peerId)
    if let user = peer as? TelegramUser {
        return user.botInfo != nil ? .bot : .privateChat
    } else if peer is TelegramSecretChat {
        return .secretChat
    } else if peer is TelegramGroup {
        return .group
    } else if let channel = peer as? TelegramChannel {
        if case .broadcast = channel.info {
            return .channel
        }
        return .group
    }
    switch peerId.namespace {
    case Namespaces.Peer.SecretChat:
        return .secretChat
    case Namespaces.Peer.CloudGroup:
        return .group
    case Namespaces.Peer.CloudChannel:
        return .channel
    default:
        return .privateChat
    }
}

private func mindGramMediaSummary(_ message: Message) -> String {
    for media in message.media {
        if media is TelegramMediaImage {
            return "Фото"
        } else if let file = media as? TelegramMediaFile {
            if file.isVoice {
                return "Голосовое"
            } else if file.isInstantVideo {
                return "Кружок"
            } else if file.isSticker {
                return "Стикер"
            } else if file.isAnimated {
                return "GIF"
            } else if file.isVideo {
                return "Видео"
            } else {
                return "Файл"
            }
        } else if media is TelegramMediaPoll {
            return "Опрос"
        } else if media is TelegramMediaMap {
            return "Геопозиция"
        } else if media is TelegramMediaContact {
            return "Контакт"
        }
    }
    return ""
}

/// Rewrites a message unchanged so open chats lay it out again (and read the MindGram mark or countdown).
func mindGramTouchMessage(transaction: Transaction, id: MessageId) {
    transaction.updateMessage(id, update: { currentMessage in
        let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
        return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
    })
}

/// The server deleted these messages. Saves the ones «Удалённые» keeps and returns the ids that should
/// really be deleted: everything when saving is off, and the kept ones too when they are hidden from chats.
func mindGramFilterServerDeletions(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    guard MindGramDeleted.isEnabled else {
        return ids
    }
    var result: [MessageId] = []
    let now = Int32(Date().timeIntervalSince1970)
    for id in ids {
        guard id.namespace == Namespaces.Message.Cloud || id.peerId.namespace == Namespaces.Peer.SecretChat, let message = transaction.getMessage(id) else {
            result.append(id)
            continue
        }
        let kind = mindGramChatKind(transaction: transaction, peerId: id.peerId)
        let isOutgoing = !message.flags.contains(.Incoming)
        guard MindGramDeleted.shouldKeep(kind: kind, isOutgoing: isOutgoing) else {
            result.append(id)
            continue
        }
        let key = mindGramMessageKey(id)
        if MindGramDeleted.isDeleted(key) {
            // Already kept; a second deletion (validation after a gap) changes nothing.
            continue
        }
        var chatTitle = transaction.getPeer(id.peerId)?.debugDisplayTitle ?? ""
        if let secretChat = transaction.getPeer(id.peerId) as? TelegramSecretChat, let user = transaction.getPeer(secretChat.regularPeerId) {
            chatTitle = user.debugDisplayTitle
        }
        MindGramDeleted.add(MindGramDeleted.Record(
            key: key,
            chatKind: kind,
            chatTitle: chatTitle,
            author: message.author?.debugDisplayTitle ?? "",
            authorId: message.author?.id.toInt64(),
            text: message.text,
            media: mindGramMediaSummary(message),
            isOutgoing: isOutgoing,
            date: message.timestamp,
            deletedAt: now
        ))
        if MindGramDeleted.showsInChat {
            mindGramTouchMessage(transaction: transaction, id: id)
        } else {
            result.append(id)
        }
    }
    return result
}

/// The same for deletions that arrive by global id (private chats and basic groups).
func mindGramFilterServerDeletions(transaction: Transaction, globalIds: [Int32]) -> [Int32] {
    guard MindGramDeleted.isEnabled else {
        return globalIds
    }
    var result: [Int32] = []
    for globalId in globalIds {
        guard let id = transaction.messageIdsForGlobalIds([globalId]).first else {
            result.append(globalId)
            continue
        }
        if !mindGramFilterServerDeletions(transaction: transaction, ids: [id]).isEmpty {
            result.append(globalId)
        }
    }
    return result
}

/// A message is being edited on the server: keeps its previous text for «История правок».
func mindGramRecordEdit(previousMessage: Message, updatedText: String) {
    guard MindGramEdits.isEnabled, previousMessage.text != updatedText else {
        return
    }
    var previousDate = previousMessage.timestamp
    for attribute in previousMessage.attributes {
        if let attribute = attribute as? EditedMessageAttribute {
            previousDate = attribute.date
        }
    }
    MindGramEdits.record(mindGramMessageKey(previousMessage.id), previousText: previousMessage.text, previousDate: previousDate)
}

/// An own message got its server id: starts its self-destruct timer when that is on for the chat.
func mindGramScheduleSelfDestruct(transaction: Transaction, id: MessageId) {
    guard MindGramSelfDestruct.isEnabled, id.namespace == Namespaces.Message.Cloud else {
        return
    }
    let kind = mindGramChatKind(transaction: transaction, peerId: id.peerId)
    guard MindGramSelfDestruct.applies(peerId: id.peerId.toInt64(), kind: kind) else {
        return
    }
    MindGramSelfDestruct.schedule(mindGramMessageKey(id))
}

/// Runs for the account's lifetime: deletes own messages whose timer ran out (for everyone) and redraws
/// the ones still counting down whenever their countdown text changes. Only messages this account has
/// are touched, so with several accounts each one handles its own.
func mindGramManagedSelfDestruct(account: Account) -> Signal<Void, NoError> {
    return Signal { subscriber in
        let queue = Queue(name: "MindGram.selfDestruct")
        var shownTexts: [MindGramMessageKey: String] = [:]
        var inFlight = Set<MindGramMessageKey>()
        var isChecking = false

        let tick = {
            let pending = MindGramSelfDestruct.pending
            if pending.isEmpty || isChecking {
                if pending.isEmpty {
                    shownTexts.removeAll()
                }
                return
            }
            isChecking = true
            let _ = (account.postbox.transaction({ transaction -> Set<MindGramMessageKey> in
                var existing = Set<MindGramMessageKey>()
                for item in pending {
                    let id = MessageId(peerId: PeerId(item.key.peerId), namespace: item.key.namespace, id: item.key.id)
                    if let message = transaction.getMessage(id), !message.flags.contains(.Incoming) {
                        existing.insert(item.key)
                    }
                }
                return existing
            })
            |> deliverOn(queue)).start(next: { existing in
                isChecking = false
                let now = Date().timeIntervalSince1970
                var due: [MessageId] = []
                var touch: [MessageId] = []
                var stale: [MindGramMessageKey] = []
                for item in pending {
                    let id = MessageId(peerId: PeerId(item.key.peerId), namespace: item.key.namespace, id: item.key.id)
                    guard existing.contains(item.key) else {
                        // Deleted by hand, or another account's message that is long overdue.
                        if now > item.deadline + 60.0 {
                            stale.append(item.key)
                        }
                        continue
                    }
                    if item.deadline <= now {
                        if !inFlight.contains(item.key) {
                            inFlight.insert(item.key)
                            due.append(id)
                        }
                    } else if MindGramSelfDestruct.showsCountdown {
                        let text = MindGramSelfDestruct.countdownText(deadline: item.deadline, isRussian: true)
                        if shownTexts[item.key] != text {
                            shownTexts[item.key] = text
                            touch.append(id)
                        }
                    }
                }
                if !stale.isEmpty {
                    MindGramSelfDestruct.remove(stale)
                }
                if !touch.isEmpty {
                    let _ = account.postbox.transaction({ transaction -> Void in
                        for id in touch where transaction.getMessage(id) != nil {
                            mindGramTouchMessage(transaction: transaction, id: id)
                        }
                    }).start()
                }
                if !due.isEmpty {
                    let keys = due.map(mindGramMessageKey)
                    let _ = (_internal_deleteMessagesInteractively(account: account, messageIds: due, type: .forEveryone)
                    |> deliverOn(queue)).start(completed: {
                        MindGramSelfDestruct.remove(keys)
                        for key in keys {
                            inFlight.remove(key)
                            shownTexts.removeValue(forKey: key)
                        }
                    })
                }
            })
        }

        let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: {
            tick()
        }, queue: queue)
        timer.start()
        return ActionDisposable {
            timer.invalidate()
            let _ = subscriber
        }
    }
}
