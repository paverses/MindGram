import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import ComponentFlow
import MindGramCore

private enum TabsEntryId: Int32 {
    case previewTop = 0
    case hideContacts = 1
    case hideCalls = 2
    case sizeHeader = 10
    case height = 11
    case width = 12
    case previewBottom = 13
    case sizeFooter = 14
    case customSize = 15
}

/// Вкладки: which tabs the bottom bar shows and how big it is, with Telegram's real tab bar as the preview.
func mindGramTabsController(context: AccountContext) -> ViewController {
    let showCallsTab = Atomic<Bool>(value: CallListSettings.defaultSettings.showTab)
    let callListSettings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.callListSettings])
    |> map { sharedData -> Void in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings]?.get(CallListSettings.self) ?? CallListSettings.defaultSettings
        let _ = showCallsTab.swap(settings.showTab)
        return Void()
    }

    let arguments = MindGramListArguments(toggle: { id, value in
        switch TabsEntryId(rawValue: id) {
        case .hideContacts:
            MindGramSettings.set(.hideContactsTab, value)
        case .customSize:
            MindGramSettings.navbarCustomSize = value
        case .hideCalls:
            let _ = updateCallListSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                settings.showTab = !value
                return settings
            }).start()
        default:
            break
        }
    }, customItem: { key, presentationData, section in
        let theme = presentationData.theme
        switch key {
        case "preview":
            return MindGramComponentItem(theme: theme, height: 120.0, component: AnyComponent(MindGramTabBarPreviewComponent(
                theme: theme,
                strings: presentationData.strings,
                showContacts: !MindGramSettings.isOn(.hideContactsTab),
                showCalls: showCallsTab.with { $0 },
                revision: MindGramSettings.navbarHeightPercent * 1000 + MindGramSettings.navbarWidthPercent,
                tabBarController: (context.sharedContext.mainWindow?.viewController as? NavigationController)?.viewControllers.first as? TabBarController
            )), sectionId: section)
        case "height", "width":
            let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
            let isHeight = key == "height"
            return MindGramComponentItem(theme: theme, height: 92.0, component: AnyComponent(MindGramPercentSliderComponent(
                theme: theme,
                title: isHeight ? strings.navbarHeight : strings.navbarWidth,
                percent: isHeight ? MindGramSettings.storedNavbarHeightPercent : MindGramSettings.storedNavbarWidthPercent,
                updated: { percent in
                    if isHeight {
                        if MindGramSettings.storedNavbarHeightPercent != percent {
                            MindGramSettings.navbarHeightPercent = percent
                        }
                    } else {
                        if MindGramSettings.storedNavbarWidthPercent != percent {
                            MindGramSettings.navbarWidthPercent = percent
                        }
                    }
                }
            )), sectionId: section)
        default:
            return ItemListTextItem(presentationData: presentationData, text: .plain(""), sectionId: section)
        }
    })

    return mindGramListController(context: context, title: { $0.tabs }, arguments: arguments, extraUpdates: callListSettings, entries: { _, strings in
        let showCalls = showCallsTab.with { $0 }
        let hideContacts = MindGramSettings.isOn(.hideContactsTab)
        let height = MindGramSettings.storedNavbarHeightPercent
        let width = MindGramSettings.storedNavbarWidthPercent
        let custom = MindGramSettings.navbarCustomSize
        let locked = MindGramDesign.isClassicOnNextLaunch
        let previewRevision = (hideContacts ? 1 : 0) + (showCalls ? 2 : 0) + (custom ? 4 : 0) + height * 10 + width * 10000
        var entries: [MindGramListEntry] = [
            .custom(id: TabsEntryId.previewTop.rawValue, section: 0, key: "preview", revision: previewRevision),
            .toggle(id: TabsEntryId.hideContacts.rawValue, section: 0, title: strings.toggleTitle(.hideContactsTab), info: strings.toggleInfo(.hideContactsTab), value: hideContacts),
            .toggle(id: TabsEntryId.hideCalls.rawValue, section: 0, title: strings.hideCallsTab, info: strings.hideCallsTabInfo, value: !showCalls),
            .header(id: TabsEntryId.sizeHeader.rawValue, section: 1, text: strings.navbarSizeHeader),
            .toggleEx(id: TabsEntryId.customSize.rawValue, section: 1, title: strings.t("Свой размер", "Custom Size"), info: "", value: custom, enabled: !locked, beta: false)
        ]
        if custom && !locked {
            entries.append(.custom(id: TabsEntryId.height.rawValue, section: 1, key: "height", revision: height))
            entries.append(.custom(id: TabsEntryId.width.rawValue, section: 1, key: "width", revision: width))
            entries.append(.custom(id: TabsEntryId.previewBottom.rawValue, section: 1, key: "preview", revision: previewRevision))
        }
        entries.append(.footer(id: TabsEntryId.sizeFooter.rawValue, section: 1, text: locked ? strings.t("Недоступно в старом дизайне.", "Unavailable in the classic design.") : strings.navbarSizeFooter))
        return entries
    })
}
