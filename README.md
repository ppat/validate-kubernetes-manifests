# Validate Kubernetes Manifests

A GitHub Action and pre-commit hook for comprehensive Kubernetes manifest validation, supporting both raw files and kustomize packages with multiple schema sources.

## Features

- **Dual Interface**: Available as both GitHub Action and pre-commit hook
- **Multiple Schema Sources**: Validates against Kubernetes core, Flux CRDs, and community schemas
- **Two-Stage Validation**: Raw manifest syntax checking plus built package validation
- **Flexible Content Selection**: Configurable include/exclude patterns for targeted validation
- **GitOps Ready**: Built-in support for Flux workflows and environment substitution

## Quick Start

### GitHub Action Usage

```yaml
# .github/workflows/validate-k8s.yaml
name: Validate Kubernetes Manifests

on:
  pull_request:
    paths: ['**/*.yaml', '**/*.yml']

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      files: ${{ steps.prepare-files.outputs.files }}
    steps:
    - uses: actions/checkout@v4

    - name: Get changed files
      id: changed
      uses: tj-actions/changed-files@v46
      with:
        files: '**/*.{yaml,yml}'

    - name: Prepare files JSON
      id: prepare-files
      run: |
        ALL=(${{ steps.changed.outputs.all_changed_files }})
        printf '%s\n' "${ALL[@]}" | jq -R . | jq -s -c . > files.json
        echo "files=$(cat files.json)" >> $GITHUB_OUTPUT

  validate:
    needs: detect-changes
    if: needs.detect-changes.outputs.files != '[]'
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Validate Kubernetes Manifests
      uses: ppat/validate-kubernetes-manifests@v0.1.1 # x-release-please-version
      with:
        files: ${{ needs.detect-changes.outputs.files }}
        pkg-include: '["apps/*", "infrastructure/*"]'
        pkg-exclude: '["components/*"]'
```

### Pre-commit Hook Usage

```yaml
# .pre-commit-config.yaml
repos:
- repo: https://github.com/ppat/validate-kubernetes-manifests
  rev: v0.1.1 # x-release-please-version
  hooks:
  - id: validate-k8s
    args:
    - --pkg-include
    - '["apps/*","infrastructure/*"]'
    - --pkg-exclude
    - '["components/*"]'
```

## Configuration Options

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `flux-version` | Flux CLI version for CRD schemas | `2.6.2` | `2.6.2` |
| `files` | JSON array of file paths (Action only) | `[]` | `["apps/media/plex/kustomization.yaml"]` |
| `pkg-include` | Glob patterns for including directories | `["."]` | `["apps/*"]` |
| `pkg-exclude` | Glob patterns for excluding directories | `[]` | `["test/*"]` |
| `kubeconform-flags` | Additional kubeconform flags | `-skip=Secret` | `-skip=Secret,ConfigMap` |
| `kustomize-flags` | Additional kustomize flags | `--load-restrictor=LoadRestrictionsNone` | `--enable-helm` |
| `env-file` | Environment file for variable substitution | _none_ | `ci/.env` |
| `base-kustomization-file` | Base kustomization for post-build | _none_ | `ci/kustomization.yaml` |
| `debug` | Enable debug output | `false` | `true` |

## How It Works

### Schema Sources

The validation uses multiple schema sources for comprehensive coverage:

- **Default Kubernetes schemas**: Built-in kubeconform schemas for core K8s resources (Pod, Service, Deployment, etc.)
- **Flux CRD schemas**: Custom Resource Definitions from the specified Flux version
- **Datree CRD catalog**: Community-maintained schemas from [datreeio/CRDs-catalog](https://github.com/datreeio/CRDs-catalog) covering popular operators and tools

### Validation Stages

**Pre-build Validation**: Validates raw `kustomization.yaml` files directly as they exist in the repository. This catches syntax errors, invalid field names, and structural issues in kustomization configurations before any processing occurs.

**Post-build Validation**: Executes `kustomize build` on each package directory to generate the final Kubernetes manifests, then validates all resulting resources. This stage:

1. Builds the complete resource set from kustomizations (including patches, generators, transformers)
2. Applies Flux environment variable substitution via `flux envsubst` to resolve `${VAR_NAME}` placeholders
3. Validates every generated resource (not just kustomizations) against all available schemas

The post-build stage is crucial because it validates the actual manifests that would be applied to a cluster, including all transformations and variable substitutions.

### Validation Process Flow

1. **File Filtering**: Identifies `kustomization.yaml` files from input file paths
2. **Content Discovery**: Maps kustomization files to package directories using include/exclude patterns
3. **Schema Download**: Fetches and caches Flux CRD schemas for the specified version
4. **Pre-build Validation**: Validates raw `kustomization.yaml` files with kubeconform
5. **Post-build Validation**: Builds each package with kustomize, applies Flux envsubst, and validates all generated resources

### Content Identification Logic

The script determines what to validate based on input parameters and file types:

**Pre-build Content**: All `kustomization.yaml` files from the input file list are validated directly.

**Post-build Content**: Package directories containing `kustomization.yaml` files are filtered using include/exclude patterns, then each package is built and validated:

```bash
# Include all directories by default
--pkg-include='["."]'

# Include only specific paths
--pkg-include='["apps/*", "infrastructure/*"]'

# Exclude test directories and components
--pkg-exclude='["test/*", "examples/*", "components/*"]'
```

**Important**: Kustomize `components` directories must always be excluded from post-build validation as they are not standalone packages and cannot be built independently.

**Example Structure**:

```
repo/
├── apps/
│   ├── frontend/kustomization.yaml     # ✅ Pre + Post validation
│   └── backend/kustomization.yaml      # ✅ Pre + Post validation
├── infrastructure/
│   └── postgres/kustomization.yaml     # ✅ Pre + Post validation
├── components/
│   └── monitoring/kustomization.yaml   # ✅ Pre-build only (excluded from post-build)
└── test/
    └── mock/kustomization.yaml         # ✅ Pre-build only (excluded from post-build)
```

## Advanced Usage

### Environment Variable Substitution

Post-build validation supports Flux-style environment variable substitution. After `kustomize build` generates manifests, `flux envsubst` processes `${VAR_NAME}` placeholders before validation.

**Setup with env-file**:

```bash
# ci/validation/.env
CLUSTER_NAME=staging
NAMESPACE=default
REPLICA_COUNT=3
```

```yaml
# ci/validation/kustomization.yaml (base kustomization)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# resources: []  do not set resources field, it's populated dynamically during validation
# for example, if you have configmap that fails validation due to its content
patches:
- patch: |-
    $patch: delete
    kind: ConfigMap
    metadata:
      name: irrelevant
  target:
    kind: ConfigMap
    name: your-configmap-name
```

**GitHub Action Configuration**:

```yaml
- uses: ppat/validate-kubernetes-manifests
  with:
    env-file: 'ci/validation/.env'
    base-kustomization-file: 'ci/validation/kustomization.yaml'
```

**Pre-commit Configuration**:

```yaml
repos:
- repo: https://github.com/ppat/validate-kubernetes-manifests
  hooks:
  - id: validate-k8s
    args:
    - --env-file=ci/validation/.env
    - --base-kustomization-file=ci/validation/kustomization.yaml
```

The base kustomization file allows you to modify the kustomize build output before validation by applying patches, removing resources that shouldn't be validated, or adding transformations needed for the validation context.

**Example Substitution**:

```yaml
# Original manifest after kustomize build
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: ${NAMESPACE}  # Will be substituted
spec:
  replicas: ${REPLICA_COUNT}  # Will be substituted

# After flux envsubst (with values from ci/validation/.env)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: default
spec:
  replicas: 3
```

### Repository-wide Validation

Pass `.` as the file argument to validate all `kustomization.yaml` files recursively:

**Pre-commit example**:

```yaml
- id: validate-k8s
  args: [.]
```

This discovers and validates all kustomization.yaml files in the repository.

## Dependencies

The script requires these tools to be available. While they are automatically installed by the github-action, the pre-commit hook does not, so you will need to pre-install them in your local environment.

- `kubeconform` - Kubernetes manifest validation
- `kustomize` - Kubernetes native configuration management
- `flux` - GitOps toolkit CLI
- `jq` - JSON processor
- `wget` - File downloader

## Troubleshooting

### Debug Mode

Enable detailed output to troubleshoot issues:

```yaml
- uses: ppat/validate-kubernetes-manifests
  with:
    debug: 'true'
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test with both GitHub Actions and pre-commit scenarios
4. Submit a pull request

## License

MIT License
