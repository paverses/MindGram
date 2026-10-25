import Foundation
import UIKit
import LocalAuthentication
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import MindGramCore

func mindGramOpenHiddenChats(context: AccountContext, push: @escaping (ViewController) -> Void) {
    let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
    let authContext = LAContext()
    var error: NSError?
    let showList = {
        let controller = mindGramPeersListController(context: context, title: strings.t("Скрытые чаты", "Hidden Chats"), footer: strings.t("Эти чаты не видны в списке чатов. Открываются только отсюда.", "These chats don't show in the chat list. They open only from here."), get: { MindGramHiddenChats.ids }, set: { MindGramHiddenChats.ids = $0 }, open: { peer in
            if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
            }
        })
        push(controller)
    }
    guard authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        showList()
        return
    }
    authContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: strings.t("Открыть скрытые чаты", "Open hidden chats")) { success, _ in
        if success {
            DispatchQueue.main.async {
                showList()
            }
        }
    }
}
