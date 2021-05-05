#!/bin/bash

# set the parameters
CFN_SERVICE=$1
CFN_BUCKET=${CFN_DOMAIN}-template
CFN_STACK=`echo $CFN_DOMAIN | tr . -`
CFN_CLOUD_FRONT_CERTIFICATE_ARN=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName==\`*.${CFN_DOMAIN}\`].CertificateArn" --output text)
CFN_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
CFN_REGION=$(aws configure get region)
CFN_SERVICE_DOMAIN_NAME=${CFN_SERVICE}.${CFN_DOMAIN}
CFN_VPC=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-vpc\`].Value" --output text)
CFN_LOAD_BALANCER_DOMAIN_NAME=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-alb-domain-name\`].Value" --output text)
CFN_LOAD_BALANCER_ARN=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-alb-arn\`].Value" --output text)
CFN_LISTENER_ARN=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-alb-listener-arn\`].Value" --output text)
CFN_RDS_ENDPOINT_ADDRESS=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-rds-endpoint-address\`].Value" --output text)
CFN_RDS_ID=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-rds-id\`].Value" --output text)
CFN_ECS_SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-ecs-security-group\`].Value" --output text)
CFN_PUBLIC_SUBNETS=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-public-subnets\`].Value" --output text)
CFN_PRIVATE_SUBNETS=$(aws cloudformation list-exports --query "Exports[?Name==\`${CFN_STACK}-private-subnets\`].Value" --output text)


# Print parameters
set | grep CFN_

aws cloudformation deploy --template-file components/cfn-ecr.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}-${CFN_SERVICE}-ecr --parameter-overrides ServiceName=${CFN_SERVICE} EnvironmentName=${CFN_STACK}
cd services/${CFN_SERVICE}
docker build -t ${CFN_SERVICE} .
CFN_TAG=$(docker images ${CFN_SERVICE} -q)
aws ecr get-login-password --region ${CFN_REGION} | docker login --username AWS --password-stdin ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com
docker tag ${CFN_TAG} ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com/${CFN_STACK}-${CFN_SERVICE}
docker push ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com/${CFN_STACK}-${CFN_SERVICE}
aws cloudformation package --template-file cfn-service.yaml --output-template packaged.yaml --s3-bucket ${CFN_BUCKET}
aws cloudformation deploy --template-file packaged.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}-${CFN_SERVICE} --parameter-overrides \
  CloudFrontCertificateArn=${CFN_CLOUD_FRONT_CERTIFICATE_ARN} \
  Cluster=${CFN_STACK} \
  DB=${CFN_RDS_ID} \
  ECSSecurityGroup=${CFN_ECS_SECURITY_GROUP} \
  EnvironmentName=${CFN_STACK} \
  LoadBalancerDomainName=${CFN_LOAD_BALANCER_DOMAIN_NAME} \
  LoadBalancerListenerARN=${CFN_LISTENER_ARN} \
  RDSEndpointAddress=${CFN_RDS_ENDPOINT_ADDRESS} \
  ServiceDomainName=${CFN_SERVICE_DOMAIN_NAME} \
  ServiceName=${CFN_SERVICE} \
  VPC=${CFN_VPC} \
  VPCPrivateSubnets=${CFN_PRIVATE_SUBNETS}

