load("@bazel_iwyu//bazel/iwyu:versions.bzl", "DEFAULT_VERSION", "SUPPORTED_VERSIONS")
load("@bazel_iwyu//bazel:prebuilt_pkg.bzl", "prebuilt_pkg")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def bazel_iwyu_dependencies(version = DEFAULT_VERSION):
    if version not in SUPPORTED_VERSIONS:
        fail("Unsupported IWYU version: {}. Supported versions: {}".format(
            version,
            ", ".join(SUPPORTED_VERSIONS.keys()),
        ))

    version_info = SUPPORTED_VERSIONS[version]

    urls = {platform: [info["url"]] for platform, info in version_info.items()}
    sha256 = {platform: info["sha256"] for platform, info in version_info.items()}
    strip_prefix = {platform: info["strip_prefix"] for platform, info in version_info.items()}

    maybe(
        prebuilt_pkg,
        name = "iwyu_prebuilt_pkg",
        build_file = Label("@bazel_iwyu//bazel/iwyu:BUILD.prebuilt_pkg"),
        urls = urls,
        sha256 = sha256,
        strip_prefix = strip_prefix,
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
