"""Supported versions of Include What You Use (IWYU)"""

DEFAULT_VERSION = "0.25.0"

SUPPORTED_VERSIONS = {
    "0.24.0": {
        "linux-aarch64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.0/iwyu-0.24.0-aarch64-linux-gnu.tar.zst",
            "sha256": "8ec726c8a1371d5ecec0e5e0caee82bc7edb2b0e00c33f40ce21651356023ba2",
            "strip_prefix": "iwyu-0.24.0-aarch64-linux-gnu",
        },
        "linux-x86_64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.0/iwyu-0.24.0-x86_64-linux-gnu.tar.zst",
            "sha256": "590316d4b80574bf241afb58eec5d1478a95dad818ebaaf629a2b95c9f79e075",
            "strip_prefix": "iwyu-0.24.0-x86_64-linux-gnu",
        },
        "macos-arm64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.0/iwyu-0.24.0-arm64-apple-darwin.tar.zst",
            "sha256": "b359de8a70abdfd27770a4b7cc3c00975bc210b364baafa3eab05205c3f1ca13",
            "strip_prefix": "iwyu-0.24.0-arm64-apple-darwin",
        },
    },
    "0.25.0": {
        "linux-aarch64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-aarch64-linux-gnu.tar.zst",
            "sha256": "01b2afa04f71b970a930a1108d19eb929c65d59b0810e76545056ed4fd121f2f",
            "strip_prefix": "iwyu-0.25.0-aarch64-linux-gnu",
        },
        "linux-x86_64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-x86_64-linux-gnu.tar.zst",
            "sha256": "ae37672c7e34e87e01b017bbd321dedf5e8fda68fcec6f94ca62df0ac5c66231",
            "strip_prefix": "iwyu-0.25.0-x86_64-linux-gnu",
        },
        "macos-arm64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.0/iwyu-0.25.0-arm64-apple-darwin.tar.zst",
            "sha256": "6e8afade21a9e0e1e6b123405047c56333b368802f16f3b6e8e701d4c2b9b58e",
            "strip_prefix": "iwyu-0.25.0-arm64-apple-darwin",
        },
    },
}
