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
KUSTOMIZE_FLAGS=${KUSTOMIZE_FLAGS:-"--load-restrictor=LoadRestrictionsNone"}
MODE=${MODE:-'none'}
SCHEMA_DIR="${SCHEMA_DIR:-"${HOME}/.cache/kubeconform-schemas"}"

ENV_FILE=""
BASE_KFILE=""


# Parse options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--base-kustomization-file)   BASE_KFILE=$2;          shift 2;;
    -c|--kubeconform-flags)         KUBECONFORM_FLAGS=$2;   shift 2;;
    -d|--schema-dir)                SCHEMA_DIR=$2;          shift 2;;
    -e|--env-file)                  ENV_FILE=$2;            shift 2;;
    -k|--kustomize-flags)           KUSTOMIZE_FLAGS=$2;     shift 2;;
    -h|--help)                      usage;                  exit 0;;
    *)                              POSITIONAL+=("$1");     shift;;
  esac
done
set -- "${POSITIONAL[@]}"
if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  usage
  exit 1
fi

display_validation_status() {
  local files=("$@")
  echo "Validation Results:"
  echo "------------------"
  jq -s -r '.[] | .[] | @tsv' "${files[@]}" | sort | column -t -N 'PATH,KIND,NAME,STATUS,ERROR'
  echo " "
}

aggregate_results() {
  local output_file=$1
  shift
  local files=("$@")

  echo "Aggregating validation results:"
  echo "------------------------------"
  jq -s \
    '{
      summary: (reduce .[].summary as $s
        (
          {"valid":0, "invalid":0, "errors":0, "skipped":0};
          .valid += $s.valid |
          .invalid += $s.invalid |
          .errors += $s.errors |
          .skipped += $s.skipped
        )
      )
    }' \
    "${files[@]}" > "${output_file}"
  cat "${results_dir}/aggregated.json"
  echo " "
}

validate_post() {
  local dirs=("$@")

  # shellcheck disable=SC2155
  local repo_dir="$(pwd)" temp_dir="$(mktemp -d)" env_before_file="$(mktemp)" env_after_file="$(mktemp)"
  local results_dir="${temp_dir}/results"
  mkdir -p "${results_dir}"
  # shellcheck disable=SC2064
  trap "rm -rf ${temp_dir} ${env_before_file} ${env_after_file}" EXIT

  if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    echo "🔧 Using env from $ENV_FILE for envsubst:"
    # Capture environment before loading
    env | sort > "$env_before_file"
    # load environment vars from file
    set -o allexport; source "$ENV_FILE"; set +o allexport
    if $DEBUG; then
      env | sort > "$env_after_file"
      if diff_output=$(diff "$env_before_file" "$env_after_file" 2>/dev/null); then
        echo "(no new environment variables loaded)"
      else
        echo "$diff_output" | grep '^>' | sed 's/^> //'
      fi
      echo " "
    fi | sed -E 's|^|    |g'
  fi

  pushd "${temp_dir}" >/dev/null 2>&1
  if [[ -n "$BASE_KFILE" && -f "${repo_dir}/${BASE_KFILE}" ]]; then
    cp "${repo_dir}/${BASE_KFILE}" kustomization.yaml
  else
    kustomize create
  fi

  local i=0
  for pkg_dir in "${dirs[@]}"; do
    dir="${repo_dir}/${pkg_dir}"
    relative_path="../$(realpath --relative-to="$temp_dir" "$dir")"
    [[ -d "$relative_path" ]] || { echo "✖ Missing dir: $relative_path"; exit 1; }
    kustomize edit add resource "$relative_path"

    local built_kustomization="${results_dir}/built_${i}.yaml"
    local result_file="${results_dir}/result_${i}.json"
    local output_file="${results_dir}/output_${i}.json"

    $DEBUG && >&2 echo "${pkg_dir}: building kustomization..."
    kustomize build . "$KUSTOMIZE_FLAGS" | flux envsubst > "${built_kustomization}"
    $DEBUG && >&2 echo "${pkg_dir}: validating built kustomization..."
    if ! "${SCRIPT_DIR}"/run-kubeconform.sh -c "${KUBECONFORM_FLAGS} -summary" -f json -o "${result_file}" "${built_kustomization}"; then
      $DEBUG && >&2 echo "${pkg_dir}: kubeconform failed!"
    fi

    jq --arg pkg_dir "${pkg_dir}" \
      '[.resources[] | [$pkg_dir, .kind, .name, (.status | sub("status";"")), .msg]]' \
      "${result_file}" > "${output_file}"

    kustomize edit remove resource "$relative_path"
    i=$((i+1))
  done
  popd >/dev/null 2>&1
  echo " "

  # Display individual results for each built kustomization
  display_validation_status "${results_dir}"/output_*.json

  # Aggregate summaries of all individual validation results
  aggregate_results "${results_dir}/aggregated.json" "${results_dir}"/result_*.json

  local invalid_count
  local error_count
  invalid_count=$(jq '.summary.invalid' "${results_dir}/aggregated.json")
  error_count=$(jq '.summary.errors' "${results_dir}/aggregated.json")

  if (( invalid_count > 0 || error_count > 0 )); then
    >&2 echo "Found ${invalid_count} invalid resources and ${error_count} processing errors."
    echo
    return 1
  fi
  echo
  return 0
}

validate_post "${POSITIONAL[@]}"
