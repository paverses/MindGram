import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import SwiftSignalKit
import ContextUI
import TelegramCore
import AvatarNode
import AsyncDisplayKit
import ComponentFlow
import ComponentDisplayAdapters
import EmojiStatusComponent
import SettingsUI

extension PeerInfoScreenNode {
    func accountContextMenuItems(context: AccountContext, visibleIds: [Int64] = [], logout: @escaping () -> Void) -> Signal<[ContextMenuItem], NoError> {
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        let isRussian = ["ru", "uk", "be"].contains(where: { strings.baseLanguageCode.hasPrefix($0) })
        let accountId = context.account.id.int64
        return context.engine.messages.unreadChatListPeerIds(groupId: .root, filterPredicate: nil)
        |> map { unreadChatListPeerIds -> [ContextMenuItem] in
            var items: [ContextMenuItem] = []
            
            if !unreadChatListPeerIds.isEmpty {
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAllAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    let _ = (context.engine.messages.markAllChatsAsReadInteractively(items: [(groupId: .root, filterPredicate: nil)])
                    |> deliverOnMainQueue).startStandalone(completed: {
                        f(.default)
                    })
                })))
            }
            
            if visibleIds.count > 1, let index = visibleIds.firstIndex(of: accountId) {
                if index > 0 {
                    items.append(.action(ContextMenuActionItem(text: isRussian ? "Переместить выше" : "Move Up", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Expand"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                        f(.default)
                        MindGramAccounts.move(accountId, by: -1, currentIds: visibleIds)
                    })))
                }
                if index < visibleIds.count - 1 {
                    items.append(.action(ContextMenuActionItem(text: isRussian ? "Переместить ниже" : "Move Down", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Collapse"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                        f(.default)
                        MindGramAccounts.move(accountId, by: 1, currentIds: visibleIds)
                    })))
                }
            }
            if !visibleIds.isEmpty {
                items.append(.action(ContextMenuActionItem(text: isRussian ? "Скрыть" : "Hide", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Archive"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    f(.default)
                    MindGramAccounts.setHidden(accountId, true)
                })))
            }

            items.append(.action(ContextMenuActionItem(text: strings.Settings_Context_Logout, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                logout()
                f(.default)
            })))
            
            return items
        }
    }
    
    func accountContextMenu(id: AccountRecordId, node: ASDisplayNode, gesture: ContextGesture?) {
        var selectedAccount: Account?
        var visibleIds: [Int64] = []
        let _ = (self.accountsAndPeers.get()
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { accountsAndPeers in
            visibleIds = MindGramAccounts.sorted(accountsAndPeers.map { $0.0.account.id.int64 }.filter { !MindGramAccounts.isHidden($0) }, id: { $0 })
            for (account, _, _) in accountsAndPeers {
                if account.account.id == id {
                    selectedAccount = account.account
                    break
                }
            }
        })
        if let selectedAccount = selectedAccount {
            let accountContext = self.context.sharedContext.makeTempAccountContext(account: selectedAccount)
            let chatListController = accountContext.sharedContext.makeChatListController(context: accountContext, location: .chatList(groupId: EngineChatList.Group(.root)), controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                    
            let contextController = makeContextController(presentationData: self.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatListController, sourceNode: node)), items: accountContextMenuItems(context: accountContext, visibleIds: visibleIds, logout: { [weak self] in
                self?.logoutAccount(id: id)
            }) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
            self.controller?.presentInGlobalOverlay(contextController)
        } else {
            gesture?.cancel()
        }
    }

    func switchToAccount(id: AccountRecordId) {
        self.accountsAndPeers.set(.never())
        self.context.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
    }
    
    func logoutAccount(id: AccountRecordId) {
        let presentationData = self.presentationData
        self.logoutConfirmationDisposable.set(nil)
        self.logoutConfirmationDisposable.set((self.context.sharedContext.activeAccountContexts
        |> take(1)
        |> mapToSignal { primary, accounts, _ -> Signal<String, NoError> in
            let accountContext: AccountContext?
            if let primary, primary.account.id == id {
                accountContext = primary
            } else {
                accountContext = accounts.first(where: { $0.0 == id })?.1
            }
            guard let accountContext else { return .complete() }
            return logoutConfirmationText(context: accountContext, presentationData: presentationData)
        }
        |> deliverOnMainQueue).start(next: { [weak self] text in
            guard let self else { return }
            let controller = textAlertController(
                context: self.context,
                updatedPresentationData: self.controller?.updatedPresentationData,
                title: presentationData.strings.Settings_LogoutConfirmationTitle,
                text: text,
                actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    }),
                    TextAlertAction(type: .defaultDestructiveAction, title: presentationData.strings.Settings_Logout, action: { [weak self] in
                        if let strongSelf = self {
                            let _ = logoutFromAccount(id: id, accountManager: strongSelf.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).startStandalone()
                        }
                    })
                ],
                parseMarkdown: true
            )
            self.controller?.present(controller, in: .window(.root))
        }))
    }
}

final class PeerInfoControllerContextReferenceContentSource: ContextReferenceContentSource {
    let controller: ViewController
    let sourceView: UIView
    let insets: UIEdgeInsets
    let contentInsets: UIEdgeInsets
    
    init(controller: ViewController, sourceView: UIView, insets: UIEdgeInsets, contentInsets: UIEdgeInsets = UIEdgeInsets()) {
        self.controller = controller
        self.sourceView = sourceView
        self.insets = insets
        self.contentInsets = contentInsets
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds.inset(by: self.insets), insets: self.contentInsets)
    }
}

final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}

private func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}
