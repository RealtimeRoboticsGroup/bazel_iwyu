#!/bin/bash
set -euo pipefail

# rules_bazel_integration_test sets:
# - BIT_BAZEL_BINARY: The path to the Bazel binary under test
# - BIT_WORKSPACE_DIR: The path to the temporary workspace directory

echo "Executing integration test..."
echo "BIT_BAZEL_BINARY: ${BIT_BAZEL_BINARY}"
echo "BIT_WORKSPACE_DIR: ${BIT_WORKSPACE_DIR}"

cd "${BIT_WORKSPACE_DIR}"

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
