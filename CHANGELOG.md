# Changelog

## [0.1.1](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.1.0...v0.1.1) (2025-07-01)


### 🚀 Enhancements + Bug Fixes

* validation should run on all files and error out afterwards if validation failed in aggregate ([#21](https://github.com/ppat/validate-kubernetes-manifests/issues/21)) ([3c6da45](https://github.com/ppat/validate-kubernetes-manifests/commit/3c6da452a8ad3167e912f025078e4584cd6305db))

## [0.1.0](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.0.2...v0.1.0) (2025-06-30)


### ⚠ BREAKING CHANGES

* given a list of input files discover affected kustomizations to validate ([#16](https://github.com/ppat/validate-kubernetes-manifests/issues/16))

### 🛠 Improvements

* minor updates to docs ([#18](https://github.com/ppat/validate-kubernetes-manifests/issues/18)) ([d5cc3f3](https://github.com/ppat/validate-kubernetes-manifests/commit/d5cc3f383f7bde0975eda5a587294b86ca522fbb))


### ✨ Features

* given a list of input files discover affected kustomizations to validate ([#16](https://github.com/ppat/validate-kubernetes-manifests/issues/16)) ([aa53b01](https://github.com/ppat/validate-kubernetes-manifests/commit/aa53b01bf89f5d3881395bb73b0a7a6077a3a596))

## [0.0.2](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.0.1...v0.0.2) (2025-06-29)


### 🚀 Enhancements + Bug Fixes

* update fluxcd/flux2 (v2.6.2 -&gt; v2.6.3) ([#12](https://github.com/ppat/validate-kubernetes-manifests/issues/12)) ([e1949e9](https://github.com/ppat/validate-kubernetes-manifests/commit/e1949e9e9045a8db87941095915bfb8979f3f4f9))

## 0.0.1 (2025-06-26)


### ✨ Features

* github action + pre-commit hook for validating kubernetes manifests ([#1](https://github.com/ppat/validate-kubernetes-manifests/issues/1)) ([8e3a7a5](https://github.com/ppat/validate-kubernetes-manifests/commit/8e3a7a5d0452b5bca6b71ee0f82f433411d95cdd))


### 🚀 Enhancements + Bug Fixes

* cache all schemas (i.e. default kubeconform schemas, datree crd-catalog schemas), not just flux crd schemas ([#11](https://github.com/ppat/validate-kubernetes-manifests/issues/11)) ([13d3442](https://github.com/ppat/validate-kubernetes-manifests/commit/13d3442989c884bc977ba3cf0f93e156625d404a))
* fix pre-commit hook definition ([#7](https://github.com/ppat/validate-kubernetes-manifests/issues/7)) ([45802fb](https://github.com/ppat/validate-kubernetes-manifests/commit/45802fbfc42e59c9d0d0f5f8a0f377dfb4b6521b))
* pre-commit hook needs to have language set to script, not system ([#10](https://github.com/ppat/validate-kubernetes-manifests/issues/10)) ([d42d80c](https://github.com/ppat/validate-kubernetes-manifests/commit/d42d80c68660128d4aa51acd0b0c31aa8c8547b5))
* relocate script used by pre-commit hook to root ([#9](https://github.com/ppat/validate-kubernetes-manifests/issues/9)) ([75d2c29](https://github.com/ppat/validate-kubernetes-manifests/commit/75d2c2936e0de188c64f37ed25fd8bc9ee1a7e85))
* update released version in README usage examples ([#8](https://github.com/ppat/validate-kubernetes-manifests/issues/8)) ([b1f2e38](https://github.com/ppat/validate-kubernetes-manifests/commit/b1f2e38df0a9ddde72315202b3927d2cc892f476))
