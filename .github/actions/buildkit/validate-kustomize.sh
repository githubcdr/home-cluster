#!/usr/bin/env bash

# This script downloads the Flux OpenAPI schemas, then it validates the
# Flux custom resources and the kustomize overlays using kubeval.
# This script is meant to be run locally and in CI before the changes
# are merged on the main branch that's synced by Flux.

# Copyright 2020 The Flux authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is meant to be run locally and in CI to validate the Kubernetes
# manifests (including Flux custom resources) before changes are merged into
# the branch synced by Flux in-cluster.

# Prerequisites
# - yq v4.6
# - kustomize v4.1
# - kubeval v0.15.x

set -o errexit

if [ ! -d /tmp/flux-crd-schemas/master-standalone-strict/ ]; then
  echo "INFO - Downloading Flux OpenAPI schemas"
  mkdir -p /tmp/flux-crd-schemas/master-standalone-strict
  curl -sL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C /tmp/flux-crd-schemas/master-standalone-strict
fi

# mirror kustomize-controller build options
kustomize_flags="--load-restrictor=LoadRestrictionsNone --reorder=legacy"
kustomize_config="kustomization.yaml"

# find . -path ./.secrets -prune -o -type f -name '*.yaml' -print0 | grep -vz .sops.yaml |  while IFS= read -r -d $'\0' file;
#   do
#     echo "INFO - Validating $file"
#     yq e 'true' "$file" > /dev/null
# done

echo "INFO - Validating kustomize overlays"
find ./k8s/ -path ./.secrets -prune -o -type f -name $kustomize_config -print0 |  while IFS= read -r -d $'\0' file;
  do
    echo "INFO - Validating kustomization ${file/%$kustomize_config}"
    # Secrets are ignored with --skip-kinds due to using SOPS with FluxCD
    # shellcheck disable=SC2086
    kustomize build "${file/%$kustomize_config}" $kustomize_flags | kubeval --ignore-missing-schemas --strict --additional-schema-locations=file:///tmp/flux-crd-schemas --skip-kinds Secret
    if [[ ${PIPESTATUS[0]} != 0 ]]; then
      exit 1
    fi
done

echo "INFO - Finished"
