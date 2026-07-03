"""Module extensions for bazel_iwyu"""

load("//bazel:prebuilt_pkg.bzl", "prebuilt_pkg")
load("//bazel/iwyu:versions.bzl", "DEFAULT_VERSION", "SUPPORTED_VERSIONS")

def _iwyu_impl(module_ctx):
    version = DEFAULT_VERSION

    # Find the version requested by modules. We'll use the root module's request
    # or the first version we find.
    for mod in module_ctx.modules:
        for tag in mod.tags.toolchain:
            if tag.version:
                version = tag.version

    if version not in SUPPORTED_VERSIONS:
        fail("Unsupported IWYU version: {}. Supported versions: {}".format(
            version,
            ", ".join(SUPPORTED_VERSIONS.keys()),
        ))

    version_info = SUPPORTED_VERSIONS[version]

    urls = {platform: [info["url"]] for platform, info in version_info.items()}
    sha256 = {platform: info["sha256"] for platform, info in version_info.items()}
    strip_prefix = {platform: info["strip_prefix"] for platform, info in version_info.items()}

    prebuilt_pkg(
        name = "iwyu_prebuilt_pkg",
        build_file = Label("//bazel/iwyu:BUILD.prebuilt_pkg"),
        urls = urls,
        sha256 = sha256,
        strip_prefix = strip_prefix,
    )

toolchain_tag = tag_class(
    attrs = {
        "version": attr.string(
            doc = "The prebuilt IWYU version to use (e.g. '0.24.2', '0.25.2').",
            default = DEFAULT_VERSION,
        ),
    },
)

iwyu = module_extension(
    implementation = _iwyu_impl,
    tag_classes = {
        "toolchain": toolchain_tag,
    },
)
