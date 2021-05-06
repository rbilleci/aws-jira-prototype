#!/bin/bash

BUCKET_NAME=${DOMAIN}-template
CERTIFICATE_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName==\`*.${DOMAIN}\`].CertificateArn" --output text)
STACK_NAME=`echo ${DOMAIN} | tr . -`

echo BUCKET_NAME=${BUCKET_NAME}
echo STACK_NAME=${STACK_NAME}
echo CERTIFICATE_ARN=${CERTIFICATE_ARN}

aws iam create-service-linked-role --aws-service-name es.amazonaws.com > /dev/null 2>&1
aws s3 mb s3://${BUCKET_NAME}> /dev/null 2>&1
aws cloudformation package --template-file template.yaml --output-template template-packaged.yaml --s3-bucket ${BUCKET_NAME}
aws cloudformation deploy --template-file template-packaged.yaml \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --stack-name ${STACK_NAME} \
  --parameter-overrides \
      CertificateArn=${CERTIFICATE_ARN}
