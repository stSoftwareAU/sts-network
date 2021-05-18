#!/bin/bash
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

. ./init.sh

jq --arg key0   'area' \
   --arg value0 "${AREA}" \
   --arg key1   'region' \
   --arg value1 'ap-southeast-2' \
   '. | .[$key0]=$value0 | .[$key1]=$value1' \
   <<<'{}' > IaC/01_deploy.auto.tfvars.json

store_dir=$(mktemp -d -t tf_XXXXXXXXXX)

s3_store="${S3_BUCKET}/${DOCKER_TAG}/store"

aws s3 cp s3://${s3_store} ${store_dir} --recursive

docker build --tag ${DOCKER_TAG} .

docker run \
    --rm \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    --env AWS_SESSION_TOKEN \
    --volume ${store_dir}:/home/IaC/store \
    ${DOCKER_TAG} \
    apply

aws s3 cp ${store_dir} s3://${s3_store} --recursive

rm -f IaC/01_deploy.auto.tfvars.json
rm -rf ${store_dir}