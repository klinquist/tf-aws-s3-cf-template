## Information

Regularly register a domain and want to put some web content there?


This is a shell script that:
* Adds a hosted zone in Route53 for your domain
* Prints the NS records for your domain so you can update your registrar

AND

This is a Terraform module that does the following:
* Creates an S3 bucket (domainname)
* Creates a second S3 bucket for logs (domainname-logs) with a lifecycle policy to delete logs after 15 days
* Creates a CloudFront distribution
* Creates an SSL certificate for the domain name (adding www. as a subject alternative name)
* Creates a Route53 record for the domain name (adding www. as a CNAME)
* Creates an IAM user & policy for a github action.  Warning: Check the permissions, they are too liberal right now :).
* (optional) Creates Route53 MX records and TXT validation record for Google Workspace
  
AND

This is a shell script that:
* Adds AWS credentials to your github repo secrets so you can use the github action to deploy your website to the bucket (using something like Jekyll).




### Prerequisites


1. [Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
2. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
3. Generate an access key for your AWS account and add it to your environment.  You can do this in the AWS console under IAM -> Users -> Security Credentials -> Create Access Key.    Now, type `aws configure` and enter the access key and secret key.  You can leave the default region and output format as is.


### Installation

* Change the variables in the **terraform.tfvars** file.
* Run `./create-hosted-zone.sh` to automatically create the hosted zone in AWS Route53.
* Login to your domain registrar and update the NS records for your domain to the ones printed by the script above.
**If your domain's NS records are not yet pointed to AWS prior to running terraform, this script will timeout validating the certificate.**

Run the following:
```
terraform init
terraform plan
terrafom apply --auto-approve
```
* (optional) Run `./add-secrets-to-repo.sh` to show the appropriate keys and optionally add them directly to the repo using the "gh" cli.   This is needed if you want to use the github action to deploy your website to the bucket (using something like Jekyll).

Note: This creates resources in `us-east-1`.  If you want to change the default region, you can do so by editing `main.tf`.