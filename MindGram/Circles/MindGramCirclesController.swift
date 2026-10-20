import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import MindGramCore

private let effectGroups: [MindGramRoundEffect.Group] = [.privacy, .masks, .filters]

private func groupTitle(_ group: MindGramRoundEffect.Group, _ strings: MindGramStrings) -> String {
    switch group {
    case .privacy:
        return strings.t("ПРИВАТНОСТЬ", "PRIVACY")
    case .masks:
        return strings.t("МАСКИ", "MASKS")
    case .filters:
        return strings.t("ФИЛЬТРЫ", "FILTERS")
    }
}

private func effects(in group: MindGramRoundEffect.Group) -> [MindGramRoundEffect] {
    return MindGramRoundEffect.allCases.filter { $0.group == group }
}

private let strengthOptions: [(value: Double, ru: String, en: String)] = [
    (0.35, "Слабо", "Light"),
    (0.7, "Средне", "Medium"),
    (1.0, "Сильно", "Strong")
]

/// Кружки: effects and masks for round videos — which one the camera starts with, swipes, and their settings.
func mindGramCirclesController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?

    let effectForId: (Int32) -> MindGramRoundEffect? = { id in
        if id == 50 {
            return MindGramRoundEffect.off
        }
        for (groupIndex, group) in effectGroups.enumerated() {
            let base = Int32(100 * (groupIndex + 1))
            let list = effects(in: group)
            if id > base && id <= base + Int32(list.count) {
                return list[Int(id - base - 1)]
            }
        }
        return nil
    }

    let arguments = MindGramListArguments(toggle: { id, value in
        switch id {
        case 0:
            MindGramRoundVideo.isEnabled = value
        case 1:
            MindGramRoundVideo.swipeToSwitch = value
        default:
            break
        }
    }, open: { id in
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        if let effect = effectForId(id) {
            MindGramRoundVideo.effect = effect
            return
        }
        switch id {
        case 500:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Эмодзи-маска", "Emoji Mask"), options: MindGramRoundVideo.maskEmojis.map { ($0, $0) }, selected: { MindGramRoundVideo.maskEmoji }, select: { MindGramRoundVideo.maskEmoji = $0 }))
        case 501:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Фон", "Background"), options: MindGramRoundVideo.backgrounds.enumerated().map { ("\($0.offset)", strings.isRussian ? $0.element.ru : $0.element.en) }, selected: { "\(MindGramRoundVideo.backgroundIndex)" }, select: { value in
                if let index = Int(value) {
                    MindGramRoundVideo.backgroundIndex = index
                }
            }))
        case 502:
            pushImpl?(mindGramPickerController(context: context, title: strings.t("Сила эффекта", "Effect Strength"), footer: strings.t("Для размытия, пикселей, глитча и «Красоты».", "For blurs, pixels, glitch and Beauty."), options: strengthOptions.map { ("\($0.value)", strings.isRussian ? $0.ru : $0.en) }, selected: {
                let current = MindGramRoundVideo.strength
                let nearest = strengthOptions.min(by: { abs($0.value - current) < abs($1.value - current) })?.value ?? 0.7
                return "\(nearest)"
            }, select: { value in
                if let strength = Double(value) {
                    MindGramRoundVideo.strength = strength
                }
            }))
        default:
            break
        }
    })

    let controller = mindGramListController(context: context, title: { $0.t("Кружки", "Round Videos") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.toggle(id: 0, section: 0, title: strings.t("Эффекты в кружках", "Round Video Effects"), info: strings.t("Маски и фильтры при записи", "Masks and filters while recording"), value: MindGramRoundVideo.isEnabled))
        if MindGramRoundVideo.isEnabled {
            entries.append(.toggle(id: 1, section: 0, title: strings.t("Свайп по кружку", "Swipe the Circle"), info: strings.t("Листать эффекты при записи", "Switch effects while recording"), value: MindGramRoundVideo.swipeToSwitch))
        }
        entries.append(.footer(id: 2, section: 0, text: strings.t("Эффект видно в кружке во время записи, и он сохраняется в видео. Лицо находит iPhone, ничего не отправляется в интернет.", "You see the effect in the circle while recording, and it is saved in the video. The iPhone finds your face; nothing is sent anywhere.")))

        guard MindGramRoundVideo.isEnabled else {
            return entries
        }
        let current = MindGramRoundVideo.effect
        entries.append(.header(id: 49, section: 1, text: strings.t("ЭФФЕКТ ПРИ ОТКРЫТИИ КАМЕРЫ", "EFFECT WHEN THE CAMERA OPENS")))
        entries.append(.check(id: 50, section: 1, title: MindGramRoundEffect.off.title(isRussian: strings.isRussian), checked: current == .off))
        for (groupIndex, group) in effectGroups.enumerated() {
            let base = Int32(100 * (groupIndex + 1))
            let section = ItemListSectionId(2 + groupIndex)
            entries.append(.header(id: base, section: section, text: groupTitle(group, strings)))
            for (index, effect) in effects(in: group).enumerated() {
                entries.append(.check(id: base + 1 + Int32(index), section: section, title: "\(effect.title(isRussian: strings.isRussian)) — \(effect.info(isRussian: strings.isRussian))", checked: current == effect))
            }
        }

        let preset = MindGramRoundVideo.backgrounds[MindGramRoundVideo.backgroundIndex]
        let strength = strengthOptions.min(by: { abs($0.value - MindGramRoundVideo.strength) < abs($1.value - MindGramRoundVideo.strength) })
        entries.append(.header(id: 499, section: 10, text: strings.t("НАСТРОЙКИ ЭФФЕКТОВ", "EFFECT SETTINGS")))
        entries.append(.value(id: 500, section: 10, title: strings.t("Эмодзи-маска", "Emoji Mask"), value: MindGramRoundVideo.maskEmoji))
        entries.append(.value(id: 501, section: 10, title: strings.t("Фон", "Background"), value: strings.isRussian ? preset.ru : preset.en))
        entries.append(.value(id: 502, section: 10, title: strings.t("Сила эффекта", "Effect Strength"), value: strength.map { strings.isRussian ? $0.ru : $0.en } ?? ""))
        entries.append(.footer(id: 503, section: 10, text: strings.t("Размытие фона и замена фона работают на iOS 15 и новее.", "Background blur and replacement need iOS 15 or later.")))
        return entries
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
