## Information

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
* (optional) Run `./add-secrets-to-repo.sh` to show the appropriate keys and optionally add them directly to a repo using the "gh" (github) cli.  This makes the secrets available to a github action that you can use to deploy your website to the s3 bucket.  I use [Jekyll](https://jekyllrb.com) for actual website generation - it compiles markdown to HTML.   You can see my Jekyll github action in `sample-github-action/build-and-deploy.yml`.  I place this in the `.github/workflows` directory of my repo. 

Note: This creates resources in `us-east-1`.  If you want to change the default region, you can do so by editing `main.tf`.


### Usage (if not using a github action to auto-deploy)

Upload your web content (index.html, etc) to your new S3 bucket (domainname.com).  This can be done via aws cli (using a command like `aws s3 sync <source> s3://<domainname.com> --acl public-read --delete --cache-control max-age=604800`), or via a client like Panic Transmit.  After making a change, you'll want to create a cloudfront invalidation to remove the cache. 

To do this via CLI, get the distribution:
`terraform state pull | jq -r '.resources[] | select(.type == "aws_cloudfront_distribution") | .instances[0].attributes.id'`

Then, create the invalidation:
`aws cloudfront create-invalidation --distribution-id <distribution_id> --paths "/*"`