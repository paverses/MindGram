load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# MindGram settings screens. One folder per screen:
#   Settings/      the "MindGram" entry, its menu and the shared list engine
#   Appearance/    Оформление
#   Profile/       Профиль (and the rows MindGram adds to profiles)
#   Tabs/          Вкладки
#   Glass/         Liquid Glass
#   MenuSections/  Разделы меню
#   GhostMode/     Режим призрака
#   Deleted/       Удалённые и правки (deleted messages, edit history)
#   ChatTools/     Чат и перевод (translation, self-destruct, taps, transcription)
#   Report/        Отчёт (what works, errors, export)
swift_library(
    name = "MindGramUI",
    module_name = "MindGramUI",
    srcs = glob([
        "Settings/**/*.swift",
        "Appearance/**/*.swift",
        "Profile/**/*.swift",
        "Tabs/**/*.swift",
        "Glass/**/*.swift",
        "MenuSections/**/*.swift",
        "GhostMode/**/*.swift",
        "AttachMenu/**/*.swift",
        "Phrases/**/*.swift",
        "MessageMenu/**/*.swift",
        "Deleted/**/*.swift",
        "ChatTools/**/*.swift",
        "Report/**/*.swift",
        "Export/**/*.swift",
        "Visual/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//MindGram/Core:MindGramCore",
        "//MindGram/FileTools:MindGramFileTools",
        "//MindGram/Bleep:MindGramBleep",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TextFormat:TextFormat",
        "//submodules/ItemListPeerItem:ItemListPeerItem",
        "//submodules/ItemListPeerActionItem:ItemListPeerActionItem",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/UndoUI:UndoUI",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/SettingsUI:SettingsUI",
        "//submodules/TelegramUI/Components/SliderComponent:SliderComponent",
        "//submodules/TelegramUI/Components/TabBarComponent:TabBarComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
