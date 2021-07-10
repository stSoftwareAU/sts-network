#!/bin/bash
#
# WARNING: Automatically copied from dga-template
#
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

if [[ -z "${GIT_COMMIT}" ]]; then
  echo "Must specify GIT_COMMIT"
  exit 1
fi

. ./init.sh

ECR="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR}

aws ecr describe-repositories --repository-names ${DOCKER_REPO} || \
    aws ecr create-repository --image-scanning-configuration scanOnPush=true --repository-name ${DOCKER_REPO}

DOCKER_URI="${ECR}/${DOCKER_REPO}"
docker tag ${DOCKER_REPO}:latest ${DOCKER_URI}:${GIT_COMMIT}
docker push ${DOCKER_URI}:${GIT_COMMIT}
