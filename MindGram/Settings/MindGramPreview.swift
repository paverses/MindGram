import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ItemListUI
import AccountContext
import SettingsUI
import MindGramCore

/// A settings row that hosts a view built for the row's size (rebuilt when `revision`, the theme or the size
/// changes). Used for previews that show real content, such as the profile wallpaper itself.
func mindGramPreviewItem(presentationData: ItemListPresentationData, sectionId: ItemListSectionId, height: CGFloat, revision: Int, build: @escaping (CGSize, Bool) -> UIView) -> ListViewItem {
    return MindGramComponentItem(theme: presentationData.theme, height: height, component: AnyComponent(MindGramPreviewComponent(revision: revision, isDark: presentationData.theme.overallDarkAppearance, build: build)), sectionId: sectionId)
}

final class MindGramPreviewComponent: Component {
    let revision: Int
    let isDark: Bool
    let build: (CGSize, Bool) -> UIView

    init(revision: Int, isDark: Bool, build: @escaping (CGSize, Bool) -> UIView) {
        self.revision = revision
        self.isDark = isDark
        self.build = build
    }

    static func ==(lhs: MindGramPreviewComponent, rhs: MindGramPreviewComponent) -> Bool {
        return lhs.revision == rhs.revision && lhs.isDark == rhs.isDark
    }

    final class View: UIView {
        private var content: UIView?
        private var key: (revision: Int, isDark: Bool, size: CGSize)?

        func update(component: MindGramPreviewComponent, availableSize: CGSize) -> CGSize {
            if let key = self.key, key.revision == component.revision, key.isDark == component.isDark, key.size == availableSize {
                return availableSize
            }
            self.key = (component.revision, component.isDark, availableSize)
            self.content?.removeFromSuperview()
            let content = component.build(availableSize, component.isDark)
            content.frame = CGRect(origin: .zero, size: availableSize)
            content.isUserInteractionEnabled = false
            self.addSubview(content)
            self.content = content
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

/// The previews of MindGram's screens. Chat features show real Telegram message bubbles on the chat wallpaper,
/// like the Liquid Glass and Appearance previews, with the screen's settings applied to them.
enum MindGramPreviews {
    private static func chat(context: AccountContext, sectionId: ItemListSectionId, messages: [(outgoing: Bool, reply: (String, String)?, text: String)]?) -> ListViewItem {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        return mindGramChatPreviewItem(context: context, presentationData: presentationData, sectionId: sectionId, messages: messages)
    }

    private static func isRussian(_ context: AccountContext) -> Bool {
        return MindGramStrings(context.sharedContext.currentPresentationData.with { $0 }).isRussian
    }

    /// Оформление: Telegram's own sample conversation with the current design.
    static func appearance(context: AccountContext, sectionId: ItemListSectionId) -> ListViewItem {
        return self.chat(context: context, sectionId: sectionId, messages: nil)
    }

    /// Сообщения: your message in the chosen «шрифт».
    static func messages(context: AccountContext, sectionId: ItemListSectionId) -> ListViewItem {
        let ru = self.isRussian(context)
        let sample = ru ? "Как отправлять оффер?" : "How do I send an offer?"
        return self.chat(context: context, sectionId: sectionId, messages: [
            (false, nil, ru ? "Напиши, как будешь готов 👋" : "Text me when you're ready 👋"),
            (true, nil, MindGramTextStyle.apply(font: MindGramTextStyle.font, to: sample))
        ])
    }

    /// Удалённые: the incoming message is shown as kept-deleted — the trash mark in its colour and size, and the
    /// message's opacity — exactly as in a chat.
    static func deleted(context: AccountContext, sectionId: ItemListSectionId) -> ListViewItem {
        MindGramDeleted.addPreviewKey(mindGramChatPreviewIncomingKey())
        let ru = self.isRussian(context)
        return self.chat(context: context, sectionId: sectionId, messages: [
            (false, nil, ru ? "Это сообщение удалили, но MindGram его сохранил" : "This message was deleted, but MindGram kept it"),
            (true, nil, ru ? "А это обычное сообщение" : "And this one is a regular message")
        ])
    }

    /// Быстрые фразы: a phrase as it is sent — the first saved one, with {имя}/{дата}/{время} filled in.
    static func phrases(context: AccountContext, sectionId: ItemListSectionId) -> ListViewItem {
        let ru = self.isRussian(context)
        var text = ru ? "Привет, Анна! Встречаемся сегодня в 18:00 у входа 👋" : "Hi Anna! Let's meet today at 6 pm at the entrance 👋"
        if let phrase = MindGramPhrases.phrases.first {
            text = MindGramPhrases.expand(phrase, peerName: ru ? "Анна" : "Anna").text
        }
        return self.chat(context: context, sectionId: sectionId, messages: [
            (false, nil, ru ? "Где встречаемся?" : "Where do we meet?"),
            (true, nil, text)
        ])
    }

    /// Режим призрака: you read and type, they see neither.
    static func ghost(context: AccountContext, sectionId: ItemListSectionId) -> ListViewItem {
        let ru = self.isRussian(context)
        return self.chat(context: context, sectionId: sectionId, messages: [
            (false, nil, ru ? "Ты где? Почему не читаешь? 🤔" : "Where are you? Why aren't you reading? 🤔"),
            (true, nil, ru ? "Читаю 👻 — но для тебя сообщение всё ещё не прочитано" : "I am 👻 — but to you it still looks unread")
        ])
    }

    /// Чат и перевод: a translated message with the original quoted above it.
    static func chatTools(context: AccountContext, sectionId: ItemListSectionId) -> ListViewItem {
        let ru = self.isRussian(context)
        return self.chat(context: context, sectionId: sectionId, messages: [
            (false, (ru ? "Оригинал" : "Original", ru ? "Hello! See you tomorrow at the station" : "Привет! До завтра на вокзале"), ru ? "Привет! До завтра на вокзале 🚉" : "Hello! See you tomorrow at the station 🚉"),
            (true, nil, ru ? "Договорились!" : "Deal!")
        ])
    }

    /// Голосовые и файлы: a transcribed voice message with a bleeped word, and a long text sent as a file.
    static func media(context: AccountContext, sectionId: ItemListSectionId) -> ListViewItem {
        let ru = self.isRussian(context)
        return self.chat(context: context, sectionId: sectionId, messages: [
            (false, (ru ? "Голосовое · 0:04" : "Voice · 0:04", ru ? "Расшифровано на iPhone" : "Transcribed on the iPhone"), ru ? "Да ну, ***, не может быть 😄" : "No ***, no way 😄"),
            (true, nil, ru ? "📄 message.txt — длинный текст ушёл одним файлом" : "📄 message.txt — the long text went as one file")
        ])
    }

    /// Обои профиля: the wallpaper itself, with the chosen blur and dimming.
    static func profileWallpaper(size: CGSize, isDark: Bool) -> UIView {
        let root = UIView(frame: CGRect(origin: .zero, size: size))
        root.backgroundColor = isDark ? .black : UIColor(rgb: 0xf2f2f7)
        root.clipsToBounds = true
        if MindGramProfileWallpaper.image != nil {
            let wallpaper = MindGramProfileWallpaperView(frame: root.bounds)
            wallpaper.updateFromSettings()
            wallpaper.alpha = MindGramProfileWallpaper.isEnabled ? 1.0 : 0.4
            root.addSubview(wallpaper)
        } else {
            let label = UILabel()
            label.text = (Locale.preferredLanguages.first ?? "").hasPrefix("ru") ? "Обои не выбраны" : "No wallpaper yet"
            label.font = UIFont.systemFont(ofSize: 15.0)
            label.textColor = .secondaryLabel
            label.sizeToFit()
            label.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            root.addSubview(label)
        }
        return root
    }
}
