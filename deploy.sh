#!/bin/bash

CFN_SERVICE=$1
CFN_BUCKET=${CFN_DOMAIN}-template
CFN_STACK=`echo $CFN_DOMAIN | tr . -`
CFN_CLOUDFRONT_CERTIFICATE_ARN=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName==\`*.${CFN_DOMAIN}\`].CertificateArn" --output text)
CFN_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
CFN_REGION=$(aws configure get region)
CFN_SERVICE_DOMAIN_NAME=${CFN_SERVICE}.${CFN_DOMAIN}

echo CFN_STACK=$CFN_STACK
echo CFN_BUCKET=$CFN_BUCKET
echo CFN_SERVICE=$CFN_SERVICE
echo CFN_SERVICE_DOMAIN_NAME=$CFN_SERVICE_DOMAIN_NAME
echo CFN_CLOUDFRONT_CERTIFICATE_ARN=$CFN_CLOUDFRONT_CERTIFICATE_ARN
echo CFN_ACCOUNT=$CFN_ACCOUNT
echo CFN_REGION=$CFN_REGION

aws cloudformation deploy --template-file components/cfn-ecr.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}-${CFN_SERVICE}-ecr --parameter-overrides ServiceName=${CFN_SERVICE} EnvironmentName=${CFN_STACK}
cd services/${CFN_SERVICE}
docker build -t ${CFN_SERVICE} .
CFN_TAG=$(docker images ${CFN_SERVICE} -q)
aws ecr get-login-password --region ${CFN_REGION} | docker login --username AWS --password-stdin ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com
docker tag ${CFN_TAG} ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com/${CFN_STACK}-${CFN_SERVICE}
docker push ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com/${CFN_STACK}-${CFN_SERVICE}
aws cloudformation package --template-file cfn-service.yaml --output-template packaged.yaml --s3-bucket ${CFN_BUCKET}
aws cloudformation deploy --template-file packaged.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}-${CFN_SERVICE} --parameter-overrides CloudFrontCertificateArn=${CFN_CLOUDFRONT_CERTIFICATE_ARN} ServiceDomainName=${CFN_SERVICE_DOMAIN_NAME} ServiceName=${CFN_SERVICE} EnvironmentName=${CFN_STACK}
