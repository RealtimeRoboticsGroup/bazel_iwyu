#!/bin/bash
set -euo pipefail

# Set HOME inside the test temp dir to avoid sandbox access issues on macOS
export HOME="${TEST_TMPDIR}/home"
mkdir -p "${HOME}"

# Resolve sandbox and setup writable workspace
readonly WRITABLE_WORKSPACE="${TEST_TMPDIR}/writable_workspace"
mkdir -p "${WRITABLE_WORKSPACE}"
cp -RL "${BIT_WORKSPACE_DIR}"/* "${WRITABLE_WORKSPACE}/"
chmod -R +w "${WRITABLE_WORKSPACE}"

PARENT_ROOT=$(realpath "${BIT_WORKSPACE_DIR}/../../..")
sed "s|path = \"../../..\"|path = \"${PARENT_ROOT}\"|g" "${WRITABLE_WORKSPACE}/MODULE.bazel" > "${WRITABLE_WORKSPACE}/MODULE.bazel.tmp" && mv "${WRITABLE_WORKSPACE}/MODULE.bazel.tmp" "${WRITABLE_WORKSPACE}/MODULE.bazel"

cd "${WRITABLE_WORKSPACE}"

# Under default mappings, main.cc has an unused include "my_header.h"
# So the build is expected to fail with a violation report
echo "Running initial build (should find unused include)..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report //... || true

FIX_INCLUDES_PY=$(find "${TEST_TMPDIR}/output_user_root" -name "fix_includes.py" | head -n 1)
if [[ -z "${FIX_INCLUDES_PY}" ]]; then
  echo "Error: fix_includes.py script not found!" >&2
  exit 1
fi

IWYU_REPORT=$(find -L bazel-out -name "main.main.cc.iwyu.txt" | head -n 1)
if [[ -z "${IWYU_REPORT}" ]]; then
  echo "Error: IWYU report not found!" >&2
  exit 1
fi

echo "Applying IWYU fixes to main.cc..."
python3 "${FIX_INCLUDES_PY}" --noreorder < "${IWYU_REPORT}"

echo "Updated main.cc content:"
cat main.cc

if grep -q "my_header.h" main.cc; then
  echo "Error: fix_includes.py failed to remove unused include!" >&2
  exit 1
fi

echo "Re-running build (should succeed)..."
if ! "${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report //...; then
  echo "Error: Build failed after applying fixes!" >&2
  exit 1
fi

echo "Success: Unused include fixed successfully."
