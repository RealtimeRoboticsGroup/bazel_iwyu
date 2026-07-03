#!/bin/bash
set -euo pipefail

# rules_bazel_integration_test sets:
# - BIT_BAZEL_BINARY: The path to the Bazel binary under test
# - BIT_WORKSPACE_DIR: The path to the temporary workspace directory

echo "Executing integration test..."
echo "BIT_BAZEL_BINARY: ${BIT_BAZEL_BINARY}"
echo "BIT_WORKSPACE_DIR: ${BIT_WORKSPACE_DIR}"

# Create a fully writable copy of the child workspace in TEST_TMPDIR to allow in-place file modifications.
WRITABLE_WORKSPACE="${TEST_TMPDIR}/writable_workspace"
cp -RL "${BIT_WORKSPACE_DIR}" "${WRITABLE_WORKSPACE}"
chmod -R +w "${WRITABLE_WORKSPACE}"

# Resolve the absolute path to the parent workspace (staged in the integration test runfiles)
PARENT_ROOT=$(realpath "${BIT_WORKSPACE_DIR}/../../..")

# Rewrite local_path_override in MODULE.bazel to point to the absolute parent path
sed -i "s|path = \"../../..\"|path = \"${PARENT_ROOT}\"|g" "${WRITABLE_WORKSPACE}/MODULE.bazel"

cd "${WRITABLE_WORKSPACE}"

# Run bazel build (expected to exit non-zero due to IWYU violations)
# We configure --output_user_root, --repository_cache, and --ignore_all_rc_files
# to ensure it executes hermetically and cleanly inside the write-restricted sandbox.
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report //... || true

# Check the generated wrapper script path
WRAPPER_FILE=$(find -L bazel-out -name "*_wrapper.sh" | head -n 1)

if [[ -z "${WRAPPER_FILE}" ]]; then
  echo "Error: Generated wrapper script not found!" >&2
  exit 1
fi

echo "Found wrapper script: ${WRAPPER_FILE}"
cat "${WRAPPER_FILE}"

# Verify it contains Clang 20 (used by IWYU 0.24.0) instead of Clang 21 (used by IWYU 0.25.0)
if grep -q "lib/clang/20" "${WRAPPER_FILE}"; then
  echo "Success: Wrapper script correctly references Clang 20 (from IWYU 0.24.0)."
else
  echo "Error: Wrapper script does not reference Clang 20. Version selection failed!" >&2
  exit 1
fi

# Locate fix_includes.py in the external workspace directory
FIX_INCLUDES_PY=$(find "${TEST_TMPDIR}/output_user_root" -name "fix_includes.py" | head -n 1)

if [[ -z "${FIX_INCLUDES_PY}" ]]; then
  echo "Error: fix_includes.py script not found!" >&2
  exit 1
fi

echo "Found fix_includes.py at: ${FIX_INCLUDES_PY}"

# The IWYU report is written to bazel-out
IWYU_REPORT=$(find -L bazel-out -name "main.main.cc.iwyu.txt" | head -n 1)

if [[ -z "${IWYU_REPORT}" ]]; then
  echo "Error: IWYU report file main.main.cc.iwyu.txt not found!" >&2
  exit 1
fi

echo "Applying IWYU fixes to main.cc..."
# Run the python script to apply the fixes in place
python3 "${FIX_INCLUDES_PY}" --noreorder < "${IWYU_REPORT}"

echo "Updated main.cc content:"
cat main.cc

# Verify that the unused #include <stddef.h> was removed
if grep -q "stddef.h" main.cc; then
  echo "Error: fix_includes.py failed to remove #include <stddef.h>!" >&2
  exit 1
fi

echo "Success: Unused include was successfully removed by fix_includes.py."

# Rerun the aspect build. Since we fixed the violation, the build should now complete successfully with exit code 0.
echo "Re-running IWYU build on fixed workspace..."
if ! "${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report //...; then
  echo "Error: IWYU build failed after applying the fix!" >&2
  exit 1
fi

echo "Success: IWYU build completed successfully with 0 violations after applying the fix."

