## Information

Regularly register a domain and want to put some web content there?

This is a Terraform module that does the following:
* Creates an S3 bucket (domainname)
* Creates a second S3 bucket for logs (domainname-logs) with a lifecycle policy to delete logs after 15 days
* Creates a CloudFront distribution
* Creates an SSL certificate for the domain name (adding www. as a subject alternative name)
* Creates a Route53 record for the domain name (adding www. as a CNAME)
* Creates an IAM user & policy for a github action.  Warning: Check the permissions, they are too liberal right now :).

This also assumes you want to receive email there and use a Google Workspace account for that - so the variables file includes the TXT record that you must add for Google verification.  If you don't, you can remove the MX record from the Route53 zone.



### Prerequisites


1. [Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
2. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
3. Generate an access key for your AWS account and add it to your environment.  You can do this in the AWS console under IAM -> Users -> Security Credentials -> Create Access Key.    Now, type `aws configure` and enter the access key and secret key.  You can leave the default region and output format as is.
4. Create a hosted zone in Route53 for your domain (shell script to perform this step is included, see installation below)
5. Login to your domain registrar and change the NS records to point to AWS (shell script to print NS is included, see installation below).

**If your domain's NS records are not yet pointed to AWS prior to running terraform, this script will timeout validating the certificate.**

### Installation

* Change the variables in the **terraform.tfvars** file.
* (optional) run `./create-hosted-zone.sh` to automatically create the hosted zone (step 4 above).

Run the following:
```
terraform init
terraform plan
terrafom apply --auto-approve
```
* (optional) run `./add-secrets-to-repo.sh` to show the appropriate keys and optionally add them directly to the repo using the "gh" cli.   This is needed if you want to use the github action to deploy your website to the bucket (using something like Jekyll).