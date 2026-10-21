import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ItemListUI
import MindGramCore

/// A settings row with a drawn preview of what a screen's switches do, like the chat preview of Liquid Glass.
/// `build` makes the picture for the row's size; it is rebuilt when `revision`, the theme or the size changes.
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

/// The drawn previews. Each is a small mock of the real screen with the current MindGram settings applied.
enum MindGramPreviews {
    // MARK: Building blocks

    private static func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.sizeToFit()
        return label
    }

    private static func symbol(_ name: String, size: CGFloat, color: UIColor) -> UIImageView {
        let view = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)))
        view.tintColor = color
        view.sizeToFit()
        return view
    }

    private static func chatBackground(size: CGSize, isDark: Bool) -> UIView {
        let view = UIView(frame: CGRect(origin: .zero, size: size))
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = isDark ? [UIColor(rgb: 0x1b2a3a).cgColor, UIColor(rgb: 0x0f1720).cgColor] : [UIColor(rgb: 0xd6e7c4).cgColor, UIColor(rgb: 0xa9cf9b).cgColor]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        view.layer.addSublayer(gradient)
        return view
    }

    /// A message bubble; `trailing` is drawn after the text in the corner, like the time.
    private static func bubble(text: String, outgoing: Bool, isDark: Bool, maxWidth: CGFloat, trailing: NSAttributedString) -> UIView {
        let background = outgoing ? (isDark ? UIColor(rgb: 0x2b5278) : UIColor(rgb: 0xe1ffc7)) : (isDark ? UIColor(rgb: 0x182533) : .white)
        let textColor: UIColor = isDark ? .white : .black
        let view = UIView()
        view.backgroundColor = background
        view.layer.cornerRadius = 17.0
        view.layer.cornerCurve = .continuous
        let textLabel = UILabel()
        textLabel.numberOfLines = 0
        textLabel.text = text
        textLabel.font = UIFont.systemFont(ofSize: 15.0)
        textLabel.textColor = textColor
        let meta = UILabel()
        meta.attributedText = trailing
        meta.sizeToFit()
        let textSize = textLabel.sizeThatFits(CGSize(width: maxWidth - 24.0 - meta.bounds.width - 6.0, height: 200.0))
        textLabel.frame = CGRect(x: 12.0, y: 7.0, width: textSize.width, height: textSize.height)
        let width = 12.0 + textSize.width + 6.0 + meta.bounds.width + 10.0
        let height = max(34.0, textSize.height + 14.0)
        meta.frame = CGRect(x: width - meta.bounds.width - 10.0, y: height - meta.bounds.height - 5.0, width: meta.bounds.width, height: meta.bounds.height)
        view.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        view.addSubview(textLabel)
        view.addSubview(meta)
        return view
    }

    private static func time(_ text: String, isDark: Bool, outgoing: Bool) -> NSAttributedString {
        let color: UIColor = outgoing ? (isDark ? UIColor(white: 1.0, alpha: 0.6) : UIColor(rgb: 0x3fa34d)) : UIColor(white: 0.5, alpha: 1.0)
        return NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 11.0), .foregroundColor: color])
    }

    private static func glassPanel(frame: CGRect, cornerRadius: CGFloat, isDark: Bool) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: isDark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
        view.frame = frame
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }

    // MARK: Screens

    /// Оформление → Эксперименты: the message menu with the filled Select / Copy / Delete row and larger reactions.
    static func experiments(size: CGSize, isDark: Bool) -> UIView {
        let root = self.chatBackground(size: size, isDark: isDark)
        let textColor: UIColor = isDark ? .white : .black
        let larger = MindGramSettings.isOn(.largerReactions)
        let reactionSize: CGFloat = larger ? 30.0 : 23.0
        let reactions = self.glassPanel(frame: CGRect(x: 16.0, y: 14.0, width: min(size.width - 32.0, larger ? 300.0 : 260.0), height: reactionSize + 18.0), cornerRadius: (reactionSize + 18.0) / 2.0, isDark: isDark)
        var x: CGFloat = 12.0
        for emoji in ["❤️", "👍", "🔥", "🥰", "👏", "😁"] {
            let item = self.label(emoji, size: reactionSize * 0.82, color: textColor)
            item.frame.origin = CGPoint(x: x, y: (reactions.bounds.height - item.bounds.height) / 2.0)
            if item.frame.maxX > reactions.bounds.width - 8.0 {
                break
            }
            reactions.contentView.addSubview(item)
            x += reactionSize + 12.0
        }
        root.addSubview(reactions)

        let bubble = self.bubble(text: "Привет! Как дела? 👋", outgoing: false, isDark: isDark, maxWidth: size.width - 60.0, trailing: self.time("12:43", isDark: isDark, outgoing: false))
        bubble.frame.origin = CGPoint(x: 16.0, y: reactions.frame.maxY + 8.0)
        root.addSubview(bubble)

        let menu = self.glassPanel(frame: CGRect(x: 16.0, y: bubble.frame.maxY + 8.0, width: min(250.0, size.width - 32.0), height: size.height - bubble.frame.maxY - 20.0), cornerRadius: 18.0, isDark: isDark)
        if MindGramSettings.isOn(.quickActionsMenu) {
            let titles: [(String, String, UIColor)] = [("checkmark.circle.fill", "Выбрать", textColor), ("doc.on.doc.fill", "Копировать", textColor), ("trash.fill", "Удалить", .systemRed)]
            let width = menu.bounds.width / 3.0
            for (index, item) in titles.enumerated() {
                let icon = self.symbol(item.0, size: 17.0, color: item.2)
                icon.center = CGPoint(x: width * (CGFloat(index) + 0.5), y: 22.0)
                menu.contentView.addSubview(icon)
                let title = self.label(item.1, size: 11.0, color: item.2)
                title.center = CGPoint(x: width * (CGFloat(index) + 0.5), y: 44.0)
                menu.contentView.addSubview(title)
            }
        }
        let rowsTop: CGFloat = MindGramSettings.isOn(.quickActionsMenu) ? 60.0 : 8.0
        for (index, item) in [("arrowshape.turn.up.left", "Ответить"), ("pin", "Закрепить"), ("arrowshape.turn.up.right", "Переслать")].enumerated() {
            let y = rowsTop + CGFloat(index) * 32.0
            if y + 24.0 > menu.bounds.height {
                break
            }
            let icon = self.symbol(item.0, size: 14.0, color: textColor)
            icon.center = CGPoint(x: 24.0, y: y + 12.0)
            menu.contentView.addSubview(icon)
            let title = self.label(item.1, size: 15.0, color: textColor)
            title.frame.origin = CGPoint(x: 46.0, y: y + 12.0 - title.bounds.height / 2.0)
            menu.contentView.addSubview(title)
        }
        root.addSubview(menu)
        if !MindGramSettings.isOn(.noContextBlur) {
            // The blurred chat behind the menu.
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: isDark ? .dark : .light))
            blur.frame = CGRect(x: size.width - 90.0, y: 0.0, width: 90.0, height: size.height)
            blur.alpha = 0.8
            root.addSubview(blur)
        }
        return root
    }

    /// Удалённые сообщения: a deleted bubble with the mark in the chosen colour, size and opacity.
    static func deleted(size: CGSize, isDark: Bool, isRussian: Bool) -> UIView {
        let root = self.chatBackground(size: size, isDark: isDark)
        var markColor = UIColor.systemRed
        if let parsed = MindGramDeleted.parsedMarkColor() {
            markColor = UIColor(red: CGFloat(parsed.red), green: CGFloat(parsed.green), blue: CGFloat(parsed.blue), alpha: 1.0)
        }
        let scale = CGFloat(MindGramDeleted.markScalePercent) / 100.0
        let prefix = MindGramDeleted.timestampPrefix(isRussian: isRussian)
        let trailing = NSMutableAttributedString()
        if !prefix.isEmpty {
            trailing.append(NSAttributedString(string: prefix, attributes: [.font: UIFont.systemFont(ofSize: 11.0 * scale), .foregroundColor: markColor]))
        }
        trailing.append(self.time("12:40", isDark: isDark, outgoing: false))

        let first = self.bubble(text: isRussian ? "Это сообщение удалили, но MindGram его сохранил" : "This message was deleted, but MindGram kept it", outgoing: false, isDark: isDark, maxWidth: size.width - 60.0, trailing: trailing)
        first.frame.origin = CGPoint(x: 16.0, y: 18.0)
        first.alpha = CGFloat(MindGramDeleted.opacityPercent) / 100.0
        root.addSubview(first)

        let second = self.bubble(text: isRussian ? "Обычное сообщение" : "A regular message", outgoing: true, isDark: isDark, maxWidth: size.width - 60.0, trailing: self.time("12:41 ✓✓", isDark: isDark, outgoing: true))
        second.frame.origin = CGPoint(x: size.width - second.bounds.width - 16.0, y: first.frame.maxY + 10.0)
        root.addSubview(second)
        return root
    }

    /// Быстрые фразы: the message field with a trigger typed and the list of phrases above it.
    static func phrases(size: CGSize, isDark: Bool, isRussian: Bool) -> UIView {
        let root = self.chatBackground(size: size, isDark: isDark)
        let textColor: UIColor = isDark ? .white : .black
        let trigger = MindGramPhrases.triggerList.last ?? "/"
        var phrases = MindGramPhrases.phrases.prefix(2).map { ($0.name, $0.text.replacingOccurrences(of: "\n", with: " ")) }
        if phrases.isEmpty {
            phrases = isRussian ? [("адрес", "ул. Пушкина, д. 10, кв. 5"), ("привет", "Привет, {имя}! Сегодня {дата}")] : [("address", "10 Baker Street, London"), ("hi", "Hi {name}! Today is {date}")]
        }
        let list = self.glassPanel(frame: CGRect(x: 12.0, y: 14.0, width: size.width - 24.0, height: CGFloat(phrases.count) * 46.0), cornerRadius: 16.0, isDark: isDark)
        for (index, phrase) in phrases.enumerated() {
            let title = self.label(trigger + phrase.0, size: 15.0, weight: .semibold, color: textColor)
            title.frame.origin = CGPoint(x: 14.0, y: CGFloat(index) * 46.0 + 5.0)
            list.contentView.addSubview(title)
            let detail = self.label(phrase.1, size: 13.0, color: .secondaryLabel)
            detail.frame = CGRect(x: 14.0, y: title.frame.maxY + 1.0, width: list.bounds.width - 28.0, height: detail.bounds.height)
            list.contentView.addSubview(detail)
        }
        root.addSubview(list)
        let input = self.glassPanel(frame: CGRect(x: 12.0, y: list.frame.maxY + 10.0, width: size.width - 24.0, height: 40.0), cornerRadius: 20.0, isDark: isDark)
        let typed = self.label(trigger + String(phrases[0].0.prefix(2)), size: 16.0, color: textColor)
        typed.frame.origin = CGPoint(x: 16.0, y: (40.0 - typed.bounds.height) / 2.0)
        input.contentView.addSubview(typed)
        root.addSubview(input)
        return root
    }

    /// Режим призрака: a chat list row that stays unread, with the ghost in the corner.
    static func ghost(size: CGSize, isDark: Bool, isRussian: Bool) -> UIView {
        let root = UIView(frame: CGRect(origin: .zero, size: size))
        root.backgroundColor = isDark ? UIColor(rgb: 0x101010) : UIColor(rgb: 0xf2f2f7)
        let textColor: UIColor = isDark ? .white : .black
        let ghost = self.symbol("eye.slash.fill", size: 26.0, color: UIColor(rgb: 0x8e8e93))
        ghost.center = CGPoint(x: size.width - 34.0, y: 28.0)
        root.addSubview(ghost)
        let rows: [(String, String, String)] = isRussian ? [("Анна", "Ты видел?", "2"), ("Рабочий чат", "Завтра в 10", "5")] : [("Anna", "Did you see it?", "2"), ("Work", "Tomorrow at 10", "5")]
        for (index, row) in rows.enumerated() {
            let y = 56.0 + CGFloat(index) * 58.0
            let avatar = UIView(frame: CGRect(x: 16.0, y: y, width: 44.0, height: 44.0))
            avatar.backgroundColor = index == 0 ? UIColor(rgb: 0xe17076) : UIColor(rgb: 0x65aadd)
            avatar.layer.cornerRadius = 22.0
            root.addSubview(avatar)
            let name = self.label(row.0, size: 16.0, weight: .semibold, color: textColor)
            name.frame.origin = CGPoint(x: 72.0, y: y + 2.0)
            root.addSubview(name)
            let text = self.label(row.1, size: 14.0, color: .secondaryLabel)
            text.frame.origin = CGPoint(x: 72.0, y: name.frame.maxY + 2.0)
            root.addSubview(text)
            let badge = self.label(row.2, size: 13.0, weight: .semibold, color: .white)
            let badgeView = UIView(frame: CGRect(x: size.width - 40.0, y: y + 12.0, width: 24.0, height: 20.0))
            badgeView.backgroundColor = UIColor(rgb: 0x3a8ee6)
            badgeView.layer.cornerRadius = 10.0
            badge.center = CGPoint(x: 12.0, y: 10.0)
            badgeView.addSubview(badge)
            root.addSubview(badgeView)
        }
        let caption = self.label(isRussian ? "Прочитано, но собеседник видит «не прочитано»" : "Read, but they see \"unread\"", size: 12.0, color: .secondaryLabel)
        caption.frame.origin = CGPoint(x: 16.0, y: 12.0)
        root.addSubview(caption)
        return root
    }

    /// Чат и перевод: a translated voice transcription and a bleeped word.
    static func chatTools(size: CGSize, isDark: Bool, isRussian: Bool) -> UIView {
        let root = self.chatBackground(size: size, isDark: isDark)
        let first = self.bubble(text: isRussian ? "🎤 0:04 · «Hello! See you tomorrow» → «Привет! До завтра»" : "🎤 0:04 · «Привет! До завтра» → «Hello! See you tomorrow»", outgoing: false, isDark: isDark, maxWidth: size.width - 50.0, trailing: self.time("18:02", isDark: isDark, outgoing: false))
        first.frame.origin = CGPoint(x: 16.0, y: 16.0)
        root.addSubview(first)
        let second = self.bubble(text: isRussian ? "🎤 0:03 · «Да ну, ***, не может быть» 🔇" : "🎤 0:03 · «No ***, no way» 🔇", outgoing: true, isDark: isDark, maxWidth: size.width - 50.0, trailing: self.time("18:03 ✓✓", isDark: isDark, outgoing: true))
        second.frame.origin = CGPoint(x: size.width - second.bounds.width - 16.0, y: first.frame.maxY + 10.0)
        root.addSubview(second)
        return root
    }

    /// Кружки: the round video with the effects row under it.
    static func circles(size: CGSize, isDark: Bool) -> UIView {
        let root = UIView(frame: CGRect(origin: .zero, size: size))
        root.backgroundColor = .black
        let diameter = min(size.height - 70.0, 130.0)
        let circle = UIView(frame: CGRect(x: (size.width - diameter) / 2.0, y: 12.0, width: diameter, height: diameter))
        let gradient = CAGradientLayer()
        gradient.frame = circle.bounds
        gradient.colors = [UIColor(rgb: 0x5b6cff).cgColor, UIColor(rgb: 0xff6fb1).cgColor]
        gradient.cornerRadius = diameter / 2.0
        circle.layer.addSublayer(gradient)
        let face = self.label("😎", size: diameter * 0.45, color: .white)
        face.center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)
        circle.addSubview(face)
        root.addSubview(circle)
        var x: CGFloat = 12.0
        for (index, emoji) in ["⭕️", "🌫", "😎", "👑", "😇", "😈", "🎞", "🔥"].enumerated() {
            let item = UIView(frame: CGRect(x: x, y: circle.frame.maxY + 12.0, width: 40.0, height: 40.0))
            item.backgroundColor = UIColor(white: 1.0, alpha: index == 2 ? 0.35 : 0.14)
            item.layer.cornerRadius = 20.0
            let icon = self.label(emoji, size: 20.0, color: .white)
            icon.center = CGPoint(x: 20.0, y: 20.0)
            item.addSubview(icon)
            root.addSubview(item)
            x += 48.0
            if x > size.width - 40.0 {
                break
            }
        }
        return root
    }

    /// Обои профиля: the wallpaper behind a mock profile.
    static func profileWallpaper(size: CGSize, isDark: Bool) -> UIView {
        let root = UIView(frame: CGRect(origin: .zero, size: size))
        root.backgroundColor = isDark ? .black : UIColor(rgb: 0xf2f2f7)
        root.clipsToBounds = true
        if MindGramProfileWallpaper.isEnabled, MindGramProfileWallpaper.image != nil {
            let wallpaper = MindGramProfileWallpaperView(frame: root.bounds)
            wallpaper.updateFromSettings()
            root.addSubview(wallpaper)
        }
        let textColor: UIColor = (MindGramProfileWallpaper.isEnabled || isDark) ? .white : .black
        let avatar = UIView(frame: CGRect(x: (size.width - 64.0) / 2.0, y: 16.0, width: 64.0, height: 64.0))
        avatar.backgroundColor = UIColor(rgb: 0xa695e7)
        avatar.layer.cornerRadius = 32.0
        let initial = self.label("M", size: 28.0, weight: .semibold, color: .white)
        initial.center = CGPoint(x: 32.0, y: 32.0)
        avatar.addSubview(initial)
        root.addSubview(avatar)
        let name = self.label("MindGram", size: 20.0, weight: .semibold, color: textColor)
        name.center = CGPoint(x: size.width / 2.0, y: avatar.frame.maxY + 18.0)
        root.addSubview(name)
        let buttonsY = name.frame.maxY + 10.0
        let buttonSize: CGFloat = 40.0
        let totalWidth = buttonSize * 4.0 + 12.0 * 3.0
        for (index, symbolName) in ["phone.fill", "bell.fill", "magnifyingglass", "ellipsis"].enumerated() {
            let button = self.glassPanel(frame: CGRect(x: (size.width - totalWidth) / 2.0 + CGFloat(index) * (buttonSize + 12.0), y: buttonsY, width: buttonSize, height: buttonSize), cornerRadius: buttonSize / 2.0, isDark: true)
            let icon = self.symbol(symbolName, size: 14.0, color: .white)
            icon.center = CGPoint(x: buttonSize / 2.0, y: buttonSize / 2.0)
            button.contentView.addSubview(icon)
            root.addSubview(button)
        }
        let rows = self.glassPanel(frame: CGRect(x: 16.0, y: buttonsY + buttonSize + 12.0, width: size.width - 32.0, height: 44.0), cornerRadius: 18.0, isDark: isDark || MindGramProfileWallpaper.isEnabled)
        let username = self.label("@mindgram", size: 15.0, color: textColor)
        username.frame.origin = CGPoint(x: 16.0, y: (44.0 - username.bounds.height) / 2.0)
        rows.contentView.addSubview(username)
        root.addSubview(rows)
        return root
    }
}
