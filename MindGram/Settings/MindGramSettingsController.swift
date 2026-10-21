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
    case wallpaper = 2
    case tabs = 3
    case liquidGlass = 4
    case menuSections = 5
    case ghost = 6
    case deleted = 7
    case chatTools = 8
    case phrases = 9
    case circles = 10
    case report = 11
    case footer = 12
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
        case .wallpaper:
            pushImpl?(mindGramProfileWallpaperController(context: context))
        case .tabs:
            pushImpl?(mindGramTabsController(context: context))
        case .liquidGlass:
            pushImpl?(mindGramGlassController(context: context))
        case .menuSections:
            pushImpl?(mindGramMenuSectionsController(context: context))
        case .ghost:
            pushImpl?(mindGramGhostController(context: context))
        case .deleted:
            pushImpl?(mindGramDeletedController(context: context))
        case .chatTools:
            pushImpl?(mindGramChatToolsController(context: context))
        case .phrases:
            pushImpl?(mindGramPhrasesController(context: context))
        case .circles:
            pushImpl?(mindGramCirclesController(context: context))
        case .report:
            pushImpl?(mindGramReportController(context: context))
        case .footer:
            break
        }
    }, icon: { name in
        switch name {
        case "appearance":
            return PresentationResourcesSettings.appearance
        case "profile":
            return PresentationResourcesSettings.myProfile
        case "wallpaper":
            return PresentationResourcesSettings.photosLightBlue
        case "tabs":
            return PresentationResourcesSettings.chatFolders
        case "glass":
            return PresentationResourcesSettings.effects
        case "menu":
            return PresentationResourcesSettings.settings
        case "ghost":
            return PresentationResourcesSettings.security
        case "deleted":
            return PresentationResourcesSettings.savedMessages
        case "chatTools":
            return PresentationResourcesSettings.language
        case "phrases":
            return PresentationResourcesSettings.stickers
        case "circles":
            return PresentationResourcesSettings.videos
        case "report":
            return PresentationResourcesSettings.dataUsage
        default:
            return nil
        }
    })

    let controller = mindGramListController(context: context, title: { $0.title }, arguments: arguments, entries: { _, strings in
        let section: ItemListSectionId = 0
        return [
            .disclosure(id: MindGramMenuItem.appearance.rawValue, section: section, title: strings.appearance, icon: "appearance"),
            .disclosure(id: MindGramMenuItem.profile.rawValue, section: section, title: strings.profile, icon: "profile"),
            .disclosure(id: MindGramMenuItem.wallpaper.rawValue, section: section, title: strings.t("Обои профиля", "Profile Wallpaper"), icon: "wallpaper"),
            .disclosure(id: MindGramMenuItem.tabs.rawValue, section: section, title: strings.tabs, icon: "tabs"),
            .disclosure(id: MindGramMenuItem.liquidGlass.rawValue, section: section, title: strings.liquidGlass, icon: "glass"),
            .disclosure(id: MindGramMenuItem.menuSections.rawValue, section: section, title: strings.menuSections, icon: "menu"),
            .disclosure(id: MindGramMenuItem.ghost.rawValue, section: section, title: strings.ghostMode, icon: "ghost"),
            .disclosure(id: MindGramMenuItem.deleted.rawValue, section: section, title: strings.t("Удалённые и правки", "Deleted & Edited"), icon: "deleted"),
            .disclosure(id: MindGramMenuItem.chatTools.rawValue, section: section, title: strings.t("Чат и перевод", "Chat & Translation"), icon: "chatTools"),
            .disclosure(id: MindGramMenuItem.phrases.rawValue, section: section, title: strings.t("Быстрые фразы", "Quick Phrases"), icon: "phrases"),
            .disclosure(id: MindGramMenuItem.circles.rawValue, section: section, title: strings.t("Кружки", "Round Videos"), icon: "circles"),
            .disclosure(id: MindGramMenuItem.report.rawValue, section: section, title: strings.report, icon: "report"),
            .footer(id: MindGramMenuItem.footer.rawValue, section: section, text: strings.menuFooter)
        ]
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
