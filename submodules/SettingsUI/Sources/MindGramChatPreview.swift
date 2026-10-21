import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

/// MindGram: the Appearance screen's chat preview (real message bubbles on the chat wallpaper) for MindGram's
/// settings screens. Without `messages` it shows Telegram's own sample pair.
public func mindGramChatPreviewItem(context: AccountContext, presentationData: PresentationData, sectionId: ItemListSectionId, messages: [(outgoing: Bool, reply: (String, String)?, text: String)]? = nil) -> ListViewItem {
    let strings = presentationData.strings
    let items: [ChatPreviewMessageItem]
    if let messages {
        items = messages.map { ChatPreviewMessageItem(outgoing: $0.outgoing, reply: $0.reply, text: $0.text, nameColor: .preset(.blue), backgroundEmojiId: nil) }
    } else {
        items = [
            ChatPreviewMessageItem(outgoing: false, reply: ("MindGram", strings.Appearance_PreviewReplyText), text: strings.Appearance_PreviewIncomingText, nameColor: .preset(.blue), backgroundEmojiId: nil),
            ChatPreviewMessageItem(outgoing: true, reply: nil, text: strings.Appearance_PreviewOutgoingText, nameColor: .preset(.blue), backgroundEmojiId: nil)
        ]
    }
    return ThemeSettingsChatPreviewItem(
        context: context,
        systemStyle: .glass,
        theme: presentationData.theme,
        componentTheme: presentationData.theme,
        strings: strings,
        sectionId: sectionId,
        fontSize: presentationData.chatFontSize,
        chatBubbleCorners: presentationData.chatBubbleCorners,
        wallpaper: presentationData.chatWallpaper,
        dateTimeFormat: presentationData.dateTimeFormat,
        nameDisplayOrder: presentationData.nameDisplayOrder,
        messageItems: items
    )
}

/// The key of the incoming message in that preview (ThemeSettingsChatPreviewItem gives it peer 1, id 1), so a
/// preview can show it as a kept deleted message.
public func mindGramChatPreviewIncomingKey() -> MindGramMessageKey {
    let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    return MindGramMessageKey(peerId: peerId.toInt64(), namespace: 0, id: 1)
}
