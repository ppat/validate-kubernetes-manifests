#!/usr/bin/env bash
set -euo pipefail

TEMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf ${TEMP_DIR}" EXIT
DEBUG=${DEBUG:-false}
MODE=${MODE:-'none'}
CURL_FLAGS="$($DEBUG && echo "-fsSLv" || echo "-fsSL")"


install_from_url() {
  local url="$1"
  local executable="$2"
  local dest_dir="$3"

}

install_from_github_release_asset() {
  local repository="$1"
  local version="$2"
  local asset="$3"
  local dest_dir="$4"
  local executable="$5"
  local url="https://github.com/${repository}/releases/download/${version}/${asset}"
  if [[ -f "${dest_dir}/${executable}" ]]; then
    echo "♻️ Using cached binary..."
    return
  else
    echo "⬇️  Downloading executable..."
  fi
  # shellcheck disable=SC2068,SC2086
  curl ${CURL_FLAGS} -o "${TEMP_DIR}/${asset}" "${url}" 2>&1 | sed -E 's|^|  |g'
  cd "${TEMP_DIR}/"
  tar -xzf "${asset}"
  ls -al
  mv "${executable}" "${dest_dir}/${executable}"
  chown "${USER}" "${dest_dir}/${executable}"
  chmod 755 "${dest_dir}/${executable}"
  echo "-> ${dest_dir}/${executable}"
}

mode_output() {
  local msg="$1"
  [[ "$MODE" == "github" ]] && echo "${msg}" || true
}

main() {
  local dest_dir="$1"
  mkdir -p "${dest_dir}"

  mode_output "::group::install-dependencies"
  echo "Install kubeconform ${KUBECONFORM_VERSION}..."
  install_from_github_release_asset yannh/kubeconform "${KUBECONFORM_VERSION}" kubeconform-linux-amd64.tar.gz "${dest_dir}" kubeconform
  echo
  echo "Install kustomize ${KUSTOMIZE_VERSION}..."
  install_from_github_release_asset kubernetes-sigs/kustomize "kustomize%2F${KUSTOMIZE_VERSION}" "kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" "${dest_dir}" kustomize
  echo
  echo "Install flux ${FLUX_VERSION}..."
  install_from_github_release_asset fluxcd/flux2 "${FLUX_VERSION}" "flux_${FLUX_VERSION#v}_linux_amd64.tar.gz" "${dest_dir}" flux
  mode_output "::endgroup::"
  echo

  mode_output "::group::cli-versions"
  echo "Checking CLI versions..."
  echo
  export PATH="${dest_dir}:$PATH"
  kustomize version
  kubeconform -v
  flux -v
  mode_output "::endgroup::"
  echo
}

main "$1"
