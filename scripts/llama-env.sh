#!/usr/bin/env bash
set -euo pipefail

export ROCM_PATH="/opt/therock-gfx1011-10.0.0"
export BC160_ROCBLAS_PREFIX="/opt/therock-gfx1011-llama/install"
export CMAKE_PREFIX_PATH="${BC160_ROCBLAS_PREFIX}:${ROCM_PATH}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"

# Prefer isolated rocBLAS first, then TheRock runtime libraries.
for d in \
  "${BC160_ROCBLAS_PREFIX}/lib" \
  "${BC160_ROCBLAS_PREFIX}/lib64" \
  "${ROCM_PATH}/lib" \
  "${ROCM_PATH}/lib64"; do
  if [[ -d "$d" ]]; then
    export LD_LIBRARY_PATH="$d${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  fi
done

unset HSA_OVERRIDE_GFX_VERSION || true

cat <<MSG
ROCM_PATH=$ROCM_PATH
BC160_ROCBLAS_PREFIX=$BC160_ROCBLAS_PREFIX
CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH
LD_LIBRARY_PATH=$LD_LIBRARY_PATH
HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION-<unset>}
MSG
