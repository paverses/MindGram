import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ContextUI
import MindGramUI

/// MindGram's items in a profile: the «MindGram» submenu at the end of the "…" menu, and the visual username and
/// description edited from it or from a long press on those rows.
extension PeerInfoScreenNode {
    private var mindGramIsRussian: Bool {
        return ["ru", "uk", "be"].contains(where: { self.presentationData.strings.baseLanguageCode.hasPrefix($0) })
    }

    /// «MindGram» with the logo; it opens a submenu with chat export and the visual username and description.
    func mindGramProfileMenuItem(peer: EnginePeer) -> ContextMenuItem {
        let isRussian = self.mindGramIsRussian
        let backTitle = self.presentationData.strings.Common_Back
        return .action(ContextMenuActionItem(text: "MindGram", icon: { theme in
            return MindGramLogo.image(size: CGSize(width: 24.0, height: 24.0), color: theme.contextMenu.primaryColor, inset: 3.5)
        }, action: { [weak self] c, _ in
            var subItems: [ContextMenuItem] = []
            subItems.append(.action(ContextMenuActionItem(text: backTitle, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
            }, iconPosition: .left, action: { c, _ in
                c?.popItems()
            })))
            subItems.append(.separator)
            subItems.append(.action(ContextMenuActionItem(text: isRussian ? "Экспорт чата" : "Export Chat", icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Download"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)
                self?.mindGramExportChat(peer: peer)
            })))
            subItems.append(.action(ContextMenuActionItem(text: isRussian ? "Визуальный юзернейм" : "Visual Username", icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Mention"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)
                self?.mindGramEditVisualUsername(peer: peer)
            })))
            subItems.append(.action(ContextMenuActionItem(text: isRussian ? "Визуальное описание" : "Visual Description", icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)
                self?.mindGramEditVisualAbout(peer: peer)
            })))
            subItems.append(.action(ContextMenuActionItem(text: isRussian ? "Скопировать ID" : "Copy ID", icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.default)
                UIPasteboard.general.string = "\(peer.id.id._internalGetInt64Value())"
            })))
            let _ = self
            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
        }))
    }

    func mindGramExportChat(peer: EnginePeer) {
        guard let controller = self.controller else {
            return
        }
        mindGramStartChatExport(context: self.context, peer: peer, present: { [weak controller] c in
            controller?.present(c, animated: true)
        }, presentInCurrent: { [weak controller] c in
            controller?.present(c, in: .current)
        })
    }

    /// «Визуальный юзернейм»: what this phone shows instead of the real @username; empty restores it.
    func mindGramEditVisualUsername(peer: EnginePeer) {
        let isRussian = self.mindGramIsRussian
        let peerId = peer.id.toInt64()
        let alert = UIAlertController(title: isRussian ? "Визуальный юзернейм" : "Visual Username", message: isRussian ? "Видно только вам: в профиле вместо настоящего. Пусто — вернуть настоящий." : "Only you see it, in place of the real one. Empty restores the real one.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = MindGramVisualProfile.username(peerId: peerId) ?? peer.addressName ?? ""
            field.placeholder = "username"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: isRussian ? "Отмена" : "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: isRussian ? "Сохранить" : "Save", style: .default, handler: { [weak alert] _ in
            let value = alert?.textFields?.first?.text ?? ""
            MindGramVisualProfile.setUsername(peerId: peerId, value == peer.addressName ? nil : value)
        }))
        self.controller?.present(alert, animated: true)
    }

    /// «Визуальное описание»: the bio or channel description this phone shows; empty restores the real one.
    func mindGramEditVisualAbout(peer: EnginePeer) {
        let isRussian = self.mindGramIsRussian
        let peerId = peer.id.toInt64()
        let alert = UIAlertController(title: isRussian ? "Визуальное описание" : "Visual Description", message: isRussian ? "Видно только вам. Пусто — вернуть настоящее." : "Only you see it. Empty restores the real one.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = MindGramVisualProfile.about(peerId: peerId) ?? ""
            field.placeholder = isRussian ? "Описание" : "Description"
        }
        alert.addAction(UIAlertAction(title: isRussian ? "Отмена" : "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: isRussian ? "Сохранить" : "Save", style: .default, handler: { [weak alert] _ in
            MindGramVisualProfile.setAbout(peerId: peerId, alert?.textFields?.first?.text)
        }))
        self.controller?.present(alert, animated: true)
    }
}
