"""Supported versions of Include What You Use (IWYU)"""

DEFAULT_VERSION = "0.25.0"

SUPPORTED_VERSIONS = {
    "0.24.0": {
        "linux-aarch64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.0/iwyu-0.24.0-aarch64-linux-gnu.tar.zst",
            "sha256": "f06db9aea7ec13d1b6cdbaf16c6ccb71fcdaf92445910f2e9b4bd4f41150ee16",
            "strip_prefix": "iwyu-0.24.0-aarch64-linux-gnu",
        },
        "linux-x86_64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.0/iwyu-0.24.0-x86_64-linux-gnu.tar.zst",
            "sha256": "f96ba71d2b0bfd06fe38074e8e7379f3cbee909cfba6a492beef3ca6b95bd5f2",
            "strip_prefix": "iwyu-0.24.0-x86_64-linux-gnu",
        },
        "macos-arm64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.0/iwyu-0.24.0-arm64-apple-darwin.tar.zst",
            "sha256": "a15dc7a5b274500e761bcebd6484eacdf08bc9392749316ea12f0223eefe65f0",
            "strip_prefix": "iwyu-0.24.0-arm64-apple-darwin",
        },
    },
    "0.25.0": {
        "linux-aarch64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-aarch64-linux-gnu.tar.zst",
            "sha256": "a0feabded1a0e71997bdb93368d592c20d7caba2d71fcf845096b3b329902866",
            "strip_prefix": "iwyu-0.25.0-aarch64-linux-gnu",
        },
        "linux-x86_64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-x86_64-linux-gnu.tar.zst",
            "sha256": "1a31d9142c78c4c133cf7b1521c34546e5f0f9561e4787f5a2ef8d516a492833",
            "strip_prefix": "iwyu-0.25.0-x86_64-linux-gnu",
        },
        "macos-arm64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-arm64-apple-darwin.tar.zst",
            "sha256": "14f073a32e64ca03cee919ba8e16c48a1864c25732edffee95b29b641f11719d",
            "strip_prefix": "iwyu-0.25.0-arm64-apple-darwin",
        },
    },
}
