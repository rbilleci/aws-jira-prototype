
# Overview

An example of deploying a JIRA and Elasticsearch environment on AWS

# Deployment

Deployment presently requires some manual steps.

#### Step 1 - Create a Bucket

For deploying the infrastructure, you will need to create an Amazon S3 Bucket. 
AWS CloudFormation stores templates in the bucket. 
After creating the bucket, take note of it for the next steps.

#### Step 2 - Install pre-requisites

The following pre-requisites must be installed:
 
* Install Docker
* Install the AWS Command Line Interface: https://aws.amazon.com/cli/

Run **aws configure** and setup the right region and access keys

#### Step 3 - Configure Local Environment

Open a terminal session and set variables used to deploy the AWS CloudFormation templates. 
For **CFN_BUCKET**, enter the bucket name you used in Step 1.
For **CFN_STACK**, enter the AWS CloudFormation stack name you want to use for the environment. 

    CFN_BUCKET=<YOUR BUCKET NAME>
    CFN_STACK=<YOUR STACK NAME>
    CFN_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    CFN_REGION=$(aws configure get region)

#### Step 4 - Deploy the VPC, ECS, and RDS infrastructure 

In the same terminal session, run the following commands.

Create a service linked role for Elasticsearch:

    aws iam create-service-linked-role --aws-service-name es.amazonaws.com

Then create the infrastructure:

    aws cloudformation package --template-file cfn.yaml --output-template packaged.yaml --s3-bucket ${CFN_BUCKET}
    aws cloudformation deploy --template-file packaged.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}

The **package** command packages up the template files and uploads dependencies to S3. The **deploy** command deploys the AWS CloudFormation stack.

#### Step 5 - Create the databases for the application

Next, we will create the MySQL databases required to install the applications and services. 
Perform the following steps:  

1. Login to the AWS Management Console 
2. Navigate to the EC2 Service
3. Select **Instances**
4. Select the checkbox next to the EC2 instance created by ECS.
5. Click on **Connect** and select to open a terminal session using the **Session Manager**
6. Once you are logged into the EC2 instance, run the following commands,
 making sure to replace **USER** and **PASSWORD** with your MySQL user:

        sudo su ec2-user
        mysql -h ${RDS_ENDPOINT_ADDRESS} -u <USER> -p<PASSWORD> -e "CREATE DATABASE IF NOT EXISTS jira CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
7. You can now close the Session Manager session. All deployment following deployment steps will be run from the terminal of your local machine.

#### Step 6 - Build and Deploy JIRA

Set the environment
    
    CFN_SERVICE=jira
   
Build and push the docker image

    aws cloudformation deploy --template-file components/cfn-ecr.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}-${CFN_SERVICE}-ecr --parameter-overrides ServiceName=${CFN_SERVICE} EnvironmentName=${CFN_STACK}
    cd services/${CFN_SERVICE}    
    docker build -t ${CFN_SERVICE} .    
    CFN_TAG=$(docker images ${CFN_SERVICE} -q)
    aws ecr get-login-password --region ${CFN_REGION} | docker login --username AWS --password-stdin ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com
    docker tag ${CFN_TAG} ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com/${CFN_STACK}-${CFN_SERVICE}
    docker push ${CFN_ACCOUNT}.dkr.ecr.${CFN_REGION}.amazonaws.com/${CFN_STACK}-${CFN_SERVICE}
    aws cloudformation package --template-file cfn-service.yaml --output-template packaged.yaml --s3-bucket ${CFN_BUCKET}
    aws cloudformation deploy --template-file packaged.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}-${CFN_SERVICE} --parameter-overrides ServiceName=${CFN_SERVICE} EnvironmentName=${CFN_STACK}
    cd ...

You can now login to JIRA and complete the setup steps.

1. Login to the AWS Management Console 
2. Navigate to CloudFront
3. Get the URL of the distribution
4. Go to the distribution in a web browser and complete the standard JIRA setup steps

It may take some time to complete loading, since JIRA creates the database and file objects the first time it is used.


# Notes on Costs

All deployment options have the following:

* Client VPN with 10 users - 40 hours per week per user
* Monthly data transfer of 100 GB outbound and 100 GB inter-region
* ECS for application deployment, 1x r5a.xlarge (32 GB) 
* Elasticsearch Service uses instances with 64 GB of memory.
* EFS Volume of 100 GB frequently accessed and 1 TB of infrequently accessed data, and a **minimum** provisioned throughput of 10 MB/s
* NAT Gateways (3)
* ALB (3-AZs)
* Team City Server included, but build agents are not

ECS Servers sized for the following:

* 4 GB - JIRA
* 4 GB - TeamCity (Tenant 1)
* 4 GB - TeamCity (Tenant 2)
* 8 GB - Upsource 
* 1 GB - MediaWiki
* 10 BG - reserved for other applications

#### Non-HA deployment with RDS and Elasticsearch using a single AZ
    
* Costs: https://calculator.aws/#/estimate?id=abe514b2eae49e058415c3c725fe1de5a4753b4b
* Costs with reserved instances: https://calculator.aws/#/estimate?id=6d9550cd8c272eed76803331973e368382eac80a

#### HA-deployment with Multi-AZ RDS and Elasticsearch across 3 AZs

* Costs: https://calculator.aws/#/estimate?id=b6f83236d766780156ca7d65a9a0c55d5cf92348
* Costs with reserved instances and using smaller ES instances since we have 3 running: https://calculator.aws/#/estimate?id=327859c4daa72b73c1875995b139ae1cea610cc5


#### Cost Reduction Options:

Based on the following: https://calculator.aws/#/estimate?id=66eaee38f44855524ec49af39e3f0397f25f0cde

* Non HA
* Use Reserved Instance Pricing
* Remove ALB - save costs by routing from CloudFront directly to ECS instances
* Remove NAT Gateways - use VPC Endpoints

Evaluate using lower-memory instance types for Amazon Elasticsearch Service


# Open Tasks

* JIRA email configuration
* Configure Elasticsearch Service Linked Role as CloudFormation resource
* Accessibility of ES
* Upsource
* Media Wiki
* Git Integration
* Teamcity
* Download Server
* Investigate autoscaling of build servers, use of docker
* Perform CloudFront invalidation on deployment
* Merge cfn-ecr template with service template
* Security: Narrow all roles/permissions
* Security: Secure database credentials
* Security: Setup database connection information in parameters, or use a dns name to access it
* Networking: ECS tasks should use **awsvpc** networking mode. See https://aws.amazon.com/blogs/compute/introducing-cloud-native-networking-for-ecs-containers/
* Networking: Remove NAT Gateways for cost-savings
* Networking Attempt to keep ECS hosts in the same region as the active RDS host
* Networking: Configure Client VPN access
* Networking: Change EFS to use security group from service, instead of ECS Security Group
* Networking: Use a different CIDR range in private subnet from public subnet
* Networking: Optimize subnets to be minimum possible size
* Networking: Move from ALB to NLB, using a different port per service	   
* Performance: Configure CPU limits on tasks, such that no task can consume an unfair share of the hosts resources
* Performance: Optimize instance types for ECS and RDS
* Performance: Investigate using separate EFS shares for various sub-directories of application, to optimize use of bursting
* Performance: EFS performance optimization: investigate local caching
    * https://investigate if we can separate where indexes are stored, compared to other data
    * https://rwmj.wordpress.com/2014/05/22/using-lvms-new-cache-feature/
    * https://www.cyberciti.biz/faq/centos-redhat-install-configure-cachefilesd-for-nfs/
* Review lifecycle hook and Load balancers here: https://github.com/aws-samples/ecs-refarch-cloudformation/tree/master/infrastructure




 