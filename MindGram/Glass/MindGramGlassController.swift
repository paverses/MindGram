import Foundation
import UIKit
import Display
import ItemListUI
import AccountContext
import SettingsUI
import MindGramCore

private let glassToggles: [MindGramToggle] = [
    .glassMessages,
    .glassProfile,
    .glassBotButtons
]

/// Liquid Glass: clear glass on messages, profile buttons and bot buttons, with real message bubbles as the preview.
func mindGramGlassController(context: AccountContext) -> ViewController {
    let arguments = MindGramListArguments(toggle: { id, value in
        MindGramSettings.set(glassToggles[Int(id) - 10], value)
    }, customItem: { _, _, section in
        return mindGramChatPreviewItem(context: context, presentationData: context.sharedContext.currentPresentationData.with { $0 }, sectionId: section)
    })
    return mindGramListController(context: context, title: { $0.liquidGlass }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.header(id: 0, section: 0, text: strings.glassHeader))
        entries.append(.custom(id: 1, section: 0, key: "preview", revision: MindGramSettings.isOn(.glassMessages) ? 1 : 0))
        for (index, toggle) in glassToggles.enumerated() {
            entries.append(.toggleEx(id: Int32(10 + index), section: 1, title: strings.toggleTitle(toggle), info: strings.toggleInfo(toggle), value: MindGramSettings.storedValue(toggle), enabled: !MindGramSettings.isLockedByClassicDesign(toggle), beta: false))
        }
        entries.append(.footer(id: 100, section: 1, text: strings.glassFooter))
        return entries
    })
}
