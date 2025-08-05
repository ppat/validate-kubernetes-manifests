#!/usr/bin/env bash
set -euo pipefail

TEMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf ${TEMP_DIR}" EXIT
DEBUG=${DEBUG:-false}
MODE=${MODE:-'none'}
CURL_FLAGS="$($DEBUG && echo "-fsSLv" || echo "-fsSL")"


determine_url() {
  local repository="$1"
  local version_pattern="$2"
  local asset_pattern="$3"
  local output
  output="$(mktemp -p "${TEMP_DIR}")"
  # shellcheck disable=SC2068,SC2086
  curl ${CURL_FLAGS} "https://api.github.com/repos/${repository}/releases" -o "${output}"
  jq -r \
    --arg version_pattern "$version_pattern" \
    --arg asset_pattern "$asset_pattern" \
    '[.[] | select(.name | test($version_pattern)) | .assets[] | select(.name | test($asset_pattern)) | .browser_download_url] | sort | .[-1]' \
    "${output}"
}

install_from_github_release_asset() {
  local repository="$1"
  local version_pattern="$2"
  local asset_pattern="$3"
  local dest_dir="$4"
  local executable="$5"
  local url
  local asset
  if [[ -f "${dest_dir}/${executable}" ]]; then
    echo "♻️ Using cached binary..."
    return
  else
    echo "⬇️  Downloading executable..."
  fi
  echo "Determining url for ${version_pattern}..."
  url="$(determine_url "${repository}" "${version_pattern}" "${asset_pattern}")"
  asset="$(basename "${url}")"
  # shellcheck disable=SC2068,SC2086
  curl ${CURL_FLAGS} -o "${TEMP_DIR}/${asset}" "${url}" 2>&1 | sed -E 's|^|    |g'
  cd "${TEMP_DIR}/"
  tar -xzf "${asset}"
  mv "${executable}" "${dest_dir}/${executable}"
  chown "${USER}" "${dest_dir}/${executable}"
  chmod 755 "${dest_dir}/${executable}"
  echo "-> ${dest_dir}/${executable}"
}

mode_output() {
  local msg="$1"
  [[ "$MODE" == "github" ]] && echo "${msg}" || true
}

install_dependencies() {
  echo "Installing kubeconform..."
  install_from_github_release_asset yannh/kubeconform "${KUBECONFORM_VERSION:-".*"}" 'kubeconform-linux-amd64\.tar\.gz' "${dest_dir}" kubeconform | sed -E 's|^|    |g'
  echo
  echo "Installing flux..."
  install_from_github_release_asset fluxcd/flux2 "${FLUX_VERSION:-".*"}" 'flux_.*_linux_amd64\.tar\.gz' "${dest_dir}" flux | sed -E 's|^|    |g'
  echo
  echo "Installing kustomize..."
  install_from_github_release_asset kubernetes-sigs/kustomize "kustomize/${KUSTOMIZE_VERSION:-".*"}" 'kustomize_.*_linux_amd64\.tar\.gz' "${dest_dir}" kustomize | sed -E 's|^|    |g'
}

show_versions() {
  echo "Checking CLI versions..."
  kustomize version | sed -E 's|^|    |g'
  kubeconform -v | sed -E 's|^|    |g'
  flux -v | sed -E 's|^|    |g'
}

main() {
  local dest_dir="$1"
  mkdir -p "${dest_dir}"

  mode_output "::group::install-dependencies"
  install_dependencies
  mode_output "::endgroup::"
  echo

  mode_output "::group::cli-versions"
  show_versions
  mode_output "::endgroup::"
  echo
}

main "$1"
