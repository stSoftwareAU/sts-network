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

aws ecr describe-repositories --repository-names ${DOCKER_TAG} || \
    aws ecr create-repository --image-scanning-configuration scanOnPush=true --repository-name ${DOCKER_TAG}

REPO="${ECR}/${DOCKER_TAG}"
docker tag ${DOCKER_TAG}:latest ${REPO}:${GIT_COMMIT}
docker push ${REPO}:${GIT_COMMIT}
