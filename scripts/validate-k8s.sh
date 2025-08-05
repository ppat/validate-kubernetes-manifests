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


mode_output() {
  local msg="$1"
  [[ "$MODE" == "github" ]] && echo "${msg}" || true
}

main() {
  export PATH="${BIN_DIR}:$PATH"
  "${SCRIPT_DIR}"/install-dependencies.sh "${BIN_DIR}"
  "${SCRIPT_DIR}"/fetch-schemas.sh "${SCHEMA_DIR}"
  if (( ${#PRE_FILES[@]} > 0 )); then
    echo "🧪 Pre-build validation (kustomization files only)..."
    mode_output "::group::validate-kustomizations"
    # shellcheck disable=SC2068
    "${SCRIPT_DIR}"/validate-pre.sh ${PRE_FILES[@]} | sed -E 's|^|    |g'
    mode_output echo "::endgroup::"
    echo "✅ Pre-build OK"
  else
    echo "⚠️ Skipping pre-build (no kustomization.yaml files)"
  fi
  echo

  if (( ${#PKG_DIRS[@]} > 0 )); then
    echo "🧪 Post-build validation (resources packaged within each kustomization)..."
    mode_output "::group::validate-resources"
    # shellcheck disable=SC2068
    if "${SCRIPT_DIR}"/validate-post.sh -e "${ENV_FILE}" -b "${BASE_KFILE}" ${PKG_DIRS[@]} | sed -E 's|^|    |g'; then
      mode_output echo "::endgroup::"
      echo "✅ Post-build OK"
    else
      mode_output echo "::endgroup::"
      echo " "
      echo "❌ Validation failed"
      exit 1
    fi
  else
    echo "⚠️ Skipping post-build (no kustomization package dirs)"
  fi
  echo
}

main
