# Changelog

## [0.1.8](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.1.7...v0.1.8) (2025-12-16)


### ✨ Features

* update kubernetes-sigs/kustomize (v5.7.1 -&gt; v5.8.0) ([#54](https://github.com/ppat/validate-kubernetes-manifests/issues/54)) ([e02bb9b](https://github.com/ppat/validate-kubernetes-manifests/commit/e02bb9b6b99005edcbe5a42192f8b6b26fd1531b))


### 🚀 Enhancements + Bug Fixes

* update fluxcd/flux2 (v2.7.3 -&gt; v2.7.4) ([#56](https://github.com/ppat/validate-kubernetes-manifests/issues/56)) ([424e623](https://github.com/ppat/validate-kubernetes-manifests/commit/424e623a4475db32186828b225412281d88619ad))
* update fluxcd/flux2 (v2.7.4 -&gt; v2.7.5) ([#57](https://github.com/ppat/validate-kubernetes-manifests/issues/57)) ([4586a0d](https://github.com/ppat/validate-kubernetes-manifests/commit/4586a0d605b072759c3a3622289d42d91254016d))

## [0.1.7](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.1.6...v0.1.7) (2025-11-01)


### 🚀 Enhancements + Bug Fixes

* update fluxcd/flux2 (v2.7.2 -&gt; v2.7.3) ([#51](https://github.com/ppat/validate-kubernetes-manifests/issues/51)) ([1f98987](https://github.com/ppat/validate-kubernetes-manifests/commit/1f98987d94c9eb465cdf061ac22bacca5d9fa416))

## [0.1.6](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.1.5...v0.1.6) (2025-10-21)


### ✨ Features

* update fluxcd/flux2 (v2.6.4 -&gt; v2.7.0) ([#45](https://github.com/ppat/validate-kubernetes-manifests/issues/45)) ([96a9654](https://github.com/ppat/validate-kubernetes-manifests/commit/96a96541b4a330e6af7a4e7ec84319ee42087a71))
* update ppat/renovate-presets (v0.0.4 -&gt; v0.1.0) ([#49](https://github.com/ppat/validate-kubernetes-manifests/issues/49)) ([688b3c7](https://github.com/ppat/validate-kubernetes-manifests/commit/688b3c7978cc643676d4aab6c2d752b672f9e26c))


### 🚀 Enhancements + Bug Fixes

* update fluxcd/flux2 (v2.7.0 -&gt; v2.7.2) ([#46](https://github.com/ppat/validate-kubernetes-manifests/issues/46)) ([ef41951](https://github.com/ppat/validate-kubernetes-manifests/commit/ef419510d1d9d6f135397770f7e0beff77027800))
* update ppat/renovate-presets (v0.0.3 -&gt; v0.0.4) ([#39](https://github.com/ppat/validate-kubernetes-manifests/issues/39)) ([79ee190](https://github.com/ppat/validate-kubernetes-manifests/commit/79ee1907d7ac0cb1ba545a500ec9ab244ff309b7))

## [0.1.5](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.1.4...v0.1.5) (2025-08-05)


### 🚀 Enhancements + Bug Fixes

* remove missed remaining references to variables that are no longer used ([10db072](https://github.com/ppat/validate-kubernetes-manifests/commit/10db0721c7659666a12158a49b2c7cd8f644b783))

## [0.1.4](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.1.3...v0.1.4) (2025-08-05)


### 🚀 Enhancements + Bug Fixes

* remove references to variables that are no longer used ([4472371](https://github.com/ppat/validate-kubernetes-manifests/commit/4472371120d2897387fe5686fca48560e6406626))

## [0.1.3](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.1.2...v0.1.3) (2025-08-05)


### 🚀 Enhancements + Bug Fixes

* extract out validate-pre.sh, validate-post.sh, run-kubeconform.sh, fetch-schemas.sh, install-dependencies.sh into separate scripts ([#32](https://github.com/ppat/validate-kubernetes-manifests/issues/32)) ([990e032](https://github.com/ppat/validate-kubernetes-manifests/commit/990e032f8ee5875fbe6486330c70e3a5c0ffbe1e))

## [0.1.2](https://github.com/ppat/validate-kubernetes-manifests/compare/v0.1.1...v0.1.2) (2025-07-28)


### ✨ Features

* update kubernetes-sigs/kustomize (v5.6.0 -&gt; v5.7.0) ([#23](https://github.com/ppat/validate-kubernetes-manifests/issues/23)) ([6ff0d3c](https://github.com/ppat/validate-kubernetes-manifests/commit/6ff0d3c03cc51e39eca0610480b816e0312ad3e9))


### 🚀 Enhancements + Bug Fixes

* update fluxcd/flux2 (v2.6.3 -&gt; v2.6.4) ([#26](https://github.com/ppat/validate-kubernetes-manifests/issues/26)) ([bd5c8e4](https://github.com/ppat/validate-kubernetes-manifests/commit/bd5c8e432f2474e3840c92c45fdc9cc5d1866ba0))
* update kubernetes-sigs/kustomize (v5.7.0 -&gt; v5.7.1) ([#29](https://github.com/ppat/validate-kubernetes-manifests/issues/29)) ([ad3897e](https://github.com/ppat/validate-kubernetes-manifests/commit/ad3897ee7de13ac976ba6688146e1189f4259e08))

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
