# MindGram code compiled INTO TelegramCore (listed in submodules/TelegramCore/BUILD srcs), because it
# needs TelegramCore internals: Postbox transactions, the Api layer, internal helpers. Kept here so all
# MindGram code lives under MindGram/ and the upstream files only carry one-line calls.
filegroup(
    name = "Sources",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    visibility = [
        "//visibility:public",
    ],
)
