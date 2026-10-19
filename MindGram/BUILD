load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# MindGram settings screens. One folder per screen:
#   Settings/    the "MindGram" entry and its menu
#   Appearance/  Оформление
#   Tabs/        Вкладки
#   Profile/     Профиль
swift_library(
    name = "MindGramUI",
    module_name = "MindGramUI",
    srcs = glob([
        "Settings/**/*.swift",
        "Appearance/**/*.swift",
        "Tabs/**/*.swift",
        "Profile/**/*.swift",
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
    ],
    visibility = [
        "//visibility:public",
    ],
)
