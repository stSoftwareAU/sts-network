#!/bin/bash
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

ENV_FILE=".env.properties"
if [[ -f ${ENV_FILE} ]]; then
    source ${ENV_FILE} 
fi

if [[ -z "${DEPARTMENT}" ]] || [[ -z "${AREA}" ]] || [[ -z "${ACCOUNT_ID}" ]] || [[ -z "${ROLE}" ]]; then
  echo "Must specify the follow environment variables DEPARTMENT(${DEPARTMENT}), ACCOUNT_ID(${ACCOUNT_ID}), ROLE(${ROLE}) and AREA(${AREA})"
  exit 1
fi

export DOCKER_TAG=`tr "[:upper:]" "[:lower:]" <<< "${DEPARTMENT}-iac/${BASE_DIR##*/}"`

ASSUME_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE}"

profileArg=""

if [[ ! -z "${PROFILE}" ]]; then
  profileArg=" --profile ${PROFILE}"
fi

TEMP_ROLE=`aws sts assume-role ${profileArg} --role-arn $ASSUME_ROLE_ARN --role-session-name "Deploy_${BASE_DIR##*/}"`

export AWS_ACCESS_KEY_ID=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.SessionToken')

export S3_BUCKET=`echo "${DEPARTMENT}-${AREA}-iac-v4"|tr "[:upper:]" "[:lower:]"`
LIST_BUCKETS=`aws s3api list-buckets`

CreationDate=`jq ".Buckets[]|select(.Name==\"${S3_BUCKET}\").CreationDate" <<< "$LIST_BUCKETS"`
if [[ -z "${CreationDate}" ]]; then
    ./create-bucket.sh
fi
