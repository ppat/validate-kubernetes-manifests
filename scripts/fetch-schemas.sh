#!/usr/bin/env bash
set -euo pipefail

TEMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf ${TEMP_DIR}" EXIT
DEBUG=${DEBUG:-false}
MODE=${MODE:-'none'}
GIT_CLONE_FLAGS="$($DEBUG && echo "" || echo "--quiet")"
CURL_FLAGS="$($DEBUG && echo "-fsSLv" || echo "-fsSL")"

count_json_files() {
  local path="$1"
  find "${path}" -type f -name '*.json' 2> /dev/null | wc -l
}

git_clone() {
  local repository="$1"
  local dest="$2"
  local other_params="${3:-""}"
  # shellcheck disable=SC2068,SC2086
  git clone ${GIT_CLONE_FLAGS} ${other_params} --depth 1 "${repository}" "${dest}" 2>&1
}

fetch_default_schemas() {
  local schema_dir=$1
  if [[ "$(count_json_files "${schema_dir}/master-standalone-strict")" -gt "0" ]]; then
    echo "♻️ Using cached schemas..."
    return
  else
    echo "⬇️  Downloading schemas..."
    rm -rf "${schema_dir}"
  fi
  git_clone https://github.com/yannh/kubernetes-json-schema "${schema_dir}" "--filter=blob:none --sparse" | sed -E 's|^|  |g'
  pushd "${schema_dir}" >/dev/null 2>&1
  git sparse-checkout set master-standalone-strict 2>&1 | sed -E 's|^|  |g'
  popd >/dev/null 2>&1
  echo "-> Saved schemas to ${schema_dir}"
}

fetch_flux_schemas() {
  local schema_dir=$1
  local flux_version=${FLUX_VERSION:-"latest"}
  if [[ "$(count_json_files "${schema_dir}/master-standalone-strict")" -gt "0" ]]; then
    echo "♻️ Using cached schemas..."
    return
  else
    echo "⬇️  Downloading schemas..."
    rm -rf "${schema_dir}"
  fi
  local url
  if [[ "${flux_version}" != "latest" ]]; then
    [[ "$flux_version" != v* ]] && flux_version="v$flux_version" || true
    url="https://github.com/fluxcd/flux2/releases/download/${flux_version}/crd-schemas.tar.gz"
  else
    echo "Determining latest flux version..."
    url=$(curl -fsSL https://api.github.com/repos/fluxcd/flux2/releases/latest | jq -r '.assets[] | select(.name == "crd-schemas.tar.gz") | .browser_download_url')
  fi
  mkdir -p "${schema_dir}/master-standalone-strict"
  # shellcheck disable=SC2068,SC2086
  curl ${CURL_FLAGS} -o "${TEMP_DIR}/crd-schemas.tar.gz" "${url}" 2>&1 | sed -E 's|^|  |g'
  pushd "${schema_dir}/master-standalone-strict" >/dev/null 2>&1
  tar -xzf "${TEMP_DIR}/crd-schemas.tar.gz"
  popd >/dev/null 2>&1
  echo "-> Saved schemas to ${schema_dir}"
}

fetch_datree_schemas() {
  local schema_dir=$1
  if [[ "$(count_json_files "${schema_dir}")" -gt "0" ]]; then
    echo "♻️ Using cached schemas..."
    return
  else
    echo "⬇️  Downloading schemas..."
    rm -rf "${schema_dir}"
  fi
  git_clone https://github.com/datreeio/CRDs-catalog "${schema_dir}" | sed -E 's|^|  |g'
  echo "-> Saved schemas to ${schema_dir}"
}

mode_output() {
  local msg="$1"
  [[ "$MODE" == "github" ]] && echo "${msg}" || true
}

main() {
  local schema_cache_dir="$1"
  if [[ -z "${schema_cache_dir}" ]]; then
    echo "Usage: fetch-schemas.sh <schema-cache-dir>"
    exit 1
  fi
  mode_output "::group::fetch-schemas"
  echo "Acquiring default schemas..."
  fetch_default_schemas "${schema_cache_dir}/kubernetes-json-schema" | sed -E 's|^|  |g'
  echo
  echo "Acquiring flux schemas..."
  fetch_flux_schemas "${schema_cache_dir}/flux-crd-schemas" | sed -E 's|^|  |g'
  echo
  echo "Acquiring datree schemas..."
  fetch_datree_schemas "${schema_cache_dir}/datreeio-CRDs-catalog" | sed -E 's|^|  |g'
  mode_output "::endgroup::"
  echo
}

main "$1"
