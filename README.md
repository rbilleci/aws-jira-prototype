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
of `jira.example.com`, use `example.com`. The value must be all lowercase and cannot contain underscores,
end with a dash, have consecutive periods, or use dashes adjacent to periods. The value must be for a domain name you
can approve SSL certificates for using email or DNS validation.

---

## Step 3 - Create certificates in the AWS Certificate Manager

Valid SSL certificates are required to deploy the infrastructure and applications. The SSL certificates are used by
Amazon CloudFront and the AWS Elastic Load Balancers. This deployment uses wildcard certificates, like `*.example.com` 
so you can  deploy multiple applications under the base domain name.

Run the following commands to request the certificates. The first command makes a request for the region your
application will be deployed to. The second command makes a request for `us-east-1`. This second request may be required
because Amazon CloudFront requires the SSL certificate be available in the `us-east-1` region. So, if your application
is running in us-east-1, the second request is redundant, but causes no harm.

    aws acm request-certificate --domain-name \*.${CFN_DOMAIN}
    aws acm request-certificate --domain-name \*.${CFN_DOMAIN} --region us-east-1                              

---
## Step 4 - Validate the Certificates

You can view the certificate requests in the AWS Certificate Manager dashboard. You must validate the certificates 
using either DNS validation or Email validation. Information is
available https://docs.aws.amazon.com/acm/latest/userguide/domain-ownership-validation.html

Do not continue until the certificate(s) are validated.

---
## Step 5 - Deploy the VPC, ECS, and RDS infrastructure

Deploy the infrastructure by running the following command:

    ./deploy-infra.sh

---
## Step 6 - Create Application Databases

Create the MySQL databases for the applications, with the following steps:

1. Login to the AWS Management Console
2. Navigate to the EC2 Service
3. Select **Instances**
4. Select the checkbox next to the EC2 instance created by ECS.
5. Click on **Connect** and select to open a terminal session using the **Session Manager**
6. Once you are logged into the EC2 instance, run the following commands:
   
        sudo su ec2-user
        sudo yum -y install aws-cli jq
        ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
        REGION="`echo \"$ZONE\" | sed 's/[a-z]$//'`"
        RDS_PASSWORD=$(aws secretsmanager get-secret-value --secret-id /apps-mvsm-io/rds/credentials --region $REGION --query SecretString --output text | jq -r '.password')
        mysql -h ${RDS_ENDPOINT_ADDRESS} -u root -p"$RDS_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS jira CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
        mysql -h ${RDS_ENDPOINT_ADDRESS} -u root -p"$RDS_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS teamcity CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
        mysql -h ${RDS_ENDPOINT_ADDRESS} -u root -p"$RDS_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS mediawiki CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"

7. You can now close the Session Manager session.

---

## Step 7 - JIRA

### Deploy 

Run the following command:

    ./deploy.sh jira

### Configure Domain Name for Service to target CloudFront Distribution

Before proceeding with the installation, you must configure a DNS entry to point to the CloudFront
distribution for the service. If you are using Amazon Route53, you can create a simple record for `<SERVICE_NAME>.<DOMAIN>`
. The domain should match the wildcard certificate you configured in the Amazon Certificate Manager. If you
used `apps.example.com` as the domain, the Route53 entry would be `jira.apps.example.com`.

### Complete JIRA setup

Complete the JIRA setup with the following steps:

1. In your browser, navigate to the domain name used in the previous step. For example `jira.apps.example.com`
   It may take more than 10 minutes for the domain name to propagate. Please be patient.
2. JIRA will prompt you for the license.
3. Enter your license and wait for JIRA to restart.
4. After 3-5 minutes, reload the page.  
5. JIRA will prompt you for the license again. 
6. JIRA will guide you through the final configuration steps.


---
## Step 8 - TeamCity

### Deploy

Run the following command:

    ./deploy.sh teamcity

### Configure Domain Name for Service to target CloudFront Distribution

Before proceeding with the installation, you must configure a DNS entry to point to the CloudFront
distribution for the service. If you are using Amazon Route53, you can create a simple record for `<SERVICE_NAME>.<DOMAIN>`
. The domain should match the wildcard certificate you configured in the Amazon Certificate Manager. If you
used `apps.example.com` as the domain, the Route53 entry would be `teamcity.apps.example.com`.

### Retrieve the RDS Endpoint and RDS Secret

The password for RDS is randomly generated and stored in the AWS Secrets Manager.
You'll need the `root` user password to configure TeamCity. 
From the AWS Management Console, navigate to the Secrets Manager, select the secret,
and click on the button: `Retrieve secret value`. You'll use this password in the next step.

### Configure TeamCity

1. In a browser window, navigate to TeamCity using the domain you configured in the previous step. 
For example `teamcity.apps.example.com`.
2. You'll see the page: "TeamCity First Start". Click `Proceed`. TeamCity will initialize the data directory
3. During the `Database connection setup` page, select `MySQL`, then enter the database credentials:
   * for the database hose, enter the RDS Endpoint address
   * for the database name, enter `teamcity`
   * for the username, enter `root`
   * for the password, enter the password from the secrets manager


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

You can access Upsource at the domain name you configured above to run the installation wizard.

The wizard will ask you for the Wizard Token. This token can be found in the log files.
1. Access AWS CloudWatch
2. Select the `upsource` log group
3. Select the latest log stream and open it
4. Scroll to the last log entry and expand it. It should look something like the follow:


      JetBrains Upsource 2020.1 Configuration Wizard will listen inside container on 
      {0.0.0.0:8080}/ after start and can be accessed by URL 
      [http://<put-your-docker-HOST-name-here>:<put-host-port-mapped-to-container-port-8080-here>
      /?wizard_token=XXXXXXXXXXXXXXX] 

## Step 10 - MediaWiki

Run the following command:

    ./deploy.sh mediawiki

### Configure Domain Name for Service to target CloudFront Distribution

Before proceeding with the installation, you'll need to configure a DNS entry to point to the CloudFront
distribution for the service. If you are using Amazon Route53, you can create a simple record for `<SERVICE_NAME>.<DOMAIN>`
. The domain should match the wildcard certificate you configured in the Amazon Certificate Manager. If you
used `apps.example.com` as the domain, the Route53 entry would be `mediawiki.apps.example.com`.

### Login to MediaWiki

Login to the mediawiki site with username: `user` and password: `bitnami123`

### SMTP Configuration

SMTP settings may be changed from the SSM Parameter Store in the AWS Management Console. 
Changes to the SMTP settings require a restart of the ECS Service for MediaWiki.


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


# Open Tasks

* Application specific database credentials
* AWS Cognito -> ALB integration 
* Optimize EFS Configuration
* Update Naming conventions 
* Update pricing info
* Test with multiple teamcity deploys
* Configure Elasticsearch Service Linked Role as CloudFormation resource
* Accessibility of ES 
* Networking: Remove NAT Gateways for cost-savings
* Networking: Change EFS to use security group from service, instead of ECS Security Group
* Networking: Use a different CIDR range in private subnet from public subnet
* Networking: Optimize subnets to minimum possible size




 