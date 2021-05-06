#!/bin/bash

CFN_BUCKET=${CFN_DOMAIN}-template
CFN_STACK=`echo $CFN_DOMAIN | tr . -`
CFN_CERTIFICATE_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName==\`*.${CFN_DOMAIN}\`].CertificateArn" --output text)

echo CFN_BUCKET=$CFN_BUCKET
echo CFN_STACK=$CFN_STACK
echo CFN_CERTIFICATE_ARN=$CFN_CERTIFICATE_ARN

aws iam create-service-linked-role --aws-service-name es.amazonaws.com > /dev/null 2>&1
aws s3 mb s3://$CFN_BUCKET> /dev/null 2>&1
aws cloudformation package --template-file cfn.yaml --output-template packaged.yaml --s3-bucket ${CFN_BUCKET}
aws cloudformation deploy --template-file packaged.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name $CFN_STACK --parameter-overrides CertificateArn=${CFN_CERTIFICATE_ARN}
