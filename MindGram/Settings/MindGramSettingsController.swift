import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import MindGramCore

/// The icon of the "MindGram" row in Settings: the logo on a black rounded square, sized like the other settings icons.
public let mindGramSettingsIcon: UIImage = MindGramLogo.image(size: CGSize(width: 30.0, height: 30.0), color: .white, inset: 6.5, backgroundColor: .black, cornerRadius: 8.0)

private enum MindGramMenuItem: Int32 {
    case appearance = 0
    case profile = 1
    case tabs = 2
    case liquidGlass = 3
    case menuSections = 4
    case footer = 5
}

/// The "MindGram" screen opened from Settings: one row per MindGram section.
public func mindGramSettingsController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?

    let arguments = MindGramListArguments(open: { id in
        guard let item = MindGramMenuItem(rawValue: id) else {
            return
        }
        switch item {
        case .appearance:
            pushImpl?(mindGramAppearanceController(context: context))
        case .profile:
            pushImpl?(mindGramProfileController(context: context))
        case .tabs:
            pushImpl?(mindGramTabsController(context: context))
        case .liquidGlass:
            pushImpl?(mindGramGlassController(context: context))
        case .menuSections:
            pushImpl?(mindGramMenuSectionsController(context: context))
        case .footer:
            break
        }
    }, icon: { name in
        switch name {
        case "appearance":
            return PresentationResourcesSettings.appearance
        case "profile":
            return PresentationResourcesSettings.myProfile
        case "tabs":
            return PresentationResourcesSettings.chatFolders
        case "glass":
            return PresentationResourcesSettings.effects
        case "menu":
            return PresentationResourcesSettings.settings
        default:
            return nil
        }
    })

    let controller = mindGramListController(context: context, title: { $0.title }, arguments: arguments, entries: { _, strings in
        let section: ItemListSectionId = 0
        return [
            .disclosure(id: MindGramMenuItem.appearance.rawValue, section: section, title: strings.appearance, icon: "appearance"),
            .disclosure(id: MindGramMenuItem.profile.rawValue, section: section, title: strings.profile, icon: "profile"),
            .disclosure(id: MindGramMenuItem.tabs.rawValue, section: section, title: strings.tabs, icon: "tabs"),
            .disclosure(id: MindGramMenuItem.liquidGlass.rawValue, section: section, title: strings.liquidGlass, icon: "glass"),
            .disclosure(id: MindGramMenuItem.menuSections.rawValue, section: section, title: strings.menuSections, icon: "menu"),
            .footer(id: MindGramMenuItem.footer.rawValue, section: section, text: strings.menuFooter)
        ]
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
