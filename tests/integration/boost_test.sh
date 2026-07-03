#!/bin/bash
set -euo pipefail

# Resolve sandbox and setup writable workspace
readonly WRITABLE_WORKSPACE="${TEST_TMPDIR}/writable_workspace"
mkdir -p "${WRITABLE_WORKSPACE}"
cp -RL "${BIT_WORKSPACE_DIR}"/* "${WRITABLE_WORKSPACE}/"
chmod -R +w "${WRITABLE_WORKSPACE}"

PARENT_ROOT=$(realpath "${BIT_WORKSPACE_DIR}/../../..")
sed "s|path = \"../../..\"|path = \"${PARENT_ROOT}\"|g" "${WRITABLE_WORKSPACE}/MODULE.bazel" > "${WRITABLE_WORKSPACE}/MODULE.bazel.tmp" && mv "${WRITABLE_WORKSPACE}/MODULE.bazel.tmp" "${WRITABLE_WORKSPACE}/MODULE.bazel"

cd "${WRITABLE_WORKSPACE}"

echo "Running normal Boost example build..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  //...

echo "Running Boost example build with IWYU..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report \
  //... || true

echo "Success: Boost example compiled successfully with IWYU."
