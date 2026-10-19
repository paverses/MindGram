import Foundation
import TelegramPresentationData

/// MindGram's own texts. Russian for Russian, Ukrainian and Belarusian interfaces, English otherwise.
struct MindGramStrings {
    let isRussian: Bool

    init(_ presentationData: PresentationData) {
        let languageCode = presentationData.strings.primaryComponent.languageCode.lowercased()
        self.isRussian = languageCode.hasPrefix("ru") || languageCode.hasPrefix("uk") || languageCode.hasPrefix("be")
    }

    private func t(_ ru: String, _ en: String) -> String {
        return self.isRussian ? ru : en
    }

    var title: String { return "MindGram" }

    var appearance: String { return t("Оформление", "Appearance") }
    var tabs: String { return t("Вкладки", "Tabs") }
    var profile: String { return t("Профиль", "Profile") }
    var menuFooter: String { return t("Функции MindGram, которых нет в обычном Telegram.", "MindGram features that regular Telegram doesn't have.") }

    var classicDesign: String { return t("Старый дизайн Telegram", "Classic Telegram Design") }
    var classicDesignInfo: String { return t("Интерфейс без жидкого стекла", "Interface without liquid glass") }
    var classicDesignFooter: String { return t("Возвращает панели, вкладки и списки, как в Telegram 2019–2024. Применяется после перезапуска.", "Brings back the bars, tabs and lists of Telegram 2019–2024. Applies after a restart.") }

    var restartTitle: String { return t("Нужен перезапуск", "Restart Required") }
    var restartText: String { return t("Дизайн сменится после перезапуска MindGram.", "The design changes after MindGram restarts.") }
    var restartAction: String { return t("Перезапуск", "Restart") }

    var callsTab: String { return t("Вкладка «Звонки»", "Calls Tab") }
    var callsTabInfo: String { return t("Звонки в нижней панели", "Calls in the bottom bar") }

    var profileSoon: String { return t("Скоро здесь появятся функции профиля.", "Profile features are coming soon.") }
}
