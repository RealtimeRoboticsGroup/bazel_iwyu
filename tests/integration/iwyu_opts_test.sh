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

# Overwrite main.cc to be clean
cat << 'EOF' > main.cc
#include "my_header.h"
void call_func() {
    my_func();
}
EOF

# We pass --verbose=7 inside --@bazel_iwyu//:iwyu_opts
echo "Running build with custom verbose option in iwyu_opts..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report \
  --@bazel_iwyu//:iwyu_opts=--verbose=7 \
  //... || true

IWYU_REPORT=$(find -L bazel-out -name "main.main.cc.iwyu.txt" | head -n 1)
if [[ -z "${IWYU_REPORT}" ]]; then
  echo "Error: IWYU report not found!" >&2
  exit 1
fi

echo "Captured IWYU report (first 20 lines):"
head -n 20 "${IWYU_REPORT}"

# Under --verbose=7, IWYU prints internal diagnostic logs like "Adding", "AST", "Decl"
if grep -qi -E "adding|processing|search|canonical|ast|decl|func|stmt" "${IWYU_REPORT}"; then
  echo "Success: Valid custom option in iwyu_opts (--verbose=7) was successfully passed and active."
else
  echo "Error: Verbose logging output was not found in the IWYU report!" >&2
  exit 1
fi
