#!/bin/bash
set -euo pipefail

# Resolve sandbox and setup writable workspace
readonly WRITABLE_WORKSPACE="${TEST_TMPDIR}/writable_workspace"
mkdir -p "${WRITABLE_WORKSPACE}"
cp -RL "${BIT_WORKSPACE_DIR}"/* "${WRITABLE_WORKSPACE}/"
chmod -R +w "${WRITABLE_WORKSPACE}"

PARENT_ROOT=$(realpath "${BIT_WORKSPACE_DIR}/../../..")
sed -i "s|path = \"../../..\"|path = \"${PARENT_ROOT}\"|g" "${WRITABLE_WORKSPACE}/MODULE.bazel"

cd "${WRITABLE_WORKSPACE}"

# Overwrite main.cc to include my_header.h and call my_func()
cat << 'EOF' > main.cc
#include "my_header.h"
void call_func() {
    my_func();
}
EOF

# Run build under custom mappings (expected to exit non-zero due to mapping violation)
echo "Running custom mappings build..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report \
  --@bazel_iwyu//:iwyu_mappings=//:custom_mappings \
  //... || true

IWYU_REPORT=$(find -L bazel-out -name "main.main.cc.iwyu.txt" | head -n 1)
if [[ -z "${IWYU_REPORT}" ]]; then
  echo "Error: IWYU report not found!" >&2
  exit 1
fi

echo "IWYU report content:"
cat "${IWYU_REPORT}"

if grep -q "my_header_custom.h" "${IWYU_REPORT}"; then
  echo "Success: Custom mappings suggested correctly."
else
  echo "Error: Custom mapping suggest failed!" >&2
  exit 1
fi

FIX_INCLUDES_PY=$(find "${TEST_TMPDIR}/output_user_root" -name "fix_includes.py" | head -n 1)
if [[ -z "${FIX_INCLUDES_PY}" ]]; then
  echo "Error: fix_includes.py script not found!" >&2
  exit 1
fi

echo "Applying IWYU fixes to main.cc..."
python3 "${FIX_INCLUDES_PY}" --noreorder < "${IWYU_REPORT}"

echo "Updated main.cc content:"
cat main.cc

if grep -q "my_header.h" main.cc; then
  echo "Error: Private header was not removed!" >&2
  exit 1
fi

if grep -q "my_header_custom.h" main.cc; then
  echo "Success: Public mapped header was added."
else
  echo "Error: Public mapped header was not added!" >&2
  exit 1
fi

echo "Re-running custom mappings build (should succeed)..."
if ! "${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report \
  --@bazel_iwyu//:iwyu_mappings=//:custom_mappings \
  //...; then
  echo "Error: Build failed after applying custom mapping fix!" >&2
  exit 1
fi

echo "Success: Custom mappings tested successfully."
