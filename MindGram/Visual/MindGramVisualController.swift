import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PromptUI
import MindGramCore

public enum MindGramVisualField: Int32, CaseIterable {
    case phone = 1
    case stars = 2
    case gram = 3
    case ratingLevel = 4
    case ratingPoints = 5
    case ratingNext = 6
    case about = 7

    public func title(isRussian: Bool) -> String {
        switch self {
        case .phone:
            return isRussian ? "Визуальный номер" : "Visual Number"
        case .stars:
            return isRussian ? "Визуальные звёзды" : "Visual Stars"
        case .gram:
            return isRussian ? "Визуальные GRAM" : "Visual GRAM"
        case .ratingLevel:
            return isRussian ? "Уровень рейтинга" : "Rating Level"
        case .ratingPoints:
            return isRussian ? "Очки рейтинга" : "Rating Points"
        case .ratingNext:
            return isRussian ? "Очки до уровня" : "Points to Next Level"
        case .about:
            return isRussian ? "Визуальное описание" : "Visual Description"
        }
    }

    func value(peerId: Int64) -> String? {
        let values = MindGramVisual.values(peerId: peerId)
        switch self {
        case .phone:
            return values.phone
        case .stars:
            return values.stars
        case .gram:
            return values.gram
        case .ratingLevel:
            return values.ratingLevel.flatMap { "\($0)" }
        case .ratingPoints:
            return values.ratingPoints.flatMap { "\($0)" }
        case .ratingNext:
            return values.ratingNextPoints.flatMap { "\($0)" }
        case .about:
            return MindGramVisualProfile.about(peerId: peerId)
        }
    }

    func set(peerId: Int64, _ text: String?) {
        let text = MindGramVisual.cleaned(text)
        if self == .about {
            MindGramVisualProfile.setAbout(peerId: peerId, text)
            return
        }
        MindGramVisual.update(peerId: peerId, { values in
            switch self {
            case .phone:
                values.phone = text.map { $0.filter { $0.isNumber || $0 == "+" } }.flatMap { $0.isEmpty ? nil : $0 }
            case .stars:
                values.stars = text
            case .gram:
                values.gram = text
            case .ratingLevel:
                values.ratingLevel = text.flatMap { Int32($0) }
            case .ratingPoints:
                values.ratingPoints = text.flatMap { Int64($0) }
            case .ratingNext:
                values.ratingNextPoints = text.flatMap { Int64($0) }
            case .about:
                break
            }
        })
    }
}

public func mindGramVisualPromptController(context: AccountContext, peerId: Int64, field: MindGramVisualField) -> ViewController {
    let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
    let subtitle: String
    switch field {
    case .ratingLevel:
        subtitle = strings.t("Число, можно отрицательное. Пусто — настоящий.", "A number, can be negative. Empty restores the real one.")
    case .ratingPoints, .ratingNext:
        subtitle = strings.t("Число. Пусто — настоящий.", "A number. Empty restores the real one.")
    default:
        subtitle = strings.t("Видно только вам. Пусто — настоящее.", "Only you see it. Empty restores the real one.")
    }
    return promptController(context: context, text: field.title(isRussian: strings.isRussian), subtitle: subtitle, value: field.value(peerId: peerId) ?? "", characterLimit: field == .about ? 1000 : 64, apply: { text in
        guard let text else {
            return
        }
        field.set(peerId: peerId, text)
    })
}

func mindGramVisualController(context: AccountContext) -> ViewController {
    let accountPeerId = context.account.peerId.id._internalGetInt64Value()
    let options: [MindGramMarks.Kind?] = [nil] + MindGramMarks.Kind.manualCases.map { Optional($0) }
    var presentImpl: ((ViewController) -> Void)?

    let arguments = MindGramListArguments(open: { id in
        if let field = MindGramVisualField(rawValue: id) ?? MindGramVisualField(rawValue: id - 20) {
            presentImpl?(mindGramVisualPromptController(context: context, peerId: accountPeerId, field: field))
            return
        }
        let index = Int(id) - 50
        if index >= 0 && index < options.count {
            MindGramMarks.setMark(peerId: accountPeerId, options[index])
        }
    })

    let controller = mindGramListController(context: context, title: { $0.t("Визуал", "Visual") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        let empty = strings.t("Нет", "Off")
        entries.append(.header(id: 0, section: 0, text: strings.t("ПРОФИЛЬ", "PROFILE")))
        for field in [MindGramVisualField.phone, .stars, .gram, .about] {
            entries.append(.value(id: field.rawValue, section: 0, title: field.title(isRussian: strings.isRussian), value: field.value(peerId: accountPeerId).map { String($0.prefix(24)) } ?? empty))
        }
        entries.append(.header(id: 20, section: 1, text: strings.t("РЕЙТИНГ", "RATING")))
        for field in [MindGramVisualField.ratingLevel, .ratingPoints, .ratingNext] {
            entries.append(.value(id: field.rawValue + 20, section: 1, title: field.title(isRussian: strings.isRussian), value: field.value(peerId: accountPeerId) ?? empty))
        }
        entries.append(.header(id: 49, section: 2, text: strings.t("МЕТКА", "MARK")))
        let current = MindGramMarks.storedMark(peerId: accountPeerId)
        for (index, option) in options.enumerated() {
            entries.append(.check(id: 50 + Int32(index), section: 2, title: option?.title ?? strings.t("Без метки", "No Mark"), checked: option == current))
        }
        entries.append(.footer(id: 70, section: 2, text: strings.t("Видно только вам. Mind ставится бета-тестерам автоматически.", "Only you see it. Beta testers get Mind automatically.")))
        return entries
    })
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
