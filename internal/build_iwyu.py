#!/usr/bin/env python3
import argparse
import glob
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import urllib.request

# Hardcoded, reproducible mapping of Clang major versions to verified LLVM releases.
LLVM_VERSIONS = {
    16: "16.0.6",
    17: "17.0.6",
    18: "18.1.8",
    19: "19.1.7",
    20: "20.1.8",
    21: "21.1.8",
    22: "22.1.8",
}


def parse_args():
    parser = argparse.ArgumentParser(
        description="Build include-what-you-use from source."
    )
    parser.add_argument(
        "--iwyu-version",
        required=True,
        help="Version of IWYU to build (e.g., 0.20 or 0.25.0). Strips leading 'v'.",
    )
    parser.add_argument(
        "--clang-version",
        type=int,
        help="LLVM/Clang major version to use. Defaults to IWYU minor version - 4.",
    )
    parser.add_argument(
        "--output-dir", default=".", help="Directory to save the built tar.zst package."
    )
    return parser.parse_args()


def get_iwyu_versions(version_str):
    if not version_str.startswith("iwyu-"):
        sys.exit(
            f"Error: Version '{version_str}' is invalid. It must start with the 'iwyu-' prefix (e.g., iwyu-0.25.0)."
        )

    iwyu_version = version_str[5:]
    # Parse major/minor/patch
    parts = iwyu_version.split(".")
    if len(parts) < 2:
        sys.exit(
            f"Error: Invalid IWYU version '{version_str}'. Must be major.minor[.patch]"
        )

    major = int(parts[0])
    minor = int(parts[1])
    major_minor = f"{major}.{minor}"
    return iwyu_version, major_minor, minor


def get_llvm_download_info(clang_major, arch, is_darwin=False):
    version = LLVM_VERSIONS.get(clang_major)
    if not version:
        sys.exit(
            f"Error: No hardcoded LLVM release version found for Clang major version {clang_major}."
        )

    arch_str = "aarch64" if arch in ("arm64", "aarch64") else arch

    if is_darwin:
        # macOS/Darwin releases (aarch64-apple-darwin)
        filename = f"clang+llvm-{version}-{arch_str}-apple-darwin.tar.zst"
    elif arch_str == "x86_64":
        # LLVM releases on x86_64 target specific Ubuntu versions.
        # 18.1.8 targets Ubuntu 18.04, others target Ubuntu 22.04.
        if version == "18.1.8":
            os_suffix = "-ubuntu-18.04"
        else:
            os_suffix = "-ubuntu-22.04"
        filename = f"clang+llvm-{version}-x86_64-linux-gnu{os_suffix}.tar.zst"
    else:
        # aarch64 has no OS suffix in the toolchain repository.
        filename = f"clang+llvm-{version}-aarch64-linux-gnu.tar.zst"

    url = f"https://github.com/RealtimeRoboticsGroup/toolchains/releases/download/{version}/{filename}"
    return filename, url


def download_file(url, dest_path):
    print(f"Downloading {url} to {dest_path}...")
    req = urllib.request.Request(url, headers={"User-Agent": "bazel_iwyu-build-script"})
    with urllib.request.urlopen(req) as response, open(dest_path, "wb") as out_file:
        shutil.copyfileobj(response, out_file)


def normalize_extracted_dir(target_dir):
    """
    If target_dir contains only a single subdirectory (and maybe hidden files),
    move all of its contents up to target_dir.
    """
    items = [x for x in os.listdir(target_dir) if x not in (".", "..")]
    if len(items) == 1:
        subpath = os.path.join(target_dir, items[0])
        if os.path.isdir(subpath):
            print(
                f"Normalizing structure of {target_dir}: moving contents of {items[0]} up..."
            )
            for content in os.listdir(subpath):
                shutil.move(
                    os.path.join(subpath, content), os.path.join(target_dir, content)
                )
            os.rmdir(subpath)


def apply_patches(src_dir, iwyu_version, major_minor):
    patch_dirs = [
        os.path.join("internal", "patches", iwyu_version),
        os.path.join("internal", "patches", major_minor),
    ]

    applied = False
    for pdir in patch_dirs:
        if os.path.isdir(pdir):
            patches = sorted(glob.glob(os.path.join(pdir, "*.patch")))
            for patch in patches:
                print(f"Applying patch: {patch}")
                subprocess.run(
                    ["patch", "-p1", "-i", os.path.abspath(patch)],
                    cwd=src_dir,
                    check=True,
                )
                applied = True

    if not applied:
        print("No patches found to apply.")


def main():
    args = parse_args()

    iwyu_version, major_minor, minor_version = get_iwyu_versions(args.iwyu_version)

    # Calculate Clang major version if not provided.
    # Ever since IWYU 0.10, clang version is iwyu_minor - 4.
    clang_major = (
        args.clang_version if args.clang_version is not None else (minor_version - 4)
    )
    if clang_major <= 0:
        sys.exit(
            f"Error: Invalid Clang major version calculated ({clang_major}) from IWYU minor version ({minor_version})."
        )

    is_darwin = platform.system() == "Darwin"
    arch = platform.machine()
    if is_darwin:
        if arch not in ("x86_64", "arm64"):
            sys.exit(f"Error: Unsupported host architecture: {arch}")
    else:
        if arch == "arm64":
            arch = "aarch64"
        elif arch not in ("x86_64", "aarch64"):
            sys.exit(f"Error: Unsupported host architecture: {arch}")

    print(f"Targeting IWYU version: {iwyu_version}")
    print(f"Targeting Clang version: {clang_major}")
    print(f"Targeting Architecture: {arch}")

    # Use temporary directory for building
    with tempfile.TemporaryDirectory(prefix="iwyu-build-") as tmpdir:
        llvm_dir = os.path.join(tmpdir, "llvm")

        # 1. Download and extract LLVM
        os.makedirs(llvm_dir, exist_ok=True)

        # Deterministic lookup
        llvm_filename, llvm_url = get_llvm_download_info(clang_major, arch, is_darwin)
        llvm_tar = os.path.join(tmpdir, llvm_filename)
        download_file(llvm_url, llvm_tar)

        print("Extracting LLVM...")
        subprocess.run(["tar", "-xf", llvm_tar, "-C", llvm_dir], check=True)
        normalize_extracted_dir(llvm_dir)

        # 2. Download and extract IWYU source
        # Upstream include-what-you-use tags are always exactly major.minor (e.g. 0.25)
        # without patch versions.
        upstream_tag = major_minor

        iwyu_src_dir = os.path.join(tmpdir, f"include-what-you-use-{iwyu_version}")
        iwyu_url = f"https://github.com/include-what-you-use/include-what-you-use/archive/refs/tags/{upstream_tag}.tar.gz"
        iwyu_tar = os.path.join(tmpdir, f"iwyu-{iwyu_version}.tar.gz")
        download_file(iwyu_url, iwyu_tar)

        print("Extracting IWYU source...")
        os.makedirs(iwyu_src_dir, exist_ok=True)
        subprocess.run(["tar", "-xzf", iwyu_tar, "-C", iwyu_src_dir], check=True)
        normalize_extracted_dir(iwyu_src_dir)

        # 3. Apply patches if any
        apply_patches(iwyu_src_dir, iwyu_version, major_minor)

        # 4. Build and install IWYU
        build_dir = os.path.join(iwyu_src_dir, "build")
        os.makedirs(build_dir, exist_ok=True)

        os_suffix = "apple-darwin" if is_darwin else "linux-gnu"
        dest_dir = os.path.join(tmpdir, f"iwyu-{iwyu_version}-{arch}-{os_suffix}")
        os.makedirs(dest_dir, exist_ok=True)

        env = os.environ.copy()
        env["CC"] = os.path.join(llvm_dir, "bin", "clang")
        env["CXX"] = os.path.join(llvm_dir, "bin", "clang++")

        print("Configuring CMake...")
        cmake_args = [
            "cmake",
            "-G",
            "Unix Makefiles",
            "..",
            "-DCMAKE_BUILD_TYPE=Release",
            f"-DCMAKE_PREFIX_PATH={llvm_dir}",
            "-DCMAKE_VERBOSE_MAKEFILE=ON",
            f"-DCMAKE_INSTALL_PREFIX={dest_dir}",
        ]
        if is_darwin:
            cmake_args.extend(
                [
                    "-DCMAKE_FIND_LIBRARY_SUFFIXES=.a",
                    "-DIWYU_LINK_CLANG_DYLIB=OFF",
                    f"-DCMAKE_EXE_LINKER_FLAGS=-nostdlib++ {llvm_dir}/lib/libc++.a {llvm_dir}/lib/libc++abi.a",
                    f"-DCMAKE_SHARED_LINKER_FLAGS=-nostdlib++ {llvm_dir}/lib/libc++.a {llvm_dir}/lib/libc++abi.a",
                ]
            )
        subprocess.run(
            cmake_args,
            cwd=build_dir,
            env=env,
            check=True,
        )

        print("Compiling IWYU...")
        num_cores = (
            multiprocessing.cpu_count() if "multiprocessing" in sys.modules else 2
        )
        subprocess.run(["make", f"-j{num_cores}"], cwd=build_dir, env=env, check=True)

        print("Installing IWYU...")
        subprocess.run(["make", "install"], cwd=build_dir, env=env, check=True)

        # 5. Copy internal Clang compiler headers into the destination dir
        print("Locating Clang compiler headers inside LLVM...")
        clang_include_paths = glob.glob(
            os.path.join(llvm_dir, "lib", "clang", "*", "include")
        )
        if not clang_include_paths:
            sys.exit(
                "Error: Could not find Clang compiler headers in LLVM installation."
            )

        clang_include_src = clang_include_paths[0]
        rel_path = os.path.relpath(clang_include_src, llvm_dir)
        dest_include_dir = os.path.join(dest_dir, rel_path)

        print(
            f"Copying compiler headers from {clang_include_src} to {dest_include_dir}..."
        )
        os.makedirs(os.path.dirname(dest_include_dir), exist_ok=True)
        shutil.copytree(clang_include_src, dest_include_dir, dirs_exist_ok=True)

        # 6. Compress using tar and zstd -21 --ultra
        output_filename = f"iwyu-{iwyu_version}-{arch}-{os_suffix}.tar.zst"
        output_path = os.path.abspath(os.path.join(args.output_dir, output_filename))

        print(f"Packaging into {output_path} with zstd -21 --ultra...")

        tar_cmd = ["tar", "-cf", "-", os.path.basename(dest_dir)]
        zstd_cmd = ["zstd", "-21", "--ultra", "-o", output_path]

        p_tar = subprocess.Popen(
            tar_cmd, cwd=os.path.dirname(dest_dir), stdout=subprocess.PIPE
        )
        p_zstd = subprocess.Popen(zstd_cmd, stdin=p_tar.stdout, stdout=subprocess.PIPE)
        p_tar.stdout.close()
        p_zstd.communicate()

        if p_tar.wait() != 0 or p_zstd.wait() != 0:
            sys.exit("Error: Failed to package artifact using tar and zstd.")

        print(f"Successfully built and packaged IWYU to {output_path}")


if __name__ == "__main__":
    # Import multiprocessing dynamically to handle core counts
    try:
        import multiprocessing
    except ImportError:
        pass
    main()
