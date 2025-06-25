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

Example (pre-commit):
  $(basename "$0") --flux-version 2.6.2 \
    path/a/kustomization.yaml path/b/x.yaml

Example (GitHub Action):
  $(basename "$0") --flux-version 2.6.2 \
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
FLUX_VERSION="2.6.2"
INCLUDE_JSON='["."]'
EXCLUDE_JSON='[]'
KUBECONFORM_FLAGS="-skip=Secret"
KUSTOMIZE_FLAGS="--load-restrictor=LoadRestrictionsNone"
ENV_FILE=""
BASE_KFILE=""
DEBUG=false
MODE='none'

# Parse options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --flux-version)            FLUX_VERSION=$2;       shift 2;;
    --pkg-include)             INCLUDE_JSON=$2;       shift 2;;
    --pkg-exclude)             EXCLUDE_JSON=$2;       shift 2;;
    --kubeconform-flags)       KUBECONFORM_FLAGS=$2;  shift 2;;
    --kustomize-flags)         KUSTOMIZE_FLAGS=$2;    shift 2;;
    --env-file)                ENV_FILE=$2;           shift 2;;
    --base-kustomization-file) BASE_KFILE=$2;         shift 2;;
    --github-mode)             MODE='github';         shift;;
    --debug)                   DEBUG=true;            shift;;
    -h|--help)                 usage;;
    *)                         POSITIONAL+=("$1");    shift;;
  esac
done
set -- "${POSITIONAL[@]}"

# After parsing positional arguments and before "Require at least one file"
FILES=("$@")
echo "${FILES[@]}"

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
  match=false
  if (( ${#INCLUDES[@]} == 0 )); then
    match=true
  else
    for pat in "${INCLUDES[@]}"; do
      [[ "$dir" == $pat* ]] && { match=true; break; }
    done
  fi
  $match || continue
  for pat in "${EXCLUDES[@]}"; do
    [[ "$dir" == $pat* ]] && { match=false; break; }
  done
  $match || continue
  PKG_DIRS+=("$dir")
done
# dedupe
if (( ${#PKG_DIRS[@]} > 0 )); then
  readarray -t PKG_DIRS < <(printf '%s\n' "${PKG_DIRS[@]}" | sort -u)
else
  PKG_DIRS=()
fi

# Schema cache paths
FLUX_SCHEMA_DIR="${HOME}/.cache/flux-crd-schemas/master-standalone-strict"
FLUX_SCHEMA_PARENT="$(dirname "$FLUX_SCHEMA_DIR")"
DATREE_SCHEMA_LOCATION='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

fetch_schemas() {
  echo "⬇️  Downloading Flux CRD schemas $FLUX_VERSION..."
  mkdir -p "$FLUX_SCHEMA_DIR"
  local tag="$FLUX_VERSION"
  [[ "$tag" != v* ]] && tag="v$tag"
  pushd "${FLUX_SCHEMA_DIR}"
  wget --progress=dot:giga -c "https://github.com/fluxcd/flux2/releases/download/${tag}/crd-schemas.tar.gz" -O /tmp/crd-schemas.tar.gz 2>&1 | sed -E 's|^(.*)|    \1|g'
  tar -xzf /tmp/crd-schemas.tar.gz
  popd
  echo "✅ Saved schemas to $FLUX_SCHEMA_DIR"
}

validate_pre() {
  echo "🧪 Pre-build validation (kustomization files only)..."
  base_flags=( -strict -ignore-missing-schemas -verbose )
  schema_flags=( -schema-location default -schema-location "$FLUX_SCHEMA_PARENT" -schema-location "$DATREE_SCHEMA_LOCATION" )
  for file in "${PRE_FILES[@]}"; do
    [[ -f "$file" ]] || { echo "✖ Missing file: $file"; exit 1; }
    kubeconform "$KUBECONFORM_FLAGS" "${base_flags[@]}" "${schema_flags[@]}" "$file" 2>&1 | sed -E 's|^(.*)|    \1|g'
  done
  echo "✅ Pre-build OK"
}

validate_post() {
  echo "🧪 Post-build validation (resources packaged within each kustomization)..."
  base_flags=( -strict -ignore-missing-schemas -verbose )
  schema_flags=( -schema-location default -schema-location "$FLUX_SCHEMA_PARENT" -schema-location "$DATREE_SCHEMA_LOCATION" )

  # shellcheck disable=SC2155
  local repo_dir="$(pwd)" temp_dir="$(mktemp -d)" env_before_file="$(mktemp)" env_after_file="$(mktemp)"
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
      echo
    fi | sed -E 's|^(.*)|     \1|g'
  fi

  pushd "${temp_dir}" >/dev/null 2>&1
  if [[ -n "$BASE_KFILE" && -f "${repo_dir}/${BASE_KFILE}" ]]; then
    cp "${repo_dir}/${BASE_KFILE}" kustomization.yaml
  else
    kustomize create
  fi
  for pkg_dir in "${PKG_DIRS[@]}"; do
    echo "-> ${pkg_dir}:"
    dir="${repo_dir}/${pkg_dir}"
    relative_path="../$(realpath --relative-to="$temp_dir" "$dir")"
    [[ -d "$relative_path" ]] || { echo "✖ Missing dir: $relative_path"; exit 1; }
    kustomize edit add resource "$relative_path"
    kustomize build . "$KUSTOMIZE_FLAGS" \
      | flux envsubst \
      | kubeconform "$KUBECONFORM_FLAGS" "${base_flags[@]}" "${schema_flags[@]}" 2>&1 | sed -E 's|^(.*)|      \1|g'
    kustomize edit remove resource "$relative_path"
  done
  popd >/dev/null 2>&1
  echo "✅ Post-build OK"
}

main() {
  [[ "$MODE" == "github" ]] && echo "::group::fetch-schemas"
  if [[ ! -d "$FLUX_SCHEMA_DIR" || "$(find "$FLUX_SCHEMA_DIR" -type f -name '*.json' | wc -l)" -eq "0" ]]; then
    fetch_schemas
  fi
  [[ "$MODE" == "github" ]] && echo "::endgroup::"

  [[ "$MODE" == "github" ]] && echo "::group::validate-kustomizations"
  if (( ${#PRE_FILES[@]} > 0 )); then
    validate_pre
  else
    echo "⚠️  Skipping pre-build (no kustomization.yaml files)"
  fi
  [[ "$MODE" == "github" ]] && echo "::endgroup::"
  echo

  [[ "$MODE" == "github" ]] && echo "::group::validate-resources"
  if (( ${#PKG_DIRS[@]} > 0 )); then
    validate_post
  else
    echo "⚠️  Skipping post-build (no kustomization package dirs)"
  fi
  [[ "$MODE" == "github" ]] && echo "::endgroup::"
  echo
}

main
