#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] <files> ...

Options:
  -c, --kubeconform-flags FLAGS     Flags to pass to kubeconform (default: -skip=Secret)
  -d, --schema-dir DIR              base directory under where schemas are referrenced from
  -h, --help                        Show this help and exit

Example:
  $(basename "$0") -k '-skip=Secret,IPAddressPool' my.yaml
EOF
}

# Defaults
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
TEMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf ${TEMP_DIR}" EXIT

DEBUG=${DEBUG:-false}
KUBECONFORM_FLAGS=${KUBECONFORM_FLAGS:-"-skip=Secret"}
MODE=${MODE:-'none'}
SCHEMA_DIR="${SCHEMA_DIR:-"${HOME}/.cache/kubeconform-schemas"}"

# Parse options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--kubeconform-flags)     KUBECONFORM_FLAGS=$2;    shift 2;;
    -d|--schema-dir)            SCHEMA_DIR=$2;           shift 2;;
    -h|--help)                  usage;                   exit 0;;
    *)                          POSITIONAL+=("$1");      shift;;
  esac
done
set -- "${POSITIONAL[@]}"
if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  usage
  exit 1
fi

validate_pre() {
  local files=("$@")

  for file in "${files[@]}"; do
    [[ -f "$file" ]] || { echo "✖ Missing file: $file"; exit 1; }
    "${SCRIPT_DIR}"/run-kubeconform.sh -c "${KUBECONFORM_FLAGS}" -d "${SCHEMA_DIR}" "${file}" 2>&1
  done
}

validate_pre "${POSITIONAL[@]}"
