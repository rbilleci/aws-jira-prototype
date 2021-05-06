#!/bin/bash

# Determine service and environment
SERVICE_NAME=$1
STACK_NAME=`echo ${DOMAIN} | tr . -`

# Set Variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ALB_ARN=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-alb-arn\`].Value" --output text)
ALB_DOMAIN_NAME=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-alb-domain-name\`].Value" --output text)
ALB_LISTENER_ARN=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-alb-listener-arn\`].Value" --output text)
BUCKET_NAME=${DOMAIN}-template
CERTIFICATE_ARN=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName==\`*.${DOMAIN}\`].CertificateArn" --output text)
ECS_SECURITY_GROUP=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-ecs-security-group\`].Value" --output text)
PUBLIC_SUBNETS=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-public-subnets\`].Value" --output text)
PRIVATE_SUBNETS=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-private-subnets\`].Value" --output text)
RDS_ENDPOINT_ADDRESS=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-rds-endpoint-address\`].Value" --output text)
RDS_ID=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-rds-id\`].Value" --output text)
REGION=$(aws configure get region)
SERVICE_DOMAIN_NAME=${SERVICE_NAME}.${DOMAIN}
VPC=$(aws cloudformation list-exports --query "Exports[?Name==\`${STACK_NAME}-vpc\`].Value" --output text)

# ECR: deploy the repository
DOCKER_REPOSITORY=${SERVICE_NAME}
DOCKER_REGISTRY=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
TIMESTAMP=`date +%s`
aws cloudformation deploy --template-file components/cfn-ecr.yaml \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --stack-name ${STACK_NAME}-${SERVICE_NAME}-ecr \
  --parameter-overrides RepositoryName=${DOCKER_REPOSITORY}

# ECR: build and tag the image locally
# use a unique local tag based on the timestamp, but the image id as the tag for remote deployment
cd services/${SERVICE_NAME}
docker build -t ${DOCKER_REPOSITORY}:${TIMESTAMP} .
TAG=$(docker images ${DOCKER_REPOSITORY}:${TIMESTAMP} -q)

# ECR: tag and push the image
docker tag ${DOCKER_REPOSITORY}:${TIMESTAMP} ${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}:${TAG}
docker tag ${DOCKER_REPOSITORY}:${TIMESTAMP} ${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}:latest
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}
docker push ${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}:${TAG}
docker push ${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}:latest

# Deploy the CloudFormation template for the service
aws cloudformation package --template-file template.yaml \
  --output-template template-packaged.yaml \
  --s3-bucket ${BUCKET_NAME}

aws cloudformation deploy --template-file template-packaged.yaml \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --stack-name ${STACK_NAME}-${SERVICE_NAME} \
  --parameter-overrides \
      CloudFrontCertificateArn=${CERTIFICATE_ARN} \
      Cluster=${STACK_NAME} \
      DB=${RDS_ID} \
      ECSSecurityGroup=${ECS_SECURITY_GROUP} \
      EnvironmentName=${STACK_NAME} \
      LoadBalancerDomainName=${ALB_DOMAIN_NAME} \
      LoadBalancerListenerARN=${ALB_LISTENER_ARN} \
      RDSEndpointAddress=${RDS_ENDPOINT_ADDRESS} \
      ServiceDomainName=${SERVICE_DOMAIN_NAME} \
      ServiceImage=${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}:${TAG} \
      ServiceName=${SERVICE_NAME} \
      VPC=${VPC} \
      VPCPrivateSubnets=${PRIVATE_SUBNETS}

