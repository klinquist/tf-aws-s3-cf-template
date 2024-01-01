Regularly register a domain and want to put some web content there?

This repo includes:

A shell script that:
* Adds a hosted zone in Route53 for your domain
* Prints the NS records for your domain so you can update your registrar

AND

A Terraform module that does the following:
* Creates an S3 bucket (domainname)
* Creates a second S3 bucket for logs (domainname-logs) with a lifecycle policy to delete logs after 15 days
* Creates a CloudFront distribution
* Creates an SSL certificate for the domain name (adding www. as a subject alternative name)
* Creates a Route53 record for the domain name (adding www. as a CNAME)
* Creates an IAM user & policy for a github action.  Warning: Check the permissions, they are too liberal right now :).
* (optional) Creates Route53 MX records and TXT validation record for Google Workspace
  
AND

A shell script that:
* Creates a new private github repo (called domainname.com) in your github account
* Commits all files in the current directory to the repo
* Adds AWS credentials to your github repo secrets so you can use the github action to deploy your website to the S3 bucket
* Sets up a github action to auto-deploy




### Prerequisites

* A domain registered with your favorite registrar.  I use namecheap.com.
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) must be installed.
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) must be installed.
* [jq](https://jqlang.github.io/jq/) must be installed.
* AWS CLI must be configured with your credentials. You can do this in the AWS console under IAM -> Users -> Security Credentials -> Create Access Key.    Type `aws configure` and enter the access key and secret key.  You can leave the default region and output format as is.
* (optional) [gh](https://cli.github.com) Github CLI must be installed (and logged in) to create a new private repo and set up github actions.


### Usage

* Clone this repo!
* Change the variables in the **terraform.tfvars** file.
* Run `./create-hosted-zone.sh` to automatically create the hosted zone in AWS Route53.
* Login to your domain registrar and update the NS records for your domain to the ones printed by the script above.  **Wait up to 30 minutes for the changes to propagate.**
  
**If your domain's NS records are not yet pointed to AWS prior to running terraform, this script will timeout validating the certificate.**

Run the following to deploy the infrastructure:
```
terraform init
terraform plan
terrafom apply --auto-approve
```
* (optional) Run `./set-up-repo.sh` to create a new private repository on github, set up github actions, and add AWS credentials to your github repo secrets.   This will make a sample site available on https://www.domainname.com!  
* 
Note: This creates resources in `us-east-1`.  If you want to change the default region, you can do so by editing `main.tf`.


### Editing your web page

Simply commit your changes to the "_site" folder and push to github.  The github action will automatically deploy your changes to the S3 bucket and invalidate the CloudFront cache.  Your changes should be live in a few minutes.