
#### Step 1 - Create a Bucket

For deploying the infrastructure, you will need to create an Amazon S3 Bucket. 
AWS CloudFormation stores templates in the bucket. 
After creating the bucket, take note of it for the next steps.

#### Step 2 - Install the AWS CLI in your Local Environment

Install the AWS Command Line Interface: https://aws.amazon.com/cli/

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
The **package** command packages up the template files and uploads dependencies to S3
The **deploy** command deploys the AWS CloudFormation stack.

    aws cloudformation package --template-file cfn.yaml --output-template packaged.yaml --s3-bucket ${CFN_BUCKET}
    aws cloudformation deploy --template-file packaged.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}

#### Step 5 - Create the databases for the application

Next, we will create the MySQL databases required to install the applications and services. 
Perform the following steps:  

1. Login to the AWS Management Console 
2. Navigate to the EC2 Service
3. Select **Instances**
4. Select the checkbox next to the EC2 instance created by ECS.
5. Click on **Connect** and select to open a terminal session using the AWS Systems Manager
6. Once you are logged into the EC2 instance, run the following commands:



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
    aws cloudformation deploy --template-file cfn-service.yaml --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name ${CFN_STACK}-${CFN_SERVICE} --parameter-overrides ServiceName=${CFN_SERVICE} EnvironmentName=${CFN_STACK}
    cd ...

# Notes on Costs

* EFS Volume of 100 GB frequently accessed and 1 TB of infrequently accessed data, and a **minimum** provisioned throughput of 10 MB/s
* RDS (single vs multi-az)
* NAT Gateways
* ALB
* Option: Route53 for load balancing from CloudFront to Services
* File transfer (lambda, aws transfer, aws batch)
* site-to-site VPN

# Open Tasks

* Elasticsearch
* Upsource
* Media Wiki
* Git Integration
* Teamcity
* JIRA email notifications
* Download Server
* Remove NAT Gateways for cost-savings
* Networking: Configure Client VPN access
* Networking: ECS tasks should use **awsvpc** networking mode. See https://aws.amazon.com/blogs/compute/introducing-cloud-native-networking-for-ecs-containers/
* Networking: Change EFS to use security group from service, instead of ECS Security Group
* Networking: Use a different CIDR range in private subnet from public subnet
* Networking: Optimize subnets to be minimum possible size
* Networking: Move from ALB to NLB, using a different port per service
* Optimize instance types for ECS and RDS
* Configure CPU limits on tasks, such that no task can consume an unfair share of the hosts resources
* Narrow all roles/permissions
* Attempt to keep ECS hosts in the same region as the active RDS host
* Secure database credentials
* Review lifecycle hook and Load balancers here: https://github.com/aws-samples/ecs-refarch-cloudformation/tree/master/infrastructure
* Investigate autoscaling of build servers, use of docker
* Fix collation for JIRA database
* Perform CloudFront invalidation on deployment
* EFS performance optimization: investigate local caching
    * https://investigate if we can separate where indexes are stored, compared to other data
    * https://rwmj.wordpress.com/2014/05/22/using-lvms-new-cache-feature/
    * https://www.cyberciti.biz/faq/centos-redhat-install-configure-cachefilesd-for-nfs/
	   





 