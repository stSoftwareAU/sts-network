#!/bin/bash
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

if [[ ! ${ACCOUNT_ALIAS} =~ ^.*production$ ]]; then
    tmpVars=$(mktemp vars_XXXXXX.json)
    jq ".reduced_redundancy=true" IaC/.auto.tfvars.json > ${tmpVars}
    # jq . ${tmpVars} 
    mv ${tmpVars} IaC/.auto.tfvars.json
fi