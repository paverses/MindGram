import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ContextUI
import PromptUI
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
            if case .user = peer {
                subItems.append(.action(ContextMenuActionItem(text: isRussian ? "Визуал" : "Visual", icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Customize"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    guard let self else {
                        return
                    }
                    c?.pushItems(items: .single(ContextController.Items(content: .list(self.mindGramVisualItems(peer: peer, backTitle: backTitle)))))
                })))
            }
            subItems.append(.action(ContextMenuActionItem(text: isRussian ? "Метка" : "Mark", icon: { theme in
                return generateTintedImage(image: MindGramMarks.image(.mind, size: 24.0), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                guard let self else {
                    return
                }
                c?.pushItems(items: .single(ContextController.Items(content: .list(self.mindGramMarkItems(peer: peer, backTitle: backTitle)))))
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

    func mindGramEditVisualUsername(peer: EnginePeer) {
        let isRussian = self.mindGramIsRussian
        let peerId = peer.id.toInt64()
        self.controller?.present(promptController(context: self.context, text: isRussian ? "Визуальный юзернейм" : "Visual Username", subtitle: isRussian ? "Видно только вам. Пусто — вернуть настоящий." : "Only you see it. Empty restores the real one.", value: MindGramVisualProfile.username(peerId: peerId) ?? peer.addressName ?? "", placeholder: "username", characterLimit: 64, apply: { value in
            guard let value else {
                return
            }
            MindGramVisualProfile.setUsername(peerId: peerId, value == peer.addressName ? nil : value)
        }), in: .window(.root))
    }

    func mindGramEditVisualAbout(peer: EnginePeer) {
        let isRussian = self.mindGramIsRussian
        let peerId = peer.id.toInt64()
        self.controller?.present(promptController(context: self.context, text: isRussian ? "Визуальное описание" : "Visual Description", subtitle: isRussian ? "Видно только вам. Пусто — вернуть настоящее." : "Only you see it. Empty restores the real one.", value: MindGramVisualProfile.about(peerId: peerId) ?? "", placeholder: isRussian ? "Описание" : "Description", characterLimit: 1000, apply: { value in
            guard let value else {
                return
            }
            MindGramVisualProfile.setAbout(peerId: peerId, value)
        }), in: .window(.root))
    }

    func mindGramVisualItems(peer: EnginePeer, backTitle: String) -> [ContextMenuItem] {
        let isRussian = self.mindGramIsRussian
        let peerId = peer.id.id._internalGetInt64Value()
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: backTitle, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
        }, iconPosition: .left, action: { c, _ in
            c?.popItems()
        })))
        items.append(.separator)
        for field in [MindGramVisualField.phone, .stars, .gram, .ratingLevel, .ratingPoints, .ratingNext] {
            items.append(.action(ContextMenuActionItem(text: field.title(isRussian: isRussian), icon: { _ in
                return nil
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)
                guard let self else {
                    return
                }
                self.controller?.present(mindGramVisualPromptController(context: self.context, peerId: peerId, field: field), in: .window(.root))
            })))
        }
        return items
    }

    func mindGramMarkItems(peer: EnginePeer, backTitle: String) -> [ContextMenuItem] {
        let isRussian = self.mindGramIsRussian
        let peerId = peer.id.id._internalGetInt64Value()
        let current = MindGramMarks.storedMark(peerId: peerId)
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: backTitle, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
        }, iconPosition: .left, action: { c, _ in
            c?.popItems()
        })))
        items.append(.separator)
        let options: [MindGramMarks.Kind?] = [nil] + MindGramMarks.Kind.manualCases.map { Optional($0) }
        for option in options {
            let title = option?.title ?? (isRussian ? "Без метки" : "No Mark")
            items.append(.action(ContextMenuActionItem(text: title, icon: { theme in
                if option == current {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }
                if let option {
                    return generateTintedImage(image: MindGramMarks.image(option, size: 24.0), color: theme.contextMenu.primaryColor)
                }
                return nil
            }, action: { _, f in
                f(.default)
                MindGramMarks.setMark(peerId: peerId, option)
            })))
        }
        return items
    }
}
