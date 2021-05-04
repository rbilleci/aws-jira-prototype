# Overview

The project offers an AWS CloudFormation template that demonstrates how to deploy development infrastructure to AWS,
that includes:

- JIRA
- TeamCity
- Upsource
- Mediawiki
- ElasticSearch Service


# Deployment Steps


## Step 1 - Install pre-requisites

The following pre-requisites must be installed on the machine you run the installation from:

* AWS Command Line Interface: https://aws.amazon.com/cli/
* Docker

Run **aws configure** and set the region you'll deploy the applications to and access keys.

---
## Step 2 - Configure Domain Name

Open a terminal session and set the variable for your domain name:

    export CFN_DOMAIN=<YOUR_DOMAIN_DOMAIN>

For `CFN_DOMAIN`, enter the base domain name of the applications. For example, if JIRA will have a domain name
of `jira.example.com`, use `example.com` for the value. The value must be all lowercase and cannot contain underscores,
end with a dash, have consecutive periods, or use dashes adjacent to periods. The value must be for a domain name you
can approve SSL certificates for using email or DNS validation.

---
## Step 3 - Create certificates in the AWS Certificate Manager

Valid SSL certificates are required to deploy the infrastructure and applications. The SSL certificates are used by
Amazon CloudFront and the AWS Elastic Load Balancers. We use wildcard certificates, like e.g `*.example.com` so you can
deploy multiple applications under the base domain name.

Run the following commands to request the certificates. The first command makes a request for the region your
application will be deployed to. The second command makes a request for `us-east-1`. This second request may be required
because Amazon CloudFront requires the SSL certificate be available in the `us-east-1` region. So, if your application
is running in us-east-1, the second request is redundant, but causes no harm.

    aws acm request-certificate --domain-name \*.${CFN_DOMAIN}
    aws acm request-certificate --domain-name \*.${CFN_DOMAIN} --region us-east-1                              

---
## Step 4 - Validate the Certificates

You can view the certificate requests by logging into the AWS Management Console and navigating to the AWS Certificate
Manager dashboard.

You need to validate the certificates using either DNS validation or Email validation. Information is
available https://docs.aws.amazon.com/acm/latest/userguide/domain-ownership-validation.html

Do not continue to the next step until the certificate(s) are validated.

---
## Step 5 - Deploy the VPC, ECS, and RDS infrastructure

Deploy the infrastructure by running the following command:

    ./deploy-infra.sh

---
## Step 6 - Create the databases for the application

Next, we will create the MySQL databases required to install the applications and services. Perform the following steps:

1. Login to the AWS Management Console
2. Navigate to the EC2 Service
3. Select **Instances**
4. Select the checkbox next to the EC2 instance created by ECS.
5. Click on **Connect** and select to open a terminal session using the **Session Manager**
6. Once you are logged into the EC2 instance, run the following commands, making sure to replace **USER** and **
   PASSWORD** with your MySQL user:

        sudo su ec2-user
        mysql -h ${RDS_ENDPOINT_ADDRESS} -u <USER> -p<PASSWORD> -e "CREATE DATABASE IF NOT EXISTS jira CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
        mysql -h ${RDS_ENDPOINT_ADDRESS} -u <USER> -p<PASSWORD> -e "CREATE DATABASE IF NOT EXISTS teamcity CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
        mysql -h ${RDS_ENDPOINT_ADDRESS} -u <USER> -p<PASSWORD> -e "CREATE DATABASE IF NOT EXISTS mediawiki CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"

7. You can now close the Session Manager session. All deployment following deployment steps will be run from the
   terminal of your local machine.
---
## Step 7 - JIRA

### Deploy 

Run the following command:

    ./deploy.sh jira

### Configure Domain Name for Service to target CloudFront Distribution

Before proceeding with the installation, you'll need to configure a DNS entry to point to the CloudFront
distribution for the service. If you are using Amazon Route53, you can create a simple record for `<SERVICE_NAME>.<DOMAIN>`
. The domain should match the wildcard certificate you configured in the Amazon Certificate Manager. If you
used `apps.example.com` as the domain, the Route53 entry would be `jira.apps.example.com`.

### Complete JIRA setup

You can now log in to JIRA and complete the setup steps. In your browser, navigate to the 
domain name used in the previous step. 
It may take some time to complete loading, since JIRA creates the database first time it is used.

---
## Step 8 - TeamCity

### Deploy

Run the following command:

    ./deploy.sh teamcity

### Configure Domain Name for Service to target CloudFront Distribution

Before proceeding with the installation, you'll need to configure a DNS entry to point to the CloudFront
distribution for the service. If you are using Amazon Route53, you can create a simple record for `<SERVICE_NAME>.<DOMAIN>`
. The domain should match the wildcard certificate you configured in the Amazon Certificate Manager. If you
used `apps.example.com` as the domain, the Route53 entry would be `teamcity.apps.example.com`.

---
## Step 9 - Upsource

### Deploy

Run the following command:

    ./deploy.sh upsource

### Configure Domain Name for Service to target CloudFront Distribution

Before proceeding with the installation, you'll need to configure a DNS entry to point to the CloudFront
distribution for the service. If you are using Amazon Route53, you can create a simple record for `<SERVICE_NAME>.<DOMAIN>`
. The domain should match the wildcard certificate you configured in the Amazon Certificate Manager. If you
used `apps.example.com` as the domain, the Route53 entry would be `upsource.apps.example.com`.

### Complete Upsource Installation Wizard

Now you can access Upsource at the domain name you configured above, and run the installation wizard.

You'll need to get the Wizard Token output into the log files. Access the AWS CloudWatch logs for Upsource. You'll need
to find the installation token in the logs. It should be the last line and look like:

    * JetBrains Upsource 2020.1 Configuration Wizard will listen inside container on 
    {0.0.0.0:8080}/ after start and can be accessed by URL 
    [http://<put-your-docker-HOST-name-here>:<put-host-port-mapped-to-container-port-8080-here>
    /?wizard_token=hOsFEoWcjl41iLAGHKwa] 


# Notes on Costs

All deployment options have the following:

* Client VPN with 10 users - 40 hours per week per user
* Monthly data transfer of 100 GB outbound and 100 GB inter-region
* ECS for application deployment, 1x r5a.xlarge (32 GB)
* Elasticsearch Service uses instances with 64 GB of memory.
* EFS Volume of 100 GB frequently accessed and 1 TB of infrequently accessed data, and a **minimum** provisioned
  throughput of 10 MB/s
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
* Costs with reserved instances and using smaller ES instances since we have 3
  running: https://calculator.aws/#/estimate?id=327859c4daa72b73c1875995b139ae1cea610cc5

#### Cost Reduction Options:

Based on the following: https://calculator.aws/#/estimate?id=66eaee38f44855524ec49af39e3f0397f25f0cde

* Non HA
* Use Reserved Instance Pricing
* Remove ALB - save costs by routing from CloudFront directly to ECS instances
* Remove NAT Gateways - use VPC Endpoints

Evaluate using lower-memory instance types for Amazon Elasticsearch Service


# Open Tasks

* Security: Secure database credentials
* Teamcity Database Configuration
* Optimize EFS Configuration
* Update pricing info
* AWS Cognito -> ALB integration
* Simplify Deployment process and support multiple teamcity deploys
* Security: Narrow all roles/permissions
* Configure Elasticsearch Service Linked Role as CloudFormation resource
* Accessibility of ES
* Investigate autoscaling of build servers, use of docker
* Networking: Remove NAT Gateways for cost-savings
* Networking: Change EFS to use security group from service, instead of ECS Security Group
* Networking: Use a different CIDR range in private subnet from public subnet
* Networking: Optimize subnets to be minimum possible size
* Performance: Configure CPU limits on tasks, such that no task can consume an unfair share of the hosts resources
* Performance: Optimize instance types for ECS and RDS




 