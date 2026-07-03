load("//bazel:sysroots.bzl", sysroot_setup = "repo")

def _sysroot_extension_impl(ctx):
    sysroot_setup()

sysroot_extension = module_extension(
    implementation = _sysroot_extension_impl,
)
