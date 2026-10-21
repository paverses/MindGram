import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import AsyncDisplayKit
import ContextUI
import UndoUI

extension PeerInfoScreenNode {
    func openUsernameContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let peer = self.data?.peer else {
            return
        }
        guard let username = peer.addressName else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            UIPasteboard.general.string = "@\(username)"
            
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.Conversation_UsernameCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_UsernameActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    self.openSettings(section: .username)
                }
            })))
        }
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_UsernameActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
            c?.dismiss {
                copyAction()
            }
        })))

        // MindGram: «Визуальный юзернейм» — what this phone shows instead of the real @username.
        let isRussian = ["ru", "uk", "be"].contains(where: { self.presentationData.strings.baseLanguageCode.hasPrefix($0) })
        let hasVisual = MindGramVisualProfile.username(peerId: peer.id.toInt64()) != nil
        items.append(.action(ContextMenuActionItem(text: isRussian ? "Визуальный юзернейм" : "Visual Username", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Mention"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                self?.mindGramEditVisualUsername(peer: peer)
            }
        })))
        if hasVisual {
            items.append(.action(ContextMenuActionItem(text: isRussian ? "Показать настоящий" : "Show the Real One", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                c?.dismiss {
                    MindGramVisualProfile.setUsername(peerId: peer.id.toInt64(), nil)
                }
            })))
        }

        let actions = ContextController.Items(content: .list(items))
        
        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
}
