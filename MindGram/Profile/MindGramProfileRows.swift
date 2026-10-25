import Foundation
import TelegramCore
import TelegramPresentationData
import MindGramCore

/// A row MindGram adds to a profile, shown like Telegram's "username" row.
public struct MindGramProfileRow {
    public let key: String
    public let label: String
    public let value: String
    /// What a long press copies; nil when the row is not copyable.
    public let copyValue: String?
}

private func dateFormatter(_ strings: MindGramStrings, format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: strings.isRussian ? "ru_RU" : "en_US")
    formatter.setLocalizedDateFormatFromTemplate(format)
    return formatter
}

/// The ID / DC / mutual / creation date rows for a profile, according to the MindGram switches.
public func mindGramProfileRows(peer: EnginePeer, accountPeerId: EnginePeer.Id, presentationData: PresentationData) -> [MindGramProfileRow] {
    let strings = MindGramStrings(presentationData)
    var rows: [MindGramProfileRow] = []

    if case .user = peer, MindGramBetaTesters.isBetaTester(peer.id.id._internalGetInt64Value()) {
        rows.append(MindGramProfileRow(key: "beta", label: strings.t("Статус MindGram", "MindGram Status"), value: "Beta Tester", copyValue: nil))
    }

    if peer.id != accountPeerId {
        let visual = MindGramVisual.values(peerId: peer.id.id._internalGetInt64Value())
        if let stars = visual.stars {
            rows.append(MindGramProfileRow(key: "stars", label: strings.t("Звёзды", "Stars"), value: stars, copyValue: stars))
        }
        if let gram = visual.gram {
            rows.append(MindGramProfileRow(key: "gram", label: "GRAM", value: gram, copyValue: gram))
        }
    }

    if let mark = MindGramMarks.mark(peerId: peer.id.id._internalGetInt64Value()) {
        rows.append(MindGramProfileRow(key: "mark", label: strings.t("Метка", "Mark"), value: mark.confirmedText(isRussian: strings.isRussian), copyValue: nil))
    }

    if MindGramSettings.isOn(.showPeerId) {
        let rawId = peer.id.id._internalGetInt64Value()
        let shownId: String
        switch peer {
        case .channel:
            // The form bots and the Bot API use for channels and supergroups.
            shownId = "-100\(rawId)"
        case .legacyGroup:
            shownId = "-\(rawId)"
        default:
            shownId = "\(rawId)"
        }
        rows.append(MindGramProfileRow(key: "id", label: strings.peerIdLabel, value: shownId, copyValue: shownId))
    }

    if MindGramSettings.isOn(.showDatacenter) {
        // A profile photo is stored on the account's datacenter, so its location is the account's DC.
        if let resource = peer.profileImageRepresentations.first?.resource as? CloudPeerPhotoSizeMediaResource {
            let datacenterId = resource.datacenterId
            rows.append(MindGramProfileRow(key: "dc", label: strings.datacenterLabel, value: MindGramDatacenter.title(datacenterId), copyValue: "\(datacenterId)"))
        }
    }

    if MindGramSettings.isOn(.showPeerId), case let .user(user) = peer, user.id != accountPeerId, user.botInfo == nil {
        rows.append(MindGramProfileRow(key: "mutual", label: strings.mutualLabel, value: user.flags.contains(.mutualContact) ? strings.yes : strings.no, copyValue: nil))
    }

    if MindGramSettings.isOn(.exactCreationDate) {
        var creationDate: Int32?
        switch peer {
        case let .channel(channel):
            creationDate = channel.creationDate
        case let .legacyGroup(group):
            creationDate = group.creationDate
        default:
            break
        }
        if let creationDate, creationDate > 0 {
            let text = dateFormatter(strings, format: "dMMMyyyy").string(from: Date(timeIntervalSince1970: TimeInterval(creationDate)))
            rows.append(MindGramProfileRow(key: "created", label: strings.createdLabel, value: text, copyValue: text))
        }
    }

    if MindGramSettings.isOn(.approximateAccountAge), case let .user(user) = peer, user.botInfo == nil {
        let formatter = dateFormatter(strings, format: "MMMyyyy")
        let text: String
        switch MindGramAccountAge.estimate(userId: user.id.id._internalGetInt64Value()) {
        case let .olderThan(date):
            text = (strings.isRussian ? "до " : "before ") + formatter.string(from: date)
        case let .approximately(date):
            text = "≈ " + formatter.string(from: date)
        case let .newerThan(date):
            text = (strings.isRussian ? "после " : "after ") + formatter.string(from: date)
        }
        rows.append(MindGramProfileRow(key: "registered", label: strings.registeredLabel, value: text, copyValue: nil))
    }

    return rows
}

/// "≈ 12:43" for a user MindGram saw active, when their last seen is hidden ("recently").
public func mindGramApproximateLastSeen(userId: Int64, presentationData: PresentationData) -> String? {
    guard MindGramSettings.isOn(.approximateLastSeen), let timestamp = MindGramActivityTracker.lastActivity(userId: userId) else {
        return nil
    }
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let strings = MindGramStrings(presentationData)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: strings.isRussian ? "ru_RU" : "en_US")
    if Calendar.current.isDateInToday(date) {
        formatter.setLocalizedDateFormatFromTemplate("HHmm")
    } else {
        formatter.setLocalizedDateFormatFromTemplate("dMMMHHmm")
    }
    return "≈ " + formatter.string(from: date)
}
