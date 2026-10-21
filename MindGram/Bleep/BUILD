load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# «Запикивание мата»: swear words in voice messages and round videos are found with on-device speech
# recognition (word timings) and replaced with a beep or silence before sending.
swift_library(
    name = "MindGramBleep",
    module_name = "MindGramBleep",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/OpusBinding:OpusBinding",
    ],
    visibility = [
        "//visibility:public",
    ],
)
