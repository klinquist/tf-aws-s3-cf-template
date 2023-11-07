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

Before the deployment of this terraform module, make sure your hosted zone exists in Route 53 and move your domain to Route53 by changing NS records on your domain registrar.


### Installation

* Change the variables in the **terraform.tfvars** file.
* Make sure you have AWS credentials in your environment and terraform installed

Run the following:
```
terraform init
terraform plan
terrafom apply --auto-approve

```


### What do I do now?

Upload a webpage to your s3 bucket.

I personally use Jekyll to create a static website from markdown, and a github action to deploy it to the bucket.  Run `./show-keys.sh` to show the appropriate keys to export to your github action.