load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# «Файл»: the screen shown before sending a file picked in Files — name and extension, music tags and
# cover, conversion (audio, video, images; MP3 through the vendored Shine encoder), and a code/text
# editor for py, ts, js, mjs, java, swift and ~80 more extensions. UIKit + AVFoundation only.
swift_library(
    name = "MindGramFileTools",
    module_name = "MindGramFileTools",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//MindGram/FileTools/Shine:MindGramShine",
    ],
    visibility = [
        "//visibility:public",
    ],
)
