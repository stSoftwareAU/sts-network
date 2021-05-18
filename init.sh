#!/bin/bash
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

source environment.properties
export DOCKER_TAG="dta-iac/jenkins-pipeline"

ASSUME_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE}"

TEMP_ROLE=`aws sts assume-role --role-arn $ASSUME_ROLE_ARN --role-session-name "Deploy-pipeline"`

export AWS_ACCESS_KEY_ID=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "${TEMP_ROLE}" | jq -r '.Credentials.SessionToken')

export S3_BUCKET=`echo "${DEPARTMENT}-${AREA}-v4"|tr "[:upper:]" "[:lower:]"`
LIST_BUCKETS=`aws s3api list-buckets`

CreationDate=`jq ".Buckets[]|select(.Name==\"${S3_BUCKET}\").CreationDate" <<< "$LIST_BUCKETS"`
if [[ -z "${CreationDate}" ]]; then

    aws s3api create-bucket --bucket ${S3_BUCKET} --acl private --region ${REGION} --create-bucket-configuration LocationConstraint=${REGION}
    aws s3api put-public-access-block --bucket ${S3_BUCKET} \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    aws s3api put-bucket-versioning --bucket ${S3_BUCKET} \
         --versioning-configuration Status=Enabled
fi
