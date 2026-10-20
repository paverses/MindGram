load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Message features: saved deleted messages, edit history, self-destructing own messages, tap actions,
# on-device transcription. Foundation only: TelegramCore writes these stores while it applies server
# updates (hooks in MindGram/CoreHooks), the chat UI reads them.
swift_library(
    name = "MindGramMessages",
    module_name = "MindGramMessages",
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
