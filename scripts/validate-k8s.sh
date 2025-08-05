#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] file1 file2 ...

A unified script to validate Kubernetes manifests by:
  1) Accepting changed file paths as positional args
  2) Filtering kustomization.yaml files and package dirs via include/exclude globs
  3) Fetching Flux CRD schemas
  4) Running kubeconform and kustomize validations

Options:
  --flux-version VERSION         Flux CLI version (default: 2.6.2)
  --pkg-include JSON             JSON array of glob prefixes to include pkg-dirs (default: ["." ])
  --pkg-exclude JSON             JSON array of glob prefixes to exclude pkg-dirs (default: [])
  --kubeconform-flags FLAGS      Flags to pass to kubeconform (default: -skip=Secret)
  --kustomize-flags FLAGS        Flags to pass to kustomize (default: --load-restrictor=LoadRestrictionsNone)
  --env-file FILE                Env file for post-build (default: none)
  --base-kustomization-file FILE Base kustomization.yaml for post-build (default: none)
  --debug                        Enable debug output
  --github-mode                  Run in Github mode (specialized output when used as a github action)
  -h, --help                     Show this help and exit

Example:
  $(basename "$0") \
    --pkg-include '["apps/*"]' \
    --pkg-exclude '["components/*"]' \
    --kubeconform-flags '-skip=Secret,IPAddressPool' \
    --kustomize-flags '--load-restrictor=LoadRestrictionsNone' \
    --env-file ci/validation/.env \
    --base-kustomization-file ci/validation/kustomization.yaml \
    file1.yaml file2.yaml
EOF
  exit 1
}

# Defaults
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
BIN_DIR="${HOME}/.local/validate-kubernetes-manifests/bin"
export SCHEMA_DIR="${HOME}/.cache/kubeconform-schemas"

export DEBUG=false
export FLUX_VERSION=""
export KUBECONFORM_FLAGS="-skip=Secret"
export KUSTOMIZE_FLAGS="--load-restrictor=LoadRestrictionsNone"
export MODE='none'
INCLUDE_JSON='["."]'
EXCLUDE_JSON='[]'
ENV_FILE=""
BASE_KFILE=""

# Parse options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  # exported variables even if not referrenced within this script, they maybe used by subscripts (even if not explicitly passed)
  case $1 in
    --flux-version)            export FLUX_VERSION=$2;          shift 2;;
    --pkg-include)             INCLUDE_JSON=$2;                 shift 2;;
    --pkg-exclude)             EXCLUDE_JSON=$2;                 shift 2;;
    --kubeconform-flags)       export KUBECONFORM_FLAGS=$2;     shift 2;;
    --kustomize-flags)         export KUSTOMIZE_FLAGS=$2;       shift 2;;
    --env-file)                ENV_FILE=$2;                     shift 2;;
    --base-kustomization-file) BASE_KFILE=$2;                   shift 2;;
    --github-mode)             export MODE='github';            shift;;
    --debug)                   export DEBUG=true;               shift;;
    -h|--help)                 usage;;
    *)                         POSITIONAL+=("$1");              shift;;
  esac
done
set -- "${POSITIONAL[@]}"

# After parsing positional arguments and before "Require at least one file"
FILES=("$@")

# Check if single argument is "." and replace with found kustomization.yaml files
if [[ ${#FILES[@]} -eq 1 && "${FILES[0]}" == "." ]]; then
  mapfile -t FILES < <(find . -type f -name "kustomization.yaml")
fi

# Require at least one file
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Error: no files provided" >&2
  usage
fi

# Parse include/exclude arrays
mapfile -t INCLUDES < <(jq -r '.[]' <<<"$INCLUDE_JSON")
mapfile -t EXCLUDES < <(jq -r '.[]' <<<"$EXCLUDE_JSON")
# Treat default include ["." ] as include-all
for pat in "${INCLUDES[@]}"; do
  [[ "$pat" == "." ]] && INCLUDES=() && break
done

# Derive pre-build files
PRE_FILES=()
for f in "${FILES[@]}"; do
  [[ "$(basename "$f")" == "kustomization.yaml" ]] && PRE_FILES+=("$f")
done

# Derive package dirs from PRE_FILES
PKG_DIRS=()
for f in "${PRE_FILES[@]}"; do
  dir=$(dirname "$f")
  # Remove leading ./ if present for consistent comparison
  dir=${dir#./}

  match=false
  if (( ${#INCLUDES[@]} == 0 )); then
    match=true
  else
    for pat in "${INCLUDES[@]}"; do
      # Remove trailing /* from pattern for directory matching
      pattern=${pat%/*}
      [[ "$dir" == $pattern* ]] && { match=true; break; }
    done
  fi
  $match || continue

  for pat in "${EXCLUDES[@]}"; do
    # Remove trailing /* from pattern for directory matching
    pattern=${pat%/*}
    [[ "$dir" == $pattern* ]] && { match=false; break; }
  done
  $match || continue
  PKG_DIRS+=("$dir")
done

# dedupe - only if PKG_DIRS has elements
if (( ${#PKG_DIRS[@]} > 0 )); then
  readarray -t PKG_DIRS < <(printf '%s\n' "${PKG_DIRS[@]}" | sort -u)
fi


validate_pre() {
  [[ "$MODE" == "github" ]] && echo "::group::validate-kustomizations" || true
  for file in "${PRE_FILES[@]}"; do
    [[ -f "$file" ]] || { echo "✖ Missing file: $file"; exit 1; }
    "${SCRIPT_DIR}"/run-kubeconform.sh -c "${KUBECONFORM_FLAGS}" "${file}" 2>&1
  done
  [[ "$MODE" == "github" ]] && echo "::endgroup::" || true
}

validate_post() {
  [[ "$MODE" == "github" ]] && echo "::group::validate-resources" || true
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
  for pkg_dir in "${PKG_DIRS[@]}"; do
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
  echo "Validation Results:"
  echo "------------------"
  jq -s -r '.[] | .[] | @tsv' "${results_dir}"/output_*.json | sort | column -t -N 'PATH,KIND,NAME,STATUS,ERROR'
  echo " "

  # Aggregate summaries of all individual validation results
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
    "${results_dir}"/result_*.json > "${results_dir}/aggregated.json"
  cat "${results_dir}/aggregated.json"
  echo " "

  local invalid_count
  local error_count
  invalid_count=$(jq '.summary.invalid' "${results_dir}/aggregated.json")
  error_count=$(jq '.summary.errors' "${results_dir}/aggregated.json")

  if (( invalid_count > 0 || error_count > 0 )); then
    >&2 echo "Found ${invalid_count} invalid resources and ${error_count} processing errors."
    [[ "$MODE" == "github" ]] && echo "::endgroup::" || true
    return 1
  fi
  [[ "$MODE" == "github" ]] && echo "::endgroup::" || true
  return 0
}

main() {
  export PATH="${BIN_DIR}:$PATH"
  "${SCRIPT_DIR}"/install-dependencies.sh "${BIN_DIR}"
  "${SCRIPT_DIR}"/fetch-schemas.sh "${SCHEMA_DIR}"
  if (( ${#PRE_FILES[@]} > 0 )); then
    echo "🧪 Pre-build validation (kustomization files only)..."
    validate_pre | sed -E 's|^|    |g'
    echo "✅ Pre-build OK"
  else
    echo "⚠️ Skipping pre-build (no kustomization.yaml files)"
  fi
  echo

  if (( ${#PKG_DIRS[@]} > 0 )); then
    echo "🧪 Post-build validation (resources packaged within each kustomization)..."
    if validate_post | sed -E 's|^|    |g'; then
      echo "✅ Post-build OK"
    else
      echo "❌ Validation failed"
      exit 1
    fi
  else
    echo "⚠️ Skipping post-build (no kustomization package dirs)"
  fi
  echo
}

main
