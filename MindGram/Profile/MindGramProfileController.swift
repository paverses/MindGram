import Foundation
import UIKit
import Display
import ItemListUI
import AccountContext
import MindGramCore

private let profileToggles: [MindGramToggle] = [
    .showPeerId,
    .showDatacenter,
    .fullViewCounts,
    .hidePhoneNumber,
    .exactCreationDate,
    .approximateAccountAge,
    .timestampSeconds,
    .approximateLastSeen
]

/// Профиль: what profiles and messages show.
func mindGramProfileController(context: AccountContext) -> ViewController {
    let arguments = MindGramListArguments(toggle: { id, value in
        MindGramSettings.set(profileToggles[Int(id)], value)
    })
    return mindGramListController(context: context, title: { $0.profile }, arguments: arguments, entries: { _, strings in
        let section: ItemListSectionId = 0
        var entries: [MindGramListEntry] = []
        for (index, toggle) in profileToggles.enumerated() {
            entries.append(.toggle(id: Int32(index), section: section, title: strings.toggleTitle(toggle), info: strings.toggleInfo(toggle), value: MindGramSettings.isOn(toggle)))
        }
        entries.append(.footer(id: 100, section: section, text: strings.profileFooter))
        return entries
    })
}
