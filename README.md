# bazel_iwyu: Bazel Support for IWYU

`bazel_iwyu` aims to provide C++ developers an convenient way to use IWYU (Include What You Use) with Bazel. It was inspired by the [bazel_clang_tidy](https://github.com/erenon/bazel_clang_tidy) project. Just like `bazel_clang_tidy`, you can run IWYU on Bazel C++ targets directly; there is NO need to generate a compilation database first.

> [!NOTE]
> This repository is a fork of [com_github_storypku_bazel_iwyu](https://github.com/storypku/bazel_iwyu). Since development has stalled on the original repository, we maintain this fork to keep the project active. We want to thank the original author (**storypku**) for his excellent contributions and foundations.

---

## How To Use

### 1. Using WORKSPACE (Legacy)

In your `WORKSPACE` file, add:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_iwyu",
    strip_prefix = "bazel_iwyu-<version>",
    sha256 = "<sha256sum>",
    urls = [
        "https://github.com/RealtimeRoboticsGroup/bazel_iwyu/archive/<version>.tar.gz",
    ],
)

load("@bazel_iwyu//bazel:dependencies.bzl", "bazel_iwyu_dependencies")
bazel_iwyu_dependencies()
```

### 2. Using Bzlmod (Recommended)

In your `MODULE.bazel` file, add:

```python
bazel_dep(name = "bazel_iwyu", version = "<version>")
```

---

## Configuration

1. Add the following to your `.bazelrc`:

```ini
build:iwyu --aspects @bazel_iwyu//:iwyu.bzl%iwyu_aspect
build:iwyu --output_groups=report
```

*(Note: The legacy path `@bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect` remains fully supported for backward compatibility.)*

2. **Custom Mappings**: If you would like to use your own IWYU mappings, put all your `.imp` files in a directory, say, `bazel/iwyu/mappings`, and create a `filegroup` target for it:

```python
# bazel/iwyu/BUILD.bazel
filegroup(
    name = "my_mappings",
    srcs = glob([
        "mappings/*.imp",
    ]),
)
```

Then add the following config to your `.bazelrc` to make it effective:

```ini
build:iwyu --@bazel_iwyu//:iwyu_mappings=//bazel/iwyu:my_mappings
```

3. **Custom Options**: If custom IWYU options should be used, configure them in your `.bazelrc` like so:

```ini
build:iwyu --@bazel_iwyu//:iwyu_opts=--verbose=3,--no_fwd_decls,--cxx17ns,--max_line_length=127
```

---

## Running IWYU

To run IWYU on a target:

```shell
bazel build --config=iwyu //path/to/pkg:target
```

### Applying Fixes

1. Create a top-level "external" symlink:

```shell
ln -s bazel-out/../../../external external
```

2. Run the `fix_includes.py` tool on the resulting output:

```shell
external/iwyu_prebuilt_pkg/bin/fix_includes.py --nosafe_headers < bazel-bin/path/to/pkg/<target>.iwyu.txt
```

---

## Features

1. [x] Support `x86_64` and `aarch64` on Linux, and `arm64` on macOS.
2. [x] No compilation database needed.
3. [x] Support custom IWYU mapping files.
4. [x] Support custom IWYU options.

## Contributing

Issues and PRs are always welcome.
