import Foundation
import UIKit
import Display
import TelegramPresentationData
import ItemListUI
import AccountContext

/// MindGram: the Appearance screen's chat preview (real message bubbles) for MindGram's Liquid Glass screen.
public func mindGramChatPreviewItem(context: AccountContext, presentationData: PresentationData, sectionId: ItemListSectionId) -> ListViewItem {
    let strings = presentationData.strings
    let messages = [
        ChatPreviewMessageItem(outgoing: false, reply: ("MindGram", strings.Appearance_PreviewReplyText), text: strings.Appearance_PreviewIncomingText, nameColor: .preset(.blue), backgroundEmojiId: nil),
        ChatPreviewMessageItem(outgoing: true, reply: nil, text: strings.Appearance_PreviewOutgoingText, nameColor: .preset(.blue), backgroundEmojiId: nil)
    ]
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
        messageItems: messages
    )
}
