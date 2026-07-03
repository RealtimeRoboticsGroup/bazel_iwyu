#!/usr/bin/env python3
import argparse
import glob
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

def parse_args():
    parser = argparse.ArgumentParser(description="Build include-what-you-use from source.")
    parser.add_argument(
        "--iwyu-version",
        required=True,
        help="Version of IWYU to build (e.g., 0.20 or 0.25.0). Strips leading 'v'."
    )
    parser.add_argument(
        "--clang-version",
        type=int,
        help="LLVM/Clang major version to use. Defaults to IWYU minor version - 4."
    )
    parser.add_argument(
        "--output-dir",
        default=".",
        help="Directory to save the built tar.zst package."
    )
    return parser.parse_args()

def get_iwyu_versions(version_str):
    iwyu_version = version_str.lstrip("v")
    # Parse major/minor/patch
    parts = iwyu_version.split(".")
    if len(parts) < 2:
        sys.exit(f"Error: Invalid IWYU version '{version_str}'. Must be major.minor[.patch]")
    
    major = int(parts[0])
    minor = int(parts[1])
    major_minor = f"{major}.{minor}"
    return iwyu_version, major_minor, minor

def get_llvm_release_info(clang_major, token=None):
    print(f"Querying GitHub API for LLVM major version {clang_major} release...")
    url = "https://api.github.com/repos/llvm/llvm-project/releases"
    req = urllib.request.Request(url, headers={"User-Agent": "bazel_iwyu-build-script"})
    
    if token:
        req.add_header("Authorization", f"token {token}")
        
    try:
        with urllib.request.urlopen(req) as response:
            releases = json.loads(response.read().decode())
            
        # Match llvmorg-<clang_major>.*.*
        pattern = re.compile(rf"^llvmorg-{clang_major}\.\d+\.\d+$")
        matching = []
        for r in releases:
            tag = r.get("tag_name", "")
            if pattern.match(tag):
                matching.append(r)
                
        if not matching:
            # Fallback to double-component tags e.g. llvmorg-16.0
            pattern_short = re.compile(rf"^llvmorg-{clang_major}\.\d+$")
            for r in releases:
                tag = r.get("tag_name", "")
                if pattern_short.match(tag):
                    matching.append(r)
                    
        if matching:
            # Sort by version tuple descending
            def version_key(release):
                v_str = release["tag_name"].replace("llvmorg-", "")
                return [int(x) for x in v_str.split(".")]
            matching.sort(key=version_key, reverse=True)
            latest = matching[0]
            print(f"Found LLVM release: {latest['tag_name']}")
            return latest
    except Exception as e:
        print(f"Error: Failed to fetch releases from GitHub API: {e}")
        
    return None

def find_llvm_asset(release, arch):
    assets = release.get("assets", [])
    for asset in assets:
        name = asset.get("name", "")
        if not name.endswith(".tar.xz"):
            continue
        if "asserts" in name:
            continue
        if arch not in name:
            continue
        if "linux" not in name:
            continue
        return asset.get("browser_download_url"), name
    return None, None

def download_file(url, dest_path):
    print(f"Downloading {url} to {dest_path}...")
    req = urllib.request.Request(url, headers={"User-Agent": "bazel_iwyu-build-script"})
    with urllib.request.urlopen(req) as response, open(dest_path, "wb") as out_file:
        shutil.copyfileobj(response, out_file)

def apply_patches(src_dir, iwyu_version, major_minor):
    patch_dirs = [
        os.path.join("internal", "patches", iwyu_version),
        os.path.join("internal", "patches", major_minor)
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
                    check=True
                )
                applied = True
                
    if not applied:
        print("No patches found to apply.")

def main():
    args = parse_args()
    
    iwyu_version, major_minor, minor_version = get_iwyu_versions(args.iwyu_version)
    
    # Calculate Clang major version if not provided.
    # Ever since IWYU 0.10, clang version is iwyu_minor - 4.
    clang_major = args.clang_version if args.clang_version is not None else (minor_version - 4)
    if clang_major <= 0:
        sys.exit(f"Error: Invalid Clang major version calculated ({clang_major}) from IWYU minor version ({minor_version}).")
        
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
        
        # 1. Install or download LLVM
        if is_darwin:
            print(f"Installing LLVM {clang_major} via Homebrew...")
            formula = f"llvm@{clang_major}"
            try:
                subprocess.run(["brew", "install", formula], check=True)
            except subprocess.CalledProcessError:
                print(f"Versioned formula {formula} not found or failed. Trying generic 'llvm'...")
                formula = "llvm"
                subprocess.run(["brew", "install", formula], check=True)
                
            # Get the installation prefix
            prefix_proc = subprocess.run(["brew", "--prefix", formula], capture_output=True, text=True, check=True)
            llvm_dir = prefix_proc.stdout.strip()
            print(f"Using macOS LLVM path: {llvm_dir}")
        else:
            os.makedirs(llvm_dir, exist_ok=True)
            token = os.environ.get("GITHUB_TOKEN")
            release = get_llvm_release_info(clang_major, token)
            if not release:
                sys.exit(f"Error: Could not retrieve LLVM release info from GitHub API for version {clang_major}.")
            
            llvm_url, llvm_filename = find_llvm_asset(release, arch)
            if not llvm_url:
                sys.exit(f"Error: Could not locate LLVM download asset for {arch} in release {release.get('tag_name')}.")
                
            llvm_tar = os.path.join(tmpdir, llvm_filename)
            download_file(llvm_url, llvm_tar)
                
            print("Extracting LLVM...")
            subprocess.run(
                ["tar", "xJf", llvm_tar, "--strip-components=1", "-C", llvm_dir],
                check=True
            )
        
        # 2. Download and extract IWYU source
        iwyu_src_dir = os.path.join(tmpdir, f"include-what-you-use-{iwyu_version}")
        iwyu_url = f"https://github.com/include-what-you-use/include-what-you-use/archive/refs/tags/{iwyu_version}.tar.gz"
        iwyu_tar = os.path.join(tmpdir, f"iwyu-{iwyu_version}.tar.gz")
        download_file(iwyu_url, iwyu_tar)
        
        print("Extracting IWYU source...")
        os.makedirs(iwyu_src_dir, exist_ok=True)
        subprocess.run(
            ["tar", "xzf", iwyu_tar, "--strip-components=1", "-C", iwyu_src_dir],
            check=True
        )
        
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
        subprocess.run(
            [
                "cmake",
                "-G", "Unix Makefiles",
                "..",
                "-DCMAKE_BUILD_TYPE=Release",
                f"-DCMAKE_PREFIX_PATH={llvm_dir}",
                "-DCMAKE_VERBOSE_MAKEFILE=ON",
                f"-DCMAKE_INSTALL_PREFIX={dest_dir}"
            ],
            cwd=build_dir,
            env=env,
            check=True
        )
        
        print("Compiling IWYU...")
        num_cores = multiprocessing.cpu_count() if "multiprocessing" in sys.modules else 2
        subprocess.run(
            ["make", f"-j{num_cores}"],
            cwd=build_dir,
            env=env,
            check=True
        )
        
        print("Installing IWYU...")
        subprocess.run(
            ["make", "install"],
            cwd=build_dir,
            env=env,
            check=True
        )
        
        # 5. Copy internal Clang compiler headers into the destination dir
        print("Locating Clang compiler headers inside LLVM...")
        clang_include_paths = glob.glob(os.path.join(llvm_dir, "lib", "clang", "*", "include"))
        if not clang_include_paths:
            sys.exit("Error: Could not find Clang compiler headers in LLVM installation.")
            
        clang_include_src = clang_include_paths[0]
        rel_path = os.path.relpath(clang_include_src, llvm_dir)
        dest_include_dir = os.path.join(dest_dir, rel_path)
        
        print(f"Copying compiler headers from {clang_include_src} to {dest_include_dir}...")
        os.makedirs(os.path.dirname(dest_include_dir), exist_ok=True)
        shutil.copytree(clang_include_src, dest_include_dir, dirs_exist_ok=True)
        
        # 6. Compress using tar and zstd -21 --ultra
        output_filename = f"iwyu-{iwyu_version}-{arch}-{os_suffix}.tar.zst"
        output_path = os.path.abspath(os.path.join(args.output_dir, output_filename))
        
        print(f"Packaging into {output_path} with zstd -21 --ultra...")
        
        tar_cmd = ["tar", "-cf", "-", os.path.basename(dest_dir)]
        zstd_cmd = ["zstd", "-21", "--ultra", "-o", output_path]
        
        p_tar = subprocess.Popen(tar_cmd, cwd=os.path.dirname(dest_dir), stdout=subprocess.PIPE)
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
