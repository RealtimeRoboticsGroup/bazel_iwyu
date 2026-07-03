"""IWYU toolchain definition"""

IwyuToolchainInfo = provider(
    doc = "Details of include-what-you-use toolchain",
    fields = {
        "iwyu_executable": "The include-what-you-use wrapper/executable (File)",
        "iwyu_runfiles": "The runfiles of the toolchain (depset of Files)",
    },
)

def _iwyu_toolchain_impl(ctx):
    iwyu_tool = ctx.executable.iwyu_tool
    iwyu_path = iwyu_tool.path

    # Attempt to locate the Clang resource directory (lib/clang/<version>)
    # to pass it as -resource-dir.
    resource_dir = None
    if ctx.files.data:
        for f in ctx.files.data:
            path = f.path
            parts = path.split("/")

            # We expect the path to contain "lib", "clang", and "include" in a strict sequence:
            # .../lib/clang/<version>/include/...
            lib_idx = -1
            for i in range(len(parts) - 3):
                if parts[i] == "lib" and parts[i + 1] == "clang" and parts[i + 3] == "include":
                    lib_idx = i
                    break

            if lib_idx == -1:
                fail("Expected toolchain data file path to contain 'lib/clang/<version>/include/...', but got: {}".format(path))

            resource_dir = "/".join(parts[:lib_idx + 3])
            break

    resource_dir_flag = ""
    if resource_dir:
        resource_dir_flag = ' -Xclang -resource-dir -Xclang "{}"'.format(resource_dir)

    wrapper = ctx.actions.declare_file(ctx.label.name + "_wrapper.sh")

    script_content = """#!/bin/bash
set -euo pipefail

readonly RED='\\033[0;31m'
readonly RESET='\\033[0m'

IWYU_BINARY="{iwyu_path}"

function error() {{
  (echo >&2 -e "${{RED}}[ERROR]${{RESET}} $*")
}}

OUTPUT="$1"
shift

touch "${{OUTPUT}}"
truncate -s 0 "${{OUTPUT}}"

if ! "${{IWYU_BINARY}}"{resource_dir_flag} "$@" 2> "${{OUTPUT}}"; then
  error "IWYU violation found. Fixes have been written to ${{OUTPUT}}"
  cat "${{OUTPUT}}"
  exit 1
fi
""".format(iwyu_path = iwyu_path, resource_dir_flag = resource_dir_flag)

    ctx.actions.write(
        output = wrapper,
        content = script_content,
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = ctx.files.data + [ctx.file.iwyu_tool],
    ).merge(
        ctx.attr.iwyu_tool[DefaultInfo].default_runfiles,
    )

    return [
        DefaultInfo(
            executable = wrapper,
            runfiles = runfiles,
        ),
        platform_common.ToolchainInfo(
            iwyu_info = IwyuToolchainInfo(
                iwyu_executable = wrapper,
                iwyu_runfiles = runfiles.files,
            ),
        ),
    ]

iwyu_toolchain = rule(
    implementation = _iwyu_toolchain_impl,
    attrs = {
        "iwyu_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_single_file = True,
        ),
        "data": attr.label_list(
            allow_files = True,
        ),
    },
)
