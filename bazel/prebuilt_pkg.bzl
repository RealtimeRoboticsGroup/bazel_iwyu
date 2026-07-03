# Bazel Repository Rule for external pre-built packages.

def _prebuilt_pkg_impl(repository_ctx):
    # Targets Linux and MacOS only for now.
    arch = repository_ctx.execute(["uname", "-m"]).stdout.strip()
    os_name = repository_ctx.os.name.lower()
    if os_name == "mac os x":
        os_name = "macos"
    key = "{}-{}".format(os_name, arch)

    if key not in repository_ctx.attr.urls:
        fail("Unsupported arch/OS combination: {}".format(key))

    build_file = repository_ctx.attr.build_file
    repository_ctx.symlink(build_file, "BUILD.bazel")

    urls = repository_ctx.attr.urls[key]
    sha256 = repository_ctx.attr.sha256.get(key, "")
    strip_prefix = repository_ctx.attr.strip_prefix.get(key, "")
    repository_ctx.download_and_extract(
        url = urls,
        sha256 = sha256,
        stripPrefix = strip_prefix,
    )

prebuilt_pkg = repository_rule(
    implementation = _prebuilt_pkg_impl,
    attrs = {
        "build_file": attr.label(mandatory = True),
        "sha256": attr.string_dict(allow_empty = True),
        "strip_prefix": attr.string_dict(allow_empty = True),
        "urls": attr.string_list_dict(),
    },
)
