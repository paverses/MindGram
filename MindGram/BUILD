load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# MindGram settings screens. One folder per screen:
#   Settings/      the "MindGram" entry, its menu and the shared list engine
#   Appearance/    Оформление
#   Profile/       Профиль (and the rows MindGram adds to profiles)
#   Tabs/          Вкладки
#   Glass/         Liquid Glass
#   MenuSections/  Разделы меню
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
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//MindGram/Core:MindGramCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/UndoUI:UndoUI",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/SettingsUI:SettingsUI",
        "//submodules/TelegramUI/Components/SliderComponent:SliderComponent",
        "//submodules/TelegramUI/Components/TabBarComponent:TabBarComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
