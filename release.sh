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

EXT=`date "+%Y%m%d%H%M%S"`

ECR="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR}

REPO="${ECR}/${DOCKER_TAG}"

docker pull ${REPO}:${GIT_COMMIT}

docker tag ${REPO}:${GIT_COMMIT} \
           ${REPO}:${AREA}_${EXT}

docker push ${REPO}:${AREA}_${EXT}

docker tag ${REPO}:${GIT_COMMIT} \
           ${REPO}:${AREA}

docker push ${REPO}:${AREA}
