#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] <file> ...

Options:
  -c, --kubeconform-flags FLAGS     Flags to pass to kubeconform (default: -skip=Secret)
  -d, --schema-dir DIR              base directory under where schemas are referrenced from
  -f, --output-format FORMAT        Output format (default: pretty)
  -o, --output-file FILE            Output file (default: /dev/stdout)
  -h, --help                        Show this help and exit

Example:
  $(basename "$0") -k '-skip=Secret,IPAddressPool' my.yaml
EOF
}

KUBECONFORM_FLAGS="-skip=Secret"
OUTPUT_FORMAT="pretty"
OUTPUT_FILE="/dev/stdout"
SCHEMA_DIR="${SCHEMA_DIR:-"${HOME}/.cache/kubeconform-schemas"}"

# Parse options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--kubeconform-flags)     KUBECONFORM_FLAGS=$2;   shift 2;;
    -d|--schema-dir)            SCHEMA_DIR=$2;          shift 2;;
    -f|--output-format)         OUTPUT_FORMAT=$2;       shift 2;;
    -o|--output-file)           OUTPUT_FILE=$2;         shift 2;;
    -h|--help)                  usage;                  exit 0;;
    *)                          POSITIONAL+=("$1");     shift;;
  esac
done
set -- "${POSITIONAL[@]}"
if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  usage
  exit 1
fi
FILE="${POSITIONAL[0]}"

FLUX_SCHEMA="${SCHEMA_DIR}/flux-crd-schemas"
KUBECONFORM_SCHEMA="${SCHEMA_DIR}/kubernetes-json-schema/master-standalone-strict/{{.ResourceKind}}{{.KindSuffix}}.json"
DATREE_SCHEMA="${SCHEMA_DIR}/datreeio-CRDs-catalog/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"

BASE_FLAGS=( -strict -ignore-missing-schemas -verbose -output "${OUTPUT_FORMAT}" )
SCHEMA_FLAGS=( -schema-location "$KUBECONFORM_SCHEMA" -schema-location "$FLUX_SCHEMA" -schema-location "$DATREE_SCHEMA" )

# shellcheck disable=SC2068,SC2086
kubeconform ${KUBECONFORM_FLAGS} ${BASE_FLAGS[@]} ${SCHEMA_FLAGS[@]} "${FILE}" > "${OUTPUT_FILE}"
