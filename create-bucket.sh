#!/bin/bash
set -e
BASE_DIR="$( cd -P "$( dirname "$BASH_SOURCE" )" && pwd -P )"
cd "${BASE_DIR}"

echo "Creating bucket ${S3_BUCKET}"
aws s3api create-bucket --bucket ${S3_BUCKET} --acl private --region ${REGION} --create-bucket-configuration LocationConstraint=${REGION}
aws s3api put-public-access-block --bucket ${S3_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws s3api put-bucket-versioning --bucket ${S3_BUCKET} \
        --versioning-configuration Status=Enabled
