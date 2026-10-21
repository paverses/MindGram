load("@rules_cc//cc:objc_library.bzl", "objc_library")

# Shine, a small fixed-point MP3 encoder (https://github.com/toots/shine, LGPL-2, see COPYING and
# UPSTREAM). iOS can decode MP3 but not encode it, and Telegram's ffmpeg has no MP3 encoder, so the
# «Файл» editor converts to MP3 with this. Vendored unchanged; the public header is a copy of layer3.h.
objc_library(
    name = "MindGramShine",
    enable_modules = True,
    module_name = "MindGramShine",
    srcs = glob([
        "Sources/*.c",
        "Sources/*.h",
    ]),
    hdrs = [
        "PublicHeaders/MindGramShine/MindGramShine.h",
    ],
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-w",
    ],
    visibility = [
        "//visibility:public",
    ],
)
