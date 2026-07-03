load("@bazel_iwyu//bazel:prebuilt_pkg.bzl", "prebuilt_pkg")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def bazel_iwyu_dependencies():
    maybe(
        prebuilt_pkg,
        name = "iwyu_prebuilt_pkg",
        build_file = Label("//bazel/iwyu:BUILD.prebuilt_pkg"),
        urls = {
            "linux-aarch64": [
                "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-aarch64-linux-gnu.tar.zst",
            ],
            "linux-x86_64": [
                "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-x86_64-linux-gnu.tar.zst",
            ],
            "macos-arm64": [
                "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-arm64-apple-darwin.tar.zst",
            ],
        },
        strip_prefix = {
            "linux-aarch64": "iwyu-0.25.0-aarch64-linux-gnu",
            "linux-x86_64": "iwyu-0.25.0-x86_64-linux-gnu",
            "macos-arm64": "iwyu-0.25.0-arm64-apple-darwin",
        },
        sha256 = {
            "linux-aarch64": "01b2afa04f71b970a930a1108d19eb929c65d59b0810e76545056ed4fd121f2f",
            "linux-x86_64": "ae37672c7e34e87e01b017bbd321dedf5e8fda68fcec6f94ca62df0ac5c66231",
            "macos-arm64": "6e8afade21a9e0e1e6b123405047c56333b368802f16f3b6e8e701d4c2b9b58e",
        },
    )

    maybe(
        http_archive,
        name = "bazel_skylib",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/archive/1.3.0.tar.gz",
        ],
        sha256 = "3b620033ca48fcd6f5ef2ac85e0f6ec5639605fa2f627968490e52fc91a9932f",
        strip_prefix = "bazel-skylib-1.3.0",
    )
