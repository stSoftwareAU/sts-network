#!/bin/bash
#
# WARNING: Automatically copied from dga-template
#
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

. ./init.sh

tf_dir=$(mktemp -d -t tf_XXXXXXXXXX)

s3_tf="${S3_BUCKET}/${DOCKER_TAG}"

aws s3 cp s3://${s3_tf} ${tf_dir} --recursive

mkdir -p ${tf_dir}/store
chmod -R ugo+rw ${tf_dir}

docker run \
    --dns 8.8.8.8 \
    --rm \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    --env AWS_SESSION_TOKEN \
    --volume ${tf_dir}/store:/home/IaC/store \
    ${DOCKER_TAG}:latest \
    apply

aws s3 cp ${tf_dir}/store s3://${s3_tf}/store --recursive
