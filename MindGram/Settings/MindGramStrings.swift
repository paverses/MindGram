import Foundation
import TelegramPresentationData
import MindGramCore

/// MindGram's own texts. Russian for Russian, Ukrainian and Belarusian interfaces, English otherwise.
public struct MindGramStrings {
    public let isRussian: Bool

    public init(_ presentationData: PresentationData) {
        let languageCode = presentationData.strings.primaryComponent.languageCode.lowercased()
        self.isRussian = languageCode.hasPrefix("ru") || languageCode.hasPrefix("uk") || languageCode.hasPrefix("be")
    }

    func t(_ ru: String, _ en: String) -> String {
        return self.isRussian ? ru : en
    }

    var title: String { return "MindGram" }

    // Menu
    var appearance: String { return t("Оформление", "Appearance") }
    var profile: String { return t("Профиль", "Profile") }
    var tabs: String { return t("Вкладки", "Tabs") }
    var liquidGlass: String { return "Liquid Glass" }
    var menuSections: String { return t("Разделы меню", "Menu Sections") }
    var menuFooter: String { return t("Функции MindGram, которых нет в обычном Telegram.", "MindGram features that regular Telegram doesn't have.") }

    // Оформление
    var classicDesign: String { return t("Старый дизайн Telegram", "Classic Telegram Design") }
    var classicDesignInfo: String { return t("Без жидкого стекла", "Without liquid glass") }
    var classicDesignFooter: String { return t("Возвращает старый дизайн Telegram.", "Brings back the classic Telegram design.") }
    var betaText: String { return t("Это бета-функция. Она ещё в разработке и может работать нестабильно. Используй на свой страх и риск.", "This is a beta feature. It is still in development and may be unstable. Use it at your own risk.") }
    var classicConflictTitle: String { return t("Старый дизайн", "Classic Design") }
    var classicConflictText: String { return t("Жидкое стекло, размер навбара и эксперименты оформления будут выключены, пока включён старый дизайн.", "Liquid Glass, tab bar size and design experiments are turned off while the classic design is on.") }
    var restartTitle: String { return t("Нужен перезапуск", "Restart Required") }
    var restartText: String { return t("Дизайн сменится после перезапуска MindGram.", "The design changes after MindGram restarts.") }
    var restartAction: String { return t("Перезапуск", "Restart") }

    // Профиль
    func toggleTitle(_ toggle: MindGramToggle) -> String {
        switch toggle {
        case .showPeerId:
            return t("Отображать ID в профиле", "Show ID in Profile")
        case .showDatacenter:
            return t("Отображать DC в профиле", "Show DC in Profile")
        case .fullViewCounts:
            return t("Полные просмотры на постах", "Full View Counts")
        case .hidePhoneNumber:
            return t("Скрыть номер телефона", "Hide Phone Number")
        case .exactCreationDate:
            return t("Точная дата создания", "Exact Creation Date")
        case .approximateAccountAge:
            return t("Примерная дата регистрации", "Approximate Account Age")
        case .timestampSeconds:
            return t("Секунды во времени", "Seconds in Timestamps")
        case .approximateLastSeen:
            return t("Время у «был(а) недавно»", "Time for \"Last Seen Recently\"")
        case .hideContactsTab:
            return t("Скрыть вкладку «Контакты»", "Hide Contacts Tab")
        case .glassMessages:
            return t("Liquid Glass в сообщениях", "Liquid Glass Messages")
        case .glassProfile:
            return t("Liquid Glass в профиле", "Liquid Glass Profile")
        case .glassBotButtons:
            return t("Liquid Glass на кнопках", "Liquid Glass Buttons")
        case .plusAttachMenu:
            return t("«+» вместо скрепки", "\"+\" Instead of Paperclip")
        case .quickActionsMenu:
            return t("Новое меню сообщения", "New Message Menu")
        case .noContextBlur:
            return t("Без размытия при зажатии", "No Blur on Long Press")
        case .largerReactions:
            return t("Крупнее реакции", "Larger Reactions")
        case .roundProfileButtons:
            return t("Круглые кнопки в профиле", "Round Profile Buttons")
        case .squareProfileAvatar:
            return t("Квадратная аватарка", "Square Avatar")
        case .avatarBackdrop:
            return t("Фон из аватарки", "Avatar Backdrop")
        }
    }

    func toggleInfo(_ toggle: MindGramToggle) -> String {
        switch toggle {
        case .showPeerId:
            return t("ID аккаунта в любом профиле", "Account ID in every profile")
        case .showDatacenter:
            return t("Дата-центр аккаунта в профиле", "Account datacenter in profile")
        case .fullViewCounts:
            return t("27 456 вместо 27K", "27,456 instead of 27K")
        case .hidePhoneNumber:
            return t("Убирает номер из профилей", "Removes the number from profiles")
        case .exactCreationDate:
            return t("Когда создан канал или чат", "When a channel or chat was made")
        case .approximateAccountAge:
            return t("Возраст аккаунта по его ID", "Account age from its ID")
        case .timestampSeconds:
            return t("12:43:12 вместо 12:43", "12:43:12 instead of 12:43")
        case .approximateLastSeen:
            return t("Примерное время по активности", "Approximate time from activity")
        case .hideContactsTab:
            return t("Убирает контакты из навбара", "Removes Contacts from the tab bar")
        case .glassMessages:
            return t("Прозрачное стекло на пузырях", "Clear glass on message bubbles")
        case .glassProfile:
            return t("Стекло в профиле и настройках", "Glass in profiles and Settings")
        case .glassBotButtons:
            return t("Стекло на инлайн-кнопках ботов", "Glass on bot inline buttons")
        case .plusAttachMenu:
            return t("Стеклянное меню вложений", "Glass attachment menu")
        case .quickActionsMenu:
            return t("Выбрать, Скопировать, Удалить сверху", "Select, Copy, Delete on top")
        case .noContextBlur:
            return t("Чат вокруг сообщения не размыт", "The chat stays sharp")
        case .largerReactions:
            return t("Реакции над сообщением больше", "Bigger reactions above messages")
        case .roundProfileButtons:
            return t("Только иконки в больших кругах", "Call, Mute, Search as circles")
        case .squareProfileAvatar:
            return t("Сразу большое фото, без растягивания", "Large photo at once, no pull-down")
        case .avatarBackdrop:
            return t("Размытое фото за кнопками и списком", "Blurred photo behind buttons and rows")
        }
    }

    var profileFooter: String { return t("Дата регистрации примерная.", "The account age is approximate.") }

    // Вкладки
    var hideCallsTab: String { return t("Скрыть вкладку «Звонки»", "Hide Calls Tab") }
    var hideCallsTabInfo: String { return t("Убирает звонки из навбара", "Removes Calls from the tab bar") }
    var navbarHeight: String { return t("Высота навбара", "Tab Bar Height") }
    var navbarWidth: String { return t("Ширина навбара", "Tab Bar Width") }
    var navbarSizeHeader: String { return t("РАЗМЕР НАВБАРА", "TAB BAR SIZE") }
    var navbarSizeFooter: String { return t("От 50 до 150 %, по умолчанию 100 %.", "From 50 to 150%, 100% by default.") }
    var tabsHeader: String { return t("ВКЛАДКИ", "TABS") }

    // Liquid Glass
    var glassHeader: String { return t("ПРЕВЬЮ", "PREVIEW") }
    var glassFooter: String { return t("Стекло пропускает обои чата.", "The glass lets the wallpaper through.") }

    // Разделы меню
    func hideSection(_ name: String) -> String { return t("Скрыть «\(name)»", "Hide \"\(name)\"") }
    var hideSectionInfo: String { return t("Убирает пункт из настроек", "Removes the row from Settings") }
    var miniApps: String { return t("Мини-приложения", "Mini Apps") }
    var proxySponsor: String { return t("Канал спонсора прокси", "Proxy Sponsor Channel") }
    var proxySponsorInfo: String { return t("Убирает закреп от прокси", "Removes the proxy's pinned chat") }
    var menuSectionsFooter: String { return t("Пункт MindGram скрыть нельзя.", "The MindGram row can't be hidden.") }

    // Режим призрака
    var ghostMode: String { return t("Режим призрака", "Ghost Mode") }
    var ghostModeInfo: String { return t("Никто не видит вашу активность", "Nobody sees your activity") }
    var ghostWhatHeader: String { return t("ЧТО СКРЫВАТЬ", "WHAT TO HIDE") }
    func ghostTitle(_ option: MindGramGhost.Option) -> String {
        switch option {
        case .hideRead:
            return t("Скрыть прочтение", "Hide Read Receipts")
        case .hideOnline:
            return t("Скрыть онлайн", "Hide Online")
        case .hideTyping:
            return t("Скрыть «печатает»", "Hide Typing")
        case .hideMediaActivity:
            return t("Скрыть запись и отправку", "Hide Recording and Uploading")
        case .hideListening:
            return t("Скрыть прослушивание", "Hide Listening")
        case .anonymousStories:
            return t("Анонимный просмотр историй", "Anonymous Story Viewing")
        case .readAfterActions:
            return t("Прочитывать после действий", "Read After Actions")
        case .chatListButton:
            return t("Кнопка в списке чатов", "Button in Chat List")
        }
    }
    func ghostInfo(_ option: MindGramGhost.Option) -> String {
        switch option {
        case .hideRead:
            return t("Галочки не станут двойными", "Checkmarks stay single")
        case .hideOnline:
            return t("Всегда «был(а) недавно»", "Always \"last seen recently\"")
        case .hideTyping:
            return t("Набор текста и стикеров", "Typing and choosing stickers")
        case .hideMediaActivity:
            return t("Голосовые, кружки, фото, файлы", "Voice, round videos, photos, files")
        case .hideListening:
            return t("Голосовые и кружки не прослушаны", "Voice and round stay unplayed")
        case .anonymousStories:
            return t("Вас нет в списке зрителей", "You're not in the viewers list")
        case .readAfterActions:
            return t("Ответ, медиа или реакция читают чат", "A reply, media or reaction reads the chat")
        case .chatListButton:
            return t("Призрак вкл/выкл одним тапом", "Ghost on/off in one tap")
        }
    }
    var ghostWhereHeader: String { return t("ГДЕ РАБОТАЕТ", "WHERE IT WORKS") }
    var ghostOnlySelected: String { return t("Только в выбранных чатах", "Only in Selected Chats") }
    var ghostOnlySelectedInfo: String { return t("Призрак в отдельных чатах", "Ghost in specific chats") }
    var ghostChats: String { return t("Чаты с призраком", "Ghost Chats") }
    var ghostExceptions: String { return t("Исключения", "Exceptions") }
    var ghostWhereFooter: String { return t("Исключения видят ваш настоящий статус.", "Exceptions see your real status.") }
    var ghostFooter: String { return t("Прочитать чат вручную: зажмите его в списке чатов.", "To mark a chat read, press and hold it in the chat list.") }
    var ghostAddChat: String { return t("Добавить чат", "Add Chat") }
    var ghostChatsFooter: String { return t("Призрак работает только в этих чатах.", "Ghost mode works only in these chats.") }
    var ghostExceptionsFooter: String { return t("Эти чаты видят прочтение и набор текста.", "These chats see read receipts and typing.") }

    // Отчёт
    var report: String { return t("Отчёт", "Report") }
    var reportStatusHeader: String { return t("ЧТО РАБОТАЕТ", "WHAT WORKS") }
    var reportExportHeader: String { return t("ОТЧЁТ", "REPORT") }
    var reportCopy: String { return t("Скопировать отчёт", "Copy Report") }
    var reportSendToSaved: String { return t("Отправить в Избранное", "Send to Saved Messages") }
    var reportSendToChat: String { return t("Отправить в чат…", "Send to Chat…") }
    var reportClearErrors: String { return t("Очистить ошибки", "Clear Errors") }
    var reportFooter: String { return t("Отчёт уходит файлом .txt.", "The report is sent as a .txt file.") }
    var reportStatus: String { return t("Состояние", "Status") }
    var reportInWords: String { return t("СЛОВАМИ", "IN WORDS") }
    var reportInCode: String { return t("В КОДЕ", "IN CODE") }

    // Profile rows
    var peerIdLabel: String { return "ID" }
    var datacenterLabel: String { return "DC" }
    var mutualLabel: String { return t("Взаимные", "Mutual") }
    var yes: String { return t("Да", "Yes") }
    var no: String { return t("Нет", "No") }
    var createdLabel: String { return t("Создан", "Created") }
    var registeredLabel: String { return t("Регистрация", "Registered") }
    public var copiedText: String { return t("Скопировано", "Copied") }
}
