load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Ghost mode switches and MindGramLog (the «Отчёт» journal). Foundation only: TelegramCore (which must
# not see UIKit) reads and writes them where it
# talks to the server.
swift_library(
    name = "MindGramGhost",
    module_name = "MindGramGhost",
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
