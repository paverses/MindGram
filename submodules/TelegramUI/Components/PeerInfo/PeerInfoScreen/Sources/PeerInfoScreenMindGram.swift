import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ContextUI
import ComponentFlow
import AlertComponent
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
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    guard let self else {
                        return
                    }
                    self.controller?.push(mindGramVisualController(context: self.context, peerId: peer.id.id._internalGetInt64Value()))
                })))
            }
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

    func mindGramPresentMarkInfo(_ mark: MindGramMarks.Kind) {
        let isRussian = self.mindGramIsRussian
        let presentationData = self.presentationData
        let theme = presentationData.theme
        let textFont = UIFont.systemFont(ofSize: 15.0)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 2.0

        let header = NSMutableAttributedString()
        let iconAttachment = NSTextAttachment()
        iconAttachment.image = generateTintedImage(image: MindGramMarks.image(mark, size: 72.0), color: theme.list.itemAccentColor)
        iconAttachment.bounds = CGRect(x: 0.0, y: 0.0, width: 72.0, height: 72.0)
        header.append(NSAttributedString(attachment: iconAttachment))
        header.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: header.length))

        let body = NSMutableAttributedString()
        let attributes: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: theme.list.itemPrimaryTextColor, .paragraphStyle: paragraph]
        var actions: [AlertScreen.Action] = []
        if mark == .mind {
            body.append(NSAttributedString(string: isRussian ? "Статус бета-тестера MindGram. Его видят все, кто пользуется MindGram.\n\nДоступ к бета-тестированию — 100 " : "MindGram beta tester status. Everyone who uses MindGram sees it.\n\nBeta access costs 100 ", attributes: attributes))
            let starAttachment = NSTextAttachment()
            starAttachment.image = UIImage(bundleImageName: "Premium/Stars/BalanceStar")
            starAttachment.bounds = CGRect(x: 0.0, y: -3.0, width: 16.0, height: 16.0)
            body.append(NSAttributedString(attachment: starAttachment))
            body.append(NSAttributedString(string: isRussian ? " в месяц." : " a month.", attributes: attributes))
            actions.append(AlertScreen.Action(title: isRussian ? "Купить статус" : "Buy Status", type: .default, action: { [weak self] in
                guard let self, let navigationController = self.controller?.navigationController as? NavigationController else {
                    return
                }
                self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: "https://t.me/+bPjh0R3HNjAxNWI5", forceExternal: false, presentationData: self.presentationData, navigationController: navigationController, dismissInput: {})
            }))
            actions.append(AlertScreen.Action(title: presentationData.strings.Common_Close, action: {}))
        } else {
            body.append(NSAttributedString(string: mark.confirmedText(isRussian: isRussian), attributes: attributes))
            actions.append(AlertScreen.Action(title: presentationData.strings.Common_OK, type: .default, action: {}))
        }

        let content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
            AnyComponentWithIdentity(id: "icon", component: AnyComponent(AlertTextComponent(content: .attributed(header), alignment: .center))),
            AnyComponentWithIdentity(id: "title", component: AnyComponent(AlertTitleComponent(title: mark == .mind ? "Mind" : mark.title, alignment: .center))),
            AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(content: .attributed(body), alignment: .center)))
        ]
        let alert = AlertScreen(configuration: AlertScreen.Configuration(actionAlignment: .vertical), content: content, actions: actions, updatedPresentationData: (presentationData, self.context.sharedContext.presentationData))
        self.controller?.present(alert, in: .window(.root))
    }
}
