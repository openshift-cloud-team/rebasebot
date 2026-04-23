#!/bin/bash

set -euo pipefail

REPO_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
CONTAINERFILE="${REPO_ROOT}/Containerfile"
BUILD_ROOT_DOCKERFILE="${REPO_ROOT}/.openshift-ci/Dockerfile.build_root"

command -v perl >/dev/null

usage() {
    echo "Usage: $0 <go-version>" >&2
    echo "Example: $0 1.25.9" >&2
}

if [[ $# -ne 1 ]]; then
    echo "Exactly one Go version argument is required." >&2
    usage
    exit 1
fi

version="${1#go}"

if [[ -z "${version}" ]]; then
    echo "Go version argument cannot be empty." >&2
    usage
    exit 1
fi

requested_go_version="${version}"

perl -0pi -e 's/^ARG GO_VERSION=.*/ARG GO_VERSION='"${version}"'/m' "${CONTAINERFILE}"
perl -0pi -e 's/^ENV GO_VERSION=.*/ENV GO_VERSION='"${version}"'/m' "${BUILD_ROOT_DOCKERFILE}"

container_go_version="$(sed -n 's/^ARG GO_VERSION=//p' "${CONTAINERFILE}")"
build_root_go_version="$(sed -n 's/^ENV GO_VERSION=//p' "${BUILD_ROOT_DOCKERFILE}")"

if [[ "${container_go_version}" != "${requested_go_version}" ]]; then
    echo "GO_VERSION mismatch: expected ${requested_go_version} in ${CONTAINERFILE}, found ${container_go_version}" >&2
    exit 1
fi

if [[ "${build_root_go_version}" != "${requested_go_version}" ]]; then
    echo "GO_VERSION mismatch: expected ${requested_go_version} in ${BUILD_ROOT_DOCKERFILE}, found ${build_root_go_version}" >&2
    exit 1
fi
