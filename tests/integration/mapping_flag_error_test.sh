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

# We pass --@bazel_iwyu//:iwyu_opts=--mapping_file=dummy.imp
# This should trigger the fail() assertion during the analysis phase.
echo "Running build with invalid iwyu_opts mapping flag..."
stderr_log="${TEST_TMPDIR}/stderr.log"

"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report \
  --@bazel_iwyu//:iwyu_opts=--mapping_file=dummy.imp \
  //... > /dev/null 2> "${stderr_log}" || true

echo "Captured build stderr:"
cat "${stderr_log}"

if grep -q "Do not put mapping files in iwyu_opts" "${stderr_log}"; then
  echo "Success: Aspect successfully rejected mapping file inside iwyu_opts."
else
  echo "Error: Build did not fail with the expected error message!" >&2
  exit 1
fi
