#!/bin/bash
#
# WARNING: Automatically copied from dga-template
#
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

. ./init.sh

if [[ -f pre-build.sh ]]; then
    ./pre-build.sh
fi 

tf_dir=$(mktemp -d -t tf_XXXXXXXXXX)

s3_tf="${S3_BUCKET}/${DOCKER_TAG}"

aws s3 cp s3://${s3_tf} ${tf_dir} --recursive
chmod -R ugo+rw ${tf_dir}

tmpVars=$(mktemp /tmp/tf-vars.XXXXXX)

if [[ -s ${tf_dir}/config.json ]]; then
    jq ".tfvars//{}" ${tf_dir}/config.json > ${tmpVars} 
else 
    echo "{}" > ${tmpVars}  
fi

jq ".area=\"${AREA}\" | .region=\"${REGION}\" | .department=\"${DEPARTMENT}\"" ${tmpVars} > IaC/.auto.tfvars.json

rm ${tmpVars}

docker build --tag ${DOCKER_TAG}:latest .

rm -r ${tf_dir}
rm -f IaC/.auto.tfvars.json