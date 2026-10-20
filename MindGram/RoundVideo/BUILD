load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Effects and masks for round videos: face blur, background blur, face masks, color filters. Core Image
# and Vision only, no Telegram modules, so the camera (submodules/Camera) can use it directly.
swift_library(
    name = "MindGramRoundVideo",
    module_name = "MindGramRoundVideo",
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
