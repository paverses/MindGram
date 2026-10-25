import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import MindGramCore

private struct MindGramChatStatsResult {
    var total = 0
    var authors: [(String, Int)] = []
    var hours: [(Int, Int)] = []
    var words: [(String, Int)] = []
    var emoji: [(String, Int)] = []
    var averageReply: [(String, Int)] = []
    var firstDate: Int32?
}

private func mindGramComputeStats(messages: [Message], accountPeerId: PeerId, myName: String) -> MindGramChatStatsResult {
    var result = MindGramChatStatsResult()
    var authorCounts: [String: Int] = [:]
    var hourCounts: [Int: Int] = [:]
    var wordCounts: [String: Int] = [:]
    var emojiCounts: [String: Int] = [:]
    var replyTotals: [String: (Int, Int)] = [:]
    var previous: (author: String, timestamp: Int32)?
    let calendar = Calendar.current
    let stopWords: Set<String> = ["это", "что", "как", "так", "вот", "тебя", "меня", "тоже", "если", "когда", "чтобы", "только", "есть", "будет", "было", "очень", "просто", "сейчас", "там", "тут", "the", "and", "that", "this", "with", "have", "your", "what"]

    for message in messages {
        let author: String
        if message.author?.id == accountPeerId {
            author = myName
        } else if let peer = message.author {
            author = EnginePeer(peer).compactDisplayTitle
        } else {
            author = "—"
        }
        result.total += 1
        authorCounts[author, default: 0] += 1
        let hour = calendar.component(.hour, from: Date(timeIntervalSince1970: TimeInterval(message.timestamp)))
        hourCounts[hour, default: 0] += 1
        if result.firstDate == nil || message.timestamp < result.firstDate! {
            result.firstDate = message.timestamp
        }
        if let previous, previous.author != author {
            let delta = Int(message.timestamp - previous.timestamp)
            if delta > 0 && delta < 60 * 60 * 12 {
                let current = replyTotals[author] ?? (0, 0)
                replyTotals[author] = (current.0 + delta, current.1 + 1)
            }
        }
        previous = (author, message.timestamp)

        for character in message.text {
            if character.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) {
                emojiCounts[String(character), default: 0] += 1
            }
        }
        let words = message.text.lowercased().components(separatedBy: CharacterSet.letters.inverted)
        for word in words where word.count >= 4 && !stopWords.contains(word) {
            wordCounts[word, default: 0] += 1
        }
    }
    result.authors = authorCounts.sorted { $0.value > $1.value }.prefix(6).map { ($0.key, $0.value) }
    result.hours = hourCounts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    result.words = wordCounts.sorted { $0.value > $1.value }.prefix(8).map { ($0.key, $0.value) }
    result.emoji = emojiCounts.sorted { $0.value > $1.value }.prefix(8).map { ($0.key, $0.value) }
    result.averageReply = replyTotals.compactMap { key, value in value.1 > 0 ? (key, value.0 / value.1) : nil }.sorted { $0.1 < $1.1 }
    return result
}

private func mindGramDurationText(_ seconds: Int, isRussian: Bool) -> String {
    if seconds < 60 {
        return isRussian ? "\(seconds) с" : "\(seconds)s"
    } else if seconds < 3600 {
        return isRussian ? "\(seconds / 60) мин" : "\(seconds / 60) min"
    } else {
        return isRussian ? "\(seconds / 3600) ч \(seconds % 3600 / 60) мин" : "\(seconds / 3600)h \(seconds % 3600 / 60)m"
    }
}

public func mindGramChatStatsController(context: AccountContext, peer: EnginePeer) -> ViewController {
    var stats: MindGramChatStatsResult?
    let statsUpdated = ValuePromise<Int>(0, ignoreRepeated: true)
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let myName = MindGramStrings(presentationData).t("Вы", "You")
    let accountPeerId = context.account.peerId

    let disposable = MetaDisposable()
    var finished = false
    var latest: MessageHistoryView?
    let finish: () -> Void = {
        if finished {
            return
        }
        finished = true
        disposable.dispose()
        let messages = (latest?.entries.map(\.message) ?? []).sorted(by: { $0.index < $1.index })
        DispatchQueue.global(qos: .userInitiated).async {
            let result = mindGramComputeStats(messages: messages, accountPeerId: accountPeerId, myName: myName)
            DispatchQueue.main.async {
                stats = result
                statsUpdated.set(1)
            }
        }
    }
    disposable.set((context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peer.id, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 3000, fixedCombinedReadStates: nil)
    |> deliverOnMainQueue).startStrict(next: { view, _, _ in
        latest = view
        if !view.isLoading && (!view.holeEarlier || view.entries.count >= 3000) {
            finish()
        }
    }))
    DispatchQueue.main.asyncAfter(deadline: .now() + 15.0, execute: {
        finish()
    })

    let arguments = MindGramListArguments()
    return mindGramListController(context: context, title: { $0.t("Статистика", "Statistics") }, arguments: arguments, extraUpdates: statsUpdated.get() |> map { _ in Void() }, entries: { _, strings in
        guard let stats else {
            return [
                .header(id: 0, section: 0, text: peer.compactDisplayTitle.uppercased()),
                .text(id: 1, section: 0, text: strings.t("Считаю сообщения…", "Counting messages…"), monospace: false)
            ]
        }
        var entries: [MindGramListEntry] = []
        var id: Int32 = 0
        let next: () -> Int32 = {
            id += 1
            return id
        }
        entries.append(.header(id: next(), section: 0, text: peer.compactDisplayTitle.uppercased()))
        entries.append(.value(id: next(), section: 0, title: strings.t("Сообщений", "Messages"), value: "\(stats.total)"))
        if let firstDate = stats.firstDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            entries.append(.value(id: next(), section: 0, title: strings.t("Начиная с", "Since"), value: formatter.string(from: Date(timeIntervalSince1970: TimeInterval(firstDate)))))
        }
        if !stats.authors.isEmpty {
            entries.append(.header(id: next(), section: 1, text: strings.t("КТО СКОЛЬКО ПИШЕТ", "WHO WRITES HOW MUCH")))
            for (name, count) in stats.authors {
                let percent = stats.total > 0 ? count * 100 / stats.total : 0
                entries.append(.value(id: next(), section: 1, title: name, value: "\(count) · \(percent)%"))
            }
        }
        if !stats.averageReply.isEmpty {
            entries.append(.header(id: next(), section: 2, text: strings.t("СРЕДНЕЕ ВРЕМЯ ОТВЕТА", "AVERAGE REPLY TIME")))
            for (name, seconds) in stats.averageReply {
                entries.append(.value(id: next(), section: 2, title: name, value: mindGramDurationText(seconds, isRussian: strings.isRussian)))
            }
        }
        if !stats.hours.isEmpty {
            entries.append(.header(id: next(), section: 3, text: strings.t("САМЫЕ АКТИВНЫЕ ЧАСЫ", "MOST ACTIVE HOURS")))
            for (hour, count) in stats.hours {
                entries.append(.value(id: next(), section: 3, title: String(format: "%02d:00–%02d:00", hour, (hour + 1) % 24), value: "\(count)"))
            }
        }
        if !stats.words.isEmpty {
            entries.append(.header(id: next(), section: 4, text: strings.t("ЧАСТЫЕ СЛОВА", "TOP WORDS")))
            entries.append(.text(id: next(), section: 4, text: stats.words.map { "\($0.0) — \($0.1)" }.joined(separator: "\n"), monospace: false))
        }
        if !stats.emoji.isEmpty {
            entries.append(.header(id: next(), section: 5, text: strings.t("ЧАСТЫЕ ЭМОДЗИ", "TOP EMOJI")))
            entries.append(.text(id: next(), section: 5, text: stats.emoji.map { "\($0.0) \($0.1)" }.joined(separator: "   "), monospace: false))
        }
        entries.append(.footer(id: next(), section: 5, text: strings.t("По последним 3000 сообщениям, считается на телефоне.", "From the last 3000 messages, counted on the phone.")))
        return entries
    })
}
