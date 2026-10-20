load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# MindGram's translators (Google, Microsoft) and translation settings. Foundation only: TelegramCore
# routes Telegram's translation requests here (MindGram/CoreHooks/MindGramTranslateHooks.swift).
swift_library(
    name = "MindGramTranslator",
    module_name = "MindGramTranslator",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
