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
    // Внешний вид
    case appearanceHeader = 0
    case appearance = 1
    case liquidGlass = 2
    case wallpaper = 3
    case tabs = 4
    case menuSections = 5
    // Профиль
    case profileHeader = 10
    case profile = 11
    case visual = 12
    // Чаты
    case chatsHeader = 20
    case messages = 21
    case phrases = 22
    case translation = 23
    case media = 24
    // Приватность
    case privacyHeader = 30
    case ghost = 31
    case deleted = 32
    // Помощь
    case helpHeader = 40
    case report = 41
    case footer = 42
    case settingsExport = 43
}

/// The "MindGram" screen opened from Settings, grouped like Telegram's own Settings: look, profile, chats,
/// privacy, help.
public func mindGramSettingsController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?

    let arguments = MindGramListArguments(open: { id in
        guard let item = MindGramMenuItem(rawValue: id) else {
            return
        }
        switch item {
        case .appearance:
            pushImpl?(mindGramAppearanceController(context: context))
        case .liquidGlass:
            pushImpl?(mindGramGlassController(context: context))
        case .wallpaper:
            pushImpl?(mindGramProfileWallpaperController(context: context))
        case .tabs:
            pushImpl?(mindGramTabsController(context: context))
        case .menuSections:
            pushImpl?(mindGramMenuSectionsController(context: context))
        case .profile:
            pushImpl?(mindGramProfileController(context: context))
        case .visual:
            pushImpl?(mindGramVisualController(context: context))
        case .messages:
            pushImpl?(mindGramChatToolsController(context: context, page: .messages))
        case .phrases:
            pushImpl?(mindGramPhrasesController(context: context))
        case .translation:
            pushImpl?(mindGramChatToolsController(context: context, page: .translation))
        case .media:
            pushImpl?(mindGramChatToolsController(context: context, page: .media))
        case .ghost:
            pushImpl?(mindGramGhostController(context: context))
        case .deleted:
            pushImpl?(mindGramDeletedController(context: context))
        case .report:
            pushImpl?(mindGramReportController(context: context))
        case .settingsExport:
            pushImpl?(mindGramSettingsExportController(context: context))
        case .appearanceHeader, .profileHeader, .chatsHeader, .privacyHeader, .helpHeader, .footer:
            break
        }
    }, icon: { name in
        switch name {
        case "appearance":
            return PresentationResourcesSettings.appearance
        case "glass":
            return PresentationResourcesSettings.effects
        case "wallpaper":
            return PresentationResourcesSettings.photosLightBlue
        case "tabs":
            return PresentationResourcesSettings.chatFolders
        case "menu":
            return PresentationResourcesSettings.settings
        case "profile":
            return PresentationResourcesSettings.myProfile
        case "visual":
            return PresentationResourcesSettings.yourColor
        case "messages":
            return PresentationResourcesSettings.savedMessages
        case "phrases":
            return PresentationResourcesSettings.stickers
        case "translation":
            return PresentationResourcesSettings.language
        case "media":
            return PresentationResourcesSettings.videos
        case "ghost":
            return PresentationResourcesSettings.security
        case "deleted":
            return PresentationResourcesSettings.dataUsage
        case "report":
            return PresentationResourcesSettings.support
        case "export":
            return PresentationResourcesSettings.files
        default:
            return nil
        }
    })

    let controller = mindGramListController(context: context, title: { $0.title }, arguments: arguments, entries: { _, strings in
        return [
            .header(id: MindGramMenuItem.appearanceHeader.rawValue, section: 0, text: strings.t("ВНЕШНИЙ ВИД", "LOOK")),
            .disclosure(id: MindGramMenuItem.appearance.rawValue, section: 0, title: strings.appearance, icon: "appearance"),
            .disclosure(id: MindGramMenuItem.liquidGlass.rawValue, section: 0, title: strings.liquidGlass, icon: "glass"),
            .betaDisclosure(id: MindGramMenuItem.wallpaper.rawValue, section: 0, title: strings.t("Обои профиля", "Profile Wallpaper"), icon: "wallpaper"),
            .disclosure(id: MindGramMenuItem.tabs.rawValue, section: 0, title: strings.t("Навбар и вкладки", "Tab Bar"), icon: "tabs"),
            .disclosure(id: MindGramMenuItem.menuSections.rawValue, section: 0, title: strings.menuSections, icon: "menu"),

            .header(id: MindGramMenuItem.profileHeader.rawValue, section: 1, text: strings.t("ПРОФИЛЬ", "PROFILE")),
            .disclosure(id: MindGramMenuItem.profile.rawValue, section: 1, title: strings.t("Данные в профиле", "Profile Details"), icon: "profile"),
            .disclosure(id: MindGramMenuItem.visual.rawValue, section: 1, title: strings.t("Визуал", "Visual"), icon: "visual"),

            .header(id: MindGramMenuItem.chatsHeader.rawValue, section: 2, text: strings.t("ЧАТЫ", "CHATS")),
            .disclosure(id: MindGramMenuItem.messages.rawValue, section: 2, title: strings.t("Сообщения", "Messages"), icon: "messages"),
            .betaDisclosure(id: MindGramMenuItem.phrases.rawValue, section: 2, title: strings.t("Быстрые фразы", "Quick Phrases"), icon: "phrases"),
            .betaDisclosure(id: MindGramMenuItem.translation.rawValue, section: 2, title: strings.t("Перевод", "Translation"), icon: "translation"),
            .disclosure(id: MindGramMenuItem.media.rawValue, section: 2, title: strings.t("Голосовые и файлы", "Voice & Files"), icon: "media"),

            .header(id: MindGramMenuItem.privacyHeader.rawValue, section: 3, text: strings.t("ПРИВАТНОСТЬ", "PRIVACY")),
            .disclosure(id: MindGramMenuItem.ghost.rawValue, section: 3, title: strings.ghostMode, icon: "ghost"),
            .disclosure(id: MindGramMenuItem.deleted.rawValue, section: 3, title: strings.t("Удалённые и правки", "Deleted & Edited"), icon: "deleted"),

            .header(id: MindGramMenuItem.helpHeader.rawValue, section: 4, text: strings.t("ПОМОЩЬ", "HELP")),
            .disclosure(id: MindGramMenuItem.report.rawValue, section: 4, title: strings.report, icon: "report"),
            .disclosure(id: MindGramMenuItem.settingsExport.rawValue, section: 4, title: strings.t("Экспорт", "Export"), icon: "export"),
            .footer(id: MindGramMenuItem.footer.rawValue, section: 4, text: strings.menuFooter)
        ]
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
