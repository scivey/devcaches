#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

function pushd() {
    command pushd $@ &> /dev/null
}

function popd() {
    command popd $@ &> /dev/null
}

pushd $(dirname ${BASH_SOURCE[0]})
export DEVCACHES_SCRIPTS=$(pwd)
popd
pushd ${DEVCACHES_SCRIPTS}/..
export DEVCACHES_ROOT=$(pwd)
popd
export DEVCACHES_TEMP=${DEVCACHES_ROOT}/tmp

export PYPICLOUD_DIR=${DEVCACHES_ROOT}/pypi
export PYPICLOUD_CONF_DIR=${PYPICLOUD_DIR}/conf
export PYPICLOUD_DATA_DIR=${PYPICLOUD_DIR}/.db-data


