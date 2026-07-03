#!/bin/bash
set -euo pipefail

# Resolve sandbox and setup writable workspace
readonly WRITABLE_WORKSPACE="${TEST_TMPDIR}/writable_workspace"
mkdir -p "${WRITABLE_WORKSPACE}"
cp -RL "${BIT_WORKSPACE_DIR}"/. "${WRITABLE_WORKSPACE}/"
chmod -R +w "${WRITABLE_WORKSPACE}"

PARENT_ROOT=$(realpath "${BIT_WORKSPACE_DIR}/../../..")
sed -i "s|path = \"../../..\"|path = \"${PARENT_ROOT}\"|g" "${WRITABLE_WORKSPACE}/MODULE.bazel"

cd "${WRITABLE_WORKSPACE}"

echo "Running IWYU build..."
"${BIT_BAZEL_BINARY}" \
  --output_user_root="${TEST_TMPDIR}/output_user_root" \
  --bazelrc=/dev/null \
  build \
  --repository_cache="${TEST_TMPDIR}/repository_cache" \
  --aspects @bazel_iwyu//bazel/iwyu:iwyu.bzl%iwyu_aspect \
  --output_groups=report //... || true

# Verify that the CUDA targets were successfully skipped and no reports were generated
CUDA_SIM_REPORTS=$(find -L bazel-out -name "*cuda_sim*.iwyu.txt")
if [[ -n "${CUDA_SIM_REPORTS}" ]]; then
  echo "Error: CUDA targets were not skipped! Found reports:" >&2
  echo "${CUDA_SIM_REPORTS}" >&2
  exit 1
else
  echo "Success: CUDA targets were successfully skipped."
fi

WRAPPER_FILE=$(find -L bazel-out -name "*_wrapper.sh" | head -n 1)
if [[ -z "${WRAPPER_FILE}" ]]; then
  echo "Error: Generated wrapper script not found!" >&2
  exit 1
fi

echo "Found wrapper script: ${WRAPPER_FILE}"
cat "${WRAPPER_FILE}"

if grep -q "lib/clang/20" "${WRAPPER_FILE}"; then
  echo "Success: Wrapper script correctly references Clang 20."
else
  echo "Error: Wrapper script does not reference Clang 20. Version selection failed!" >&2
  exit 1
fi
