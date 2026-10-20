load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# MindGram switches and branding that the lowest UI layers need (Display re-exports this module).
# Depends on nothing but the system frameworks, so any Telegram module can see it.
swift_library(
    name = "MindGramCore",
    module_name = "MindGramCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//MindGram/Ghost:MindGramGhost",
    ],
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
