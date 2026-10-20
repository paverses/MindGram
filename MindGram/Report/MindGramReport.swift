import Foundation
import UIKit
import Display
import TelegramCore
import AccountContext
import MindGramCore

/// One line of the «Отчёт» screen: a MindGram feature, whether it works, why, in words and in code terms.
struct MindGramCheck {
    let title: String
    let tone: MindGramStatusTone
    let status: String
    /// For people: what the feature does on this phone right now.
    let words: String
    /// For the developer: the exact values, Swift names and files behind the status.
    let code: [String]
}

/// Everything MindGram can find out about itself on this phone, built fresh every time.
enum MindGramReport {
    private static let works = "Работает"
    private static let off = "Выключено"
    private static let problem = "Ошибка"

    static func checks(context: AccountContext) -> [MindGramCheck] {
        return [
            self.buildCheck(),
            self.classicDesignCheck(),
            self.badgeCheck(context: context),
            self.ghostCheck(),
            self.appGroupCheck(),
            self.iconsCheck(),
            self.settingsCheck(),
            self.crashCheck(),
            self.errorsCheck()
        ]
    }

    private static var info: [String: Any] {
        return Bundle.main.infoDictionary ?? [:]
    }

    static var modelIdentifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        #endif
    }

    private static func buildCheck() -> MindGramCheck {
        let version = self.info["CFBundleShortVersionString"] as? String ?? "?"
        let build = self.info["CFBundleVersion"] as? String ?? "?"
        return MindGramCheck(
            title: "Сборка",
            tone: .ok,
            status: build,
            words: "MindGram \(version) (сборка \(build)) на \(self.modelIdentifier), iOS \(UIDevice.current.systemVersion).",
            code: [
                "CFBundleIdentifier = \(Bundle.main.bundleIdentifier ?? "nil")",
                "CFBundleShortVersionString = \(version)",
                "CFBundleVersion = \(build)",
                "DTSDKName = \(self.info["DTSDKName"] as? String ?? "nil")",
                "DTXcode = \(self.info["DTXcode"] as? String ?? "nil")",
                "UIDevice.systemVersion = \(UIDevice.current.systemVersion)",
                "utsname.machine = \(self.modelIdentifier)",
                "UIScreen.main.bounds = \(UIScreen.main.bounds.size), scale \(UIScreen.main.scale)"
            ]
        )
    }

    private static func classicDesignCheck() -> MindGramCheck {
        let keyValue = self.info["UIDesignRequiresCompatibility"] as? Bool
        let error = UserDefaults.standard.string(forKey: "MindGram.classicDesignError")
        var code = [
            "MindGramDesign.isClassic = \(MindGramDesign.isClassic) (этот запуск)",
            "MindGramDesign.isClassicOnNextLaunch = \(MindGramDesign.isClassicOnNextLaunch)",
            "Bundle.main.infoDictionary[\"UIDesignRequiresCompatibility\"] = \(keyValue.flatMap { "\($0)" } ?? "nil")",
            "DTSDKName = \(self.info["DTSDKName"] as? String ?? "nil") (ключ работает с SDK iOS 26, SDK iOS 27 его не читает)",
            "Где: Telegram/Telegram-iOS/main.m mindGramApplyClassicSystemDesign(), MindGram/Core/Sources/MindGramDesign.swift"
        ]
        if let error {
            code.append("Ошибка: \(error)")
        }
        if !MindGramDesign.isClassic {
            let pending = MindGramDesign.isClassicOnNextLaunch ? " Включится после перезапуска." : ""
            return MindGramCheck(title: "Старый дизайн", tone: .off, status: self.off, words: "Сейчас обычный дизайн с жидким стеклом.\(pending)", code: code)
        }
        if keyValue == true {
            return MindGramCheck(title: "Старый дизайн", tone: .ok, status: self.works, words: "Панели, вкладки и списки без стекла. Системные тумблеры и кнопки в виде до iOS 26: ключ UIDesignRequiresCompatibility включён до запуска интерфейса.", code: code)
        }
        return MindGramCheck(title: "Старый дизайн", tone: .problem, status: self.problem, words: "Панели и списки MindGram старые, но системные тумблеры и кнопки остаются новыми: iOS не дала включить ключ UIDesignRequiresCompatibility при запуске.", code: code)
    }

    private static func badgeCheck(context: AccountContext) -> MindGramCheck {
        let image = UIImage(bundleImageName: "Components/AppBadge")
        guard let window = context.sharedContext.mainWindow else {
            return MindGramCheck(title: "Бейдж в вырезе", tone: .problem, status: self.problem, words: "Не удалось найти главное окно приложения.", code: ["context.sharedContext.mainWindow = nil"])
        }
        let metrics = window.mindGramDeviceMetrics
        let badgeView = window.badgeView
        let code = [
            "Window1.deviceMetrics = .\(metrics)",
            "DeviceMetrics.hasTopNotch = \(metrics.hasTopNotch), hasDynamicIsland = \(metrics.hasDynamicIsland)",
            "DeviceMetrics.showAppBadge = \(metrics.showAppBadge), appBadgeTopOffset = \(metrics.appBadgeTopOffset)",
            "UIImage(bundleImageName: \"Components/AppBadge\") = \(image.flatMap { "\($0.size.width)x\($0.size.height) @\($0.scale)x" } ?? "nil")",
            "Window1.badgeView.isHidden = \(badgeView.isHidden), frame = \(badgeView.frame), superview = \(badgeView.superview == nil ? "nil" : "есть")",
            "Window1.forceBadgeHidden = \(window.mindGramBadgeForceHidden) (true, пока приложение не активно)",
            "Где: submodules/Display/Source/DeviceMetrics.swift showAppBadge/appBadgeTopOffset, WindowContent.swift updateBadgeVisibility()"
        ]
        if !metrics.showAppBadge {
            return MindGramCheck(title: "Бейдж в вырезе", tone: .off, status: "Нет выреза", words: "Telegram не нашёл у этого экрана чёлку или Dynamic Island (модель .\(metrics)), поэтому бейдж не показывается.", code: code)
        }
        if image == nil {
            return MindGramCheck(title: "Бейдж в вырезе", tone: .problem, status: self.problem, words: "Картинки бейджа нет в сборке: apply-branding.sh не скопировал AppBadge@3x.png.", code: code)
        }
        if badgeView.isHidden {
            return MindGramCheck(title: "Бейдж в вырезе", tone: .problem, status: "Скрыт", words: "Устройство подходит и картинка есть, но бейдж сейчас скрыт.", code: code)
        }
        return MindGramCheck(title: "Бейдж в вырезе", tone: .ok, status: self.works, words: "Надпись MindGram показана в \(metrics.hasDynamicIsland ? "Dynamic Island" : "чёлке"), \(Int(metrics.appBadgeTopOffset)) pt от верха.", code: code)
    }

    private static func ghostCheck() -> MindGramCheck {
        let counters = MindGramLog.counters
        var code: [String] = [
            "MindGramGhost.isEnabled = \(MindGramGhost.isEnabled)",
            "MindGramGhost.onlySelectedChats = \(MindGramGhost.onlySelectedChats), ghostChats = \(MindGramGhost.ghostChats.count), exceptions = \(MindGramGhost.exceptions.count)"
        ]
        let hooks: [(MindGramGhost.Option, String, String)] = [
            (.hideRead, "прочтений", "SynchronizePeerReadState.swift pushPeerReadState(), ApplyMaxReadIndexInteractively.swift, ReplyThreadHistory.swift"),
            (.hideOnline, "статусов «в сети»", "ManagedAccountPresence.swift"),
            (.hideTyping, "«печатает»", "ManagedLocalInputActivities.swift requestActivity()"),
            (.hideMediaActivity, "«записывает/отправляет»", "ManagedLocalInputActivities.swift requestActivity()"),
            (.hideListening, "прослушиваний", "ManagedSynchronizeConsumeMessageContentsOperations.swift"),
            (.anonymousStories, "просмотров историй", "ManagedSynchronizeViewStoriesOperations.swift, Stories.swift")
        ]
        var words: [String] = []
        for (option, name, file) in hooks {
            let count = counters["ghost.\(option.rawValue)"] ?? 0
            code.append("\(option.rawValue): isSet = \(MindGramGhost.isSet(option)), скрыто с запуска = \(count) — TelegramCore/\(file)")
            if MindGramGhost.isSet(option) {
                words.append("\(name): \(count)")
            }
        }
        if !MindGramGhost.isEnabled {
            return MindGramCheck(title: "Режим призрака", tone: .off, status: self.off, words: "Сервер получает обычные прочтения, онлайн и «печатает».", code: code)
        }
        let scope = MindGramGhost.onlySelectedChats ? "Только в выбранных чатах (\(MindGramGhost.ghostChats.count))." : "Во всех чатах."
        return MindGramCheck(title: "Режим призрака", tone: .ok, status: self.works, words: "\(scope) Исключений: \(MindGramGhost.exceptions.count). С запуска приложения не отправлено — \(words.joined(separator: ", ")).", code: code)
    }

    private static func appGroupCheck() -> MindGramCheck {
        let groupName = "group.\(Bundle.main.bundleIdentifier ?? "")"
        let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupName)
        let code = [
            "FileManager.containerURL(forSecurityApplicationGroupIdentifier: \"\(groupName)\") = \(shared?.path ?? "nil")",
            "MindGramStorage.fallbackAppGroupUrl() = \(MindGramStorage.fallbackAppGroupUrl()?.path ?? "nil")",
            "Где: submodules/TelegramUI/Sources/AppDelegate.swift, MindGram/Core/Sources/MindGramDesign.swift"
        ]
        if shared != nil {
            return MindGramCheck(title: "Общая папка (App Group)", tone: .ok, status: self.works, words: "Расширения (уведомления, «Поделиться», виджеты) видят данные приложения.", code: code)
        }
        return MindGramCheck(title: "Общая папка (App Group)", tone: .problem, status: "Запасная", words: "Подпись без App Group: приложение работает из запасной папки, но расширения (текст в уведомлениях, «Поделиться», виджеты) данных не видят.", code: code)
    }

    private static func iconsCheck() -> MindGramCheck {
        let icons = ((self.info["CFBundleIcons"] as? [String: Any])?["CFBundleAlternateIcons"] as? [String: Any])?.keys.sorted() ?? []
        let supports = UIApplication.shared.supportsAlternateIcons
        let current = UIApplication.shared.alternateIconName
        let code = [
            "UIApplication.supportsAlternateIcons = \(supports)",
            "UIApplication.alternateIconName = \(current ?? "nil (основная)")",
            "CFBundleAlternateIcons = \(icons.joined(separator: ", "))",
            "Где: Telegram/BUILD alternate_icon_folders, MindGram/Branding/AlternateIcons"
        ]
        if !supports || icons.isEmpty {
            return MindGramCheck(title: "Иконки приложения", tone: .problem, status: self.problem, words: "iOS не даёт сменить иконку: в сборке \(icons.count) альтернативных иконок.", code: code)
        }
        return MindGramCheck(title: "Иконки приложения", tone: .ok, status: self.works, words: "Доступно иконок: \(icons.count + 1). Сейчас: \(current ?? "основная").", code: code)
    }

    private static func settingsCheck() -> MindGramCheck {
        let on = MindGramToggle.allCases.filter { MindGramSettings.isOn($0) }
        let hidden = MindGramMenuSection.allCases.filter { MindGramSettings.isHidden($0) }
        let code = [
            "MindGramToggle включены: \(on.map(\.rawValue).joined(separator: ", "))",
            "MindGramMenuSection скрыты: \(hidden.map(\.rawValue).joined(separator: ", "))",
            "navbarHeightPercent = \(MindGramSettings.navbarHeightPercent), navbarWidthPercent = \(MindGramSettings.navbarWidthPercent)"
        ]
        return MindGramCheck(title: "Настройки MindGram", tone: .ok, status: "\(on.count) вкл.", words: "Включено функций: \(on.count) из \(MindGramToggle.allCases.count). Скрыто разделов меню: \(hidden.count). Навбар: высота \(MindGramSettings.navbarHeightPercent) %, ширина \(MindGramSettings.navbarWidthPercent) %.", code: code)
    }

    private static func crashCheck() -> MindGramCheck {
        guard let report = MindGramLaunchTrace.lastCrashReport else {
            return MindGramCheck(title: "Сбои при запуске", tone: .ok, status: "Не было", words: "MindGram ни разу не падал при запуске.", code: ["Library/MindGramLastCrash.txt отсутствует"])
        }
        let lines = report.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let reason = lines.first(where: { $0.hasPrefix("exception:") || $0.hasPrefix("signal") }) ?? "без исключения: процесс завершился до конца запуска (например, его закрыла iOS)"
        let lastStep = lines.last(where: { $0.hasPrefix("step:") }) ?? "step: нет"
        return MindGramCheck(title: "Сбои при запуске", tone: .problem, status: "Был", words: "Последний сбой: \(lines.first ?? ""). Причина: \(reason). Запуск дошёл до шага «\(lastStep.replacingOccurrences(of: "step: ", with: ""))».", code: lines)
    }

    private static func errorsCheck() -> MindGramCheck {
        let entries = MindGramLog.entries
        if entries.isEmpty {
            return MindGramCheck(title: "Ошибки MindGram", tone: .ok, status: "Нет", words: "Функции MindGram не сообщали об ошибках.", code: ["MindGramLog.entries = []"])
        }
        return MindGramCheck(title: "Ошибки MindGram", tone: .problem, status: "\(entries.count)", words: "Последняя: \(entries.last?.feature ?? "") — \(entries.last?.text ?? "")", code: entries.map(self.format))
    }

    static func format(_ entry: MindGramLog.Entry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM HH:mm:ss"
        return "[\(formatter.string(from: entry.date))] \(entry.feature): \(entry.text)\n    в \(entry.location)"
    }

    /// The whole report as plain text: a short summary, then every check in words and in code.
    static func text(context: AccountContext) -> String {
        let checks = self.checks(context: context)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        var lines: [String] = []
        lines.append("MindGram — отчёт")
        lines.append("Создан: \(formatter.string(from: Date()))")
        lines.append("")
        lines.append("=== КРАТКО ===")
        for (tone, title) in [(MindGramStatusTone.ok, "✅ Работает"), (.off, "⚪️ Выключено"), (.problem, "❌ Проблемы")] {
            let names = checks.filter { $0.tone == tone }.map(\.title)
            lines.append("\(title): \(names.isEmpty ? "—" : names.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("=== ПОДРОБНО ===")
        for check in checks {
            let mark: String
            switch check.tone {
            case .ok:
                mark = "✅"
            case .off:
                mark = "⚪️"
            case .problem:
                mark = "❌"
            }
            lines.append("")
            lines.append("\(mark) \(check.title) — \(check.status)")
            lines.append("Словами: \(check.words)")
            lines.append("Код:")
            for line in check.code {
                lines.append("    \(line)")
            }
        }
        lines.append("")
        lines.append("=== ЭТОТ ЗАПУСК ===")
        lines.append(MindGramLaunchTrace.currentLaunchSteps ?? "нет данных")
        return lines.joined(separator: "\n")
    }
}
