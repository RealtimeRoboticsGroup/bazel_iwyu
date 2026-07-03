"""Supported versions of Include What You Use (IWYU)"""

DEFAULT_VERSION = "0.25.1"

SUPPORTED_VERSIONS = {
    "0.24.1": {
        "linux-aarch64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.1/iwyu-0.24.1-aarch64-linux-gnu.tar.zst",
            "sha256": "4517b108edf8a31ef2fcf23062e55998d093120aa3b4ea6bf7deecb4508c6b66",
            "strip_prefix": "iwyu-0.24.1-aarch64-linux-gnu",
        },
        "linux-x86_64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.1/iwyu-0.24.1-x86_64-linux-gnu.tar.zst",
            "sha256": "2fb6ca7d35f43f600d99a0ea57f0bc226a96fa0d772bd048610384ae3251c900",
            "strip_prefix": "iwyu-0.24.1-x86_64-linux-gnu",
        },
        "macos-arm64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.24.1/iwyu-0.24.1-arm64-apple-darwin.tar.zst",
            "sha256": "3eca646f9bd7cd7cb9df909129bccbf027d9d8a0bf19ebeac7a885c744ea164d",
            "strip_prefix": "iwyu-0.24.1-arm64-apple-darwin",
        },
    },
    "0.25.1": {
        "linux-aarch64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.1/iwyu-0.25.1-aarch64-linux-gnu.tar.zst",
            "sha256": "b592d4a2802478476747f519f915c0cbc883d3b89522f179357a7b3f26655ff0",
            "strip_prefix": "iwyu-0.25.1-aarch64-linux-gnu",
        },
        "linux-x86_64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.1/iwyu-0.25.1-x86_64-linux-gnu.tar.zst",
            "sha256": "624d11a42ee84ebe2c4d68f099f3733354b6ef4fbfa88542a127dec6d870cc33",
            "strip_prefix": "iwyu-0.25.1-x86_64-linux-gnu",
        },
        "macos-arm64": {
            "url": "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/releases/download/iwyu-0.25.1/iwyu-0.25.1-arm64-apple-darwin.tar.zst",
            "sha256": "0ee6756d992240e7679111d7a8e18df33f18f416bb04b727c83cbfb11ff989d1",
            "strip_prefix": "iwyu-0.25.1-arm64-apple-darwin",
        },
    },
}
