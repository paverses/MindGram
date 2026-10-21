import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ItemListUI
import AccountContext
import MindGramCore

/// Hands the system colour picker's choice to `changed` while the user drags, so the preview follows it live.
private final class MindGramColorPickerDelegate: NSObject, UIColorPickerViewControllerDelegate {
    private let changed: (UIColor) -> Void
    private var keepAlive: MindGramColorPickerDelegate?

    init(changed: @escaping (UIColor) -> Void) {
        self.changed = changed
        super.init()
        self.keepAlive = self
    }

    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        self.changed(color)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        self.keepAlive = nil
    }
}

private func mindGramHex(_ color: UIColor) -> String {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let clamp: (CGFloat) -> Int = { Int((max(0.0, min(1.0, $0)) * 255.0).rounded()) }
    return String(format: "#%02X%02X%02X", clamp(red), clamp(green), clamp(blue))
}

/// «Удалённые сообщения»: how a kept deleted message looks — the trash colour from the system palette, its size and
/// the message's opacity on sliders, with a real chat preview that follows every change.
func mindGramDeletedLookController(context: AccountContext) -> ViewController {
    var presentUIKitImpl: ((UIViewController) -> Void)?

    let arguments = MindGramListArguments(toggle: { id, value in
        if id == 1 {
            MindGramDeleted.showsWord = value
        }
    }, open: { id in
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        switch id {
        case 10:
            let picker = UIColorPickerViewController()
            picker.title = strings.t("Цвет корзины", "Trash Color")
            picker.supportsAlpha = false
            if let parsed = MindGramDeleted.parsedMarkColor() {
                picker.selectedColor = UIColor(red: CGFloat(parsed.red), green: CGFloat(parsed.green), blue: CGFloat(parsed.blue), alpha: 1.0)
            }
            picker.delegate = MindGramColorPickerDelegate(changed: { color in
                MindGramDeleted.markColor = mindGramHex(color)
            })
            presentUIKitImpl?(picker)
        case 11:
            MindGramDeleted.markColor = ""
        default:
            break
        }
    }, customItem: { key, presentationData, section in
        let theme = presentationData.theme
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        switch key {
        case "size":
            return MindGramComponentItem(theme: theme, height: 92.0, component: AnyComponent(MindGramPercentSliderComponent(theme: theme, title: strings.t("Размер корзины", "Trash Size"), percent: MindGramDeleted.markScalePercent, range: 70 ... 200, updated: { value in
                if value != MindGramDeleted.markScalePercent {
                    MindGramDeleted.markScalePercent = value
                }
            })), sectionId: section)
        case "opacity":
            return MindGramComponentItem(theme: theme, height: 92.0, component: AnyComponent(MindGramPercentSliderComponent(theme: theme, title: strings.t("Прозрачность сообщений", "Message Opacity"), percent: MindGramDeleted.opacityPercent, range: 20 ... 100, updated: { value in
                if value != MindGramDeleted.opacityPercent {
                    MindGramDeleted.opacityPercent = value
                }
            })), sectionId: section)
        default:
            return MindGramPreviews.deleted(context: context, sectionId: section)
        }
    })

    let controller = mindGramListController(context: context, title: { $0.t("Удалённые сообщения", "Deleted Messages") }, arguments: arguments, entries: { _, strings in
        var revision = Hasher()
        revision.combine(MindGramDeleted.markColor)
        revision.combine(MindGramDeleted.markScalePercent)
        revision.combine(MindGramDeleted.opacityPercent)
        revision.combine(MindGramDeleted.showsWord)

        var entries: [MindGramListEntry] = []
        entries.append(.header(id: -11, section: -1, text: strings.t("ПРЕВЬЮ", "PREVIEW")))
        entries.append(.custom(id: -10, section: -1, key: "preview", revision: revision.finalize()))
        entries.append(.toggle(id: 1, section: 0, title: strings.t("Подпись «удалено»", "\"Deleted\" Label"), info: strings.t("Слово рядом с корзиной", "A word next to the trash"), value: MindGramDeleted.showsWord))

        entries.append(.header(id: 9, section: 1, text: strings.t("КОРЗИНА", "TRASH")))
        entries.append(.value(id: 10, section: 1, title: strings.t("Цвет корзины", "Trash Color"), value: MindGramDeleted.markColor.isEmpty ? strings.t("как время", "like the time") : MindGramDeleted.markColor))
        if !MindGramDeleted.markColor.isEmpty {
            entries.append(.action(id: 11, section: 1, title: strings.t("Цвет как у времени", "Same as the Time")))
        }
        entries.append(.custom(id: 12, section: 1, key: "size", revision: MindGramDeleted.markScalePercent))

        entries.append(.header(id: 19, section: 2, text: strings.t("СООБЩЕНИЕ", "MESSAGE")))
        entries.append(.custom(id: 20, section: 2, key: "opacity", revision: MindGramDeleted.opacityPercent))
        entries.append(.footer(id: 21, section: 2, text: strings.t("Цвет выбирается в палитре iOS: сетка, спектр или ползунки, и пипетка. Превью сверху меняется сразу.", "The colour comes from the iOS palette: grid, spectrum or sliders, and the eyedropper. The preview above changes at once.")))
        return entries
    })
    presentUIKitImpl = { [weak controller] c in
        controller?.present(c, animated: true)
    }
    return controller
}
