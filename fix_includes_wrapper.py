#!/usr/bin/env python3
import os
import sys
import subprocess


def main():
    runfiles_dir = os.environ.get("RUNFILES_DIR")
    if not runfiles_dir:
        # Fallback: find the runfiles directory relative to this script
        # The script is at: <runfiles_dir>/[main_repo_name]/fix_includes_wrapper.py
        # So <runfiles_dir> is two directory levels up from the script file.
        script_dir = os.path.dirname(os.path.abspath(__file__))
        runfiles_dir = os.path.dirname(script_dir)

    # Search for the real fix_includes.py script in runfiles
    possible_paths = [
        os.path.join(
            runfiles_dir, "bazel_iwyu++iwyu+iwyu_prebuilt_pkg", "bin", "fix_includes.py"
        ),
        os.path.join(runfiles_dir, "iwyu_prebuilt_pkg", "bin", "fix_includes.py"),
    ]

    real_script = None
    for path in possible_paths:
        if os.path.exists(path):
            real_script = path
            break

    if not real_script:
        # Let's do a wider search in runfiles if not found at known locations
        for root, dirs, files in os.walk(runfiles_dir):
            if "fix_includes.py" in files:
                real_script = os.path.join(root, "fix_includes.py")
                break

    if not real_script:
        sys.exit(
            f"ERROR: Could not find fix_includes.py in runfiles directory: {runfiles_dir}"
        )

    # Build the target argument list
    args = [sys.executable, real_script]

    # Check if basedir is already specified in the command line
    has_basedir = any(
        arg == "--basedir"
        or arg.startswith("--basedir=")
        or arg == "-p"
        or arg.startswith("-p=")
        for arg in sys.argv[1:]
    )

    workspace_dir = os.environ.get("BUILD_WORKSPACE_DIRECTORY")
    if workspace_dir and not has_basedir:
        args.extend(["--basedir", workspace_dir])

    args.extend(sys.argv[1:])

    # Execute and propagate exit code
    result = subprocess.run(args)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
