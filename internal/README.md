# Building Include What You Use (IWYU)

This repository automatically builds and packages self-contained `include-what-you-use` binaries for both `x86_64` and `aarch64` architectures.

---

## 1. Automated Builds (GitHub Actions)

When a GitHub release is created or published, the [.github/workflows/build-release.yml](file:///home/austin/local/bazel_iwyu/.github/workflows/build-release.yml) workflow is triggered automatically:
1. It reads the release version tag (e.g. `0.25.0` or `0.20`).
2. It spins up two runners (native `x86_64` and native `aarch64`) running inside an `ubuntu:22.04` container to guarantee glibc compatibility (`glibc 2.35`).
3. It downloads the matching LLVM/Clang release compiler from LLVM's official GitHub releases.
4. It compiles and packages IWYU, embedding the required Clang compiler header files inside the archive.
5. It uploads the resulting `.tar.xz` archives back to the GitHub release.

You can also run this workflow manually from the GitHub Actions tab via **Workflow Dispatch**, entering the target IWYU version and Clang version.

---

## 2. Local Builds (with Python)

The build process is fully automated by the python script [internal/build_iwyu.py](file:///home/austin/local/bazel_iwyu/internal/build_iwyu.py).

### Prerequisites
Make sure you have build dependencies installed:
```bash
sudo apt-get install -y cmake build-essential python3 libtinfo-dev zlib1g-dev libzstd-dev xz-utils patch
```

### Running the Build
To build IWYU 0.25.0 against Clang 21:
```bash
python3 internal/build_iwyu.py --iwyu-version 0.25.0
```

By default, the script calculates the Clang major version to use based on the IWYU minor version (`minor - 4`). You can override this using `--clang-version`:
```bash
python3 internal/build_iwyu.py --iwyu-version 0.25.0 --clang-version 21
```

The script will:
1. Search GitHub LLVM releases to download the appropriate pre-compiled LLVM compiler to `/tmp`.
2. Fetch and extract the IWYU source tag from GitHub.
3. Automatically apply patches found in `internal/patches/<version>/` or `internal/patches/<major_minor>/` (e.g., [internal/patches/0.20/p01_angle_quote_curse_dirty_fix.patch](file:///home/austin/local/bazel_iwyu/internal/patches/0.20/p01_angle_quote_curse_dirty_fix.patch)).
4. Compile and install IWYU into a release folder, bundle Clang's internal headers, and package it as `iwyu-<version>-<arch>-linux-gnu.tar.xz`.

---

## 3. Local Builds using Docker (For GLIBC compatibility)

To ensure the built binaries are compatible with older Linux platforms (e.g. Debian 12, Ubuntu 22.04), you should build inside an `ubuntu:22.04` docker container so that it links against `glibc 2.35`:

```bash
docker run -it --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  ubuntu:22.04 \
  bash -c "apt-get update && apt-get install -y cmake build-essential python3 libtinfo-dev zlib1g-dev libzstd-dev xz-utils patch ca-certificates wget curl git && python3 internal/build_iwyu.py --iwyu-version 0.25.0"
```

The built tarball `iwyu-0.25.0-x86_64-linux-gnu.tar.xz` will be output to your host's current working directory.
