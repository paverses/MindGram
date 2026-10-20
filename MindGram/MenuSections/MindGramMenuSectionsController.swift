import Foundation
import UIKit
import Display
import TelegramPresentationData
import ItemListUI
import AccountContext
import MindGramCore

/// The name of a Settings row as Telegram shows it, in the user's language.
private func sectionName(_ section: MindGramMenuSection, strings: PresentationStrings, mindGramStrings: MindGramStrings) -> String {
    switch section {
    case .myProfile:
        return strings.Settings_MyProfile
    case .wallet:
        return strings.Settings_Money
    case .proxy:
        return strings.Settings_Proxy
    case .miniApps:
        return mindGramStrings.miniApps
    case .savedMessages:
        return strings.Settings_SavedMessages
    case .recentCalls:
        return strings.CallSettings_RecentCalls
    case .devices:
        return strings.Settings_Devices
    case .chatFolders:
        return strings.Settings_ChatFolders
    case .notifications:
        return strings.Settings_NotificationsAndSounds
    case .privacy:
        return strings.Settings_PrivacySettings
    case .dataAndStorage:
        return strings.Settings_ChatSettings
    case .appearance:
        return strings.Settings_Appearance
    case .powerSaving:
        return strings.Settings_PowerSaving
    case .language:
        return strings.Settings_AppLanguage
    case .premium:
        return strings.Settings_Premium
    case .stars:
        return strings.Settings_Stars
    case .ton:
        return strings.Settings_MyTon
    case .business:
        return strings.Settings_Business
    case .sendGift:
        return strings.Settings_SendGift
    case .passport:
        return strings.Settings_Passport
    case .watch:
        return strings.Settings_AppleWatch
    case .support:
        return strings.Settings_Support
    case .faq:
        return strings.Settings_FAQ
    case .tips:
        return strings.Settings_Tips
    case .proxySponsor:
        return mindGramStrings.proxySponsor
    }
}

/// Разделы меню: hide any row of the Settings screen (25 switches).
func mindGramMenuSectionsController(context: AccountContext) -> ViewController {
    let sections = MindGramMenuSection.allCases
    let arguments = MindGramListArguments(toggle: { id, value in
        MindGramSettings.setHidden(sections[Int(id)], value)
    })
    return mindGramListController(context: context, title: { $0.menuSections }, arguments: arguments, entries: { presentationData, strings in
        var entries: [MindGramListEntry] = []
        for (index, section) in sections.enumerated() {
            let name = sectionName(section, strings: presentationData.strings, mindGramStrings: strings)
            let info = section == .proxySponsor ? strings.proxySponsorInfo : strings.hideSectionInfo
            entries.append(.toggle(id: Int32(index), section: 0, title: strings.hideSection(name), info: info, value: MindGramSettings.isHidden(section)))
        }
        entries.append(.footer(id: 1000, section: 0, text: strings.menuSectionsFooter))
        return entries
    })
}
