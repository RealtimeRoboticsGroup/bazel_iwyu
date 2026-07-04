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

# Test each of the three versions
for version in "0.24.0" "0.25.0" "0.26.0"; do
  if [[ "${version}" == "0.24.0" ]]; then
    expected_clang="20"
  elif [[ "${version}" == "0.25.0" ]]; then
    expected_clang="21"
  elif [[ "${version}" == "0.26.0" ]]; then
    expected_clang="22"
  fi

  echo "=================================================="
  echo "Testing IWYU version ${version} (Expecting Clang ${expected_clang})..."
  echo "=================================================="

  # Update MODULE.bazel with the target version
  sed "s|toolchain(version = \"[0-9.]*\")|toolchain(version = \"${version}\")|g" MODULE.bazel > MODULE.bazel.tmp && mv MODULE.bazel.tmp MODULE.bazel

  # Clean the workspace build output for this version run
  "${BIT_BAZEL_BINARY}" \
    --output_user_root="${TEST_TMPDIR}/output_user_root" \
    --bazelrc=/dev/null \
    clean || true

  # Run IWYU build
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

  if grep -q "lib/clang/${expected_clang}" "${WRAPPER_FILE}"; then
    echo "Success: Wrapper script correctly references Clang ${expected_clang}."
  else
    echo "Error: Wrapper script does not reference Clang ${expected_clang}. Version selection failed!" >&2
    exit 1
  fi
done
