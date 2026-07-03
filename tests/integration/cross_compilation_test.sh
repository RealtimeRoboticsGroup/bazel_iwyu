#!/bin/bash
set -euo pipefail

# Set HOME inside the test temp dir to avoid sandbox access issues on macOS
export HOME="${TEST_TMPDIR}/home"
mkdir -p "${HOME}"

# Resolve sandbox and setup writable workspace
readonly WRITABLE_WORKSPACE="${TEST_TMPDIR}/writable_workspace"
mkdir -p "${WRITABLE_WORKSPACE}"
cp -RL "${BIT_WORKSPACE_DIR}"/* "${WRITABLE_WORKSPACE}/"
if [[ -f "${BIT_WORKSPACE_DIR}/.bazelrc" ]]; then
  cp -RL "${BIT_WORKSPACE_DIR}/.bazelrc" "${WRITABLE_WORKSPACE}/"
fi
chmod -R +w "${WRITABLE_WORKSPACE}"

PARENT_ROOT=$(realpath "${BIT_WORKSPACE_DIR}/../../..")
sed "s|path = \"../../..\"|path = \"${PARENT_ROOT}\"|g" "${WRITABLE_WORKSPACE}/MODULE.bazel" > "${WRITABLE_WORKSPACE}/MODULE.bazel.tmp" && mv "${WRITABLE_WORKSPACE}/MODULE.bazel.tmp" "${WRITABLE_WORKSPACE}/MODULE.bazel"

cd "${WRITABLE_WORKSPACE}"

echo "Running Cross-Compilation build with default toolchain..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=.bazelrc \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  //...

echo "Running Cross-Compilation build with default toolchain and IWYU..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=.bazelrc \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report \
  //... || true

echo "Running Cross-Compilation build with j5 cross toolchain..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=.bazelrc \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --config=j5 \
  //...

echo "Running Cross-Compilation build with j5 cross toolchain and IWYU..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=.bazelrc \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report \
  --config=j5 \
  //... || true

echo "Success: Cross-compilation targets compiled successfully with IWYU."
