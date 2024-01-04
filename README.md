Regularly register a domain and want to put some web content there?  This is a collection of tools you can use to quickly set up a website hosted by Amazon Web Services.    This is a very inexpensive hosting option, costing as little as 50 cents per month.

### What does hosting a website entail?

1. Registering the domain name with a domain registrar.
2. Configuring *authoritative name servers* for your website.  This tells the internet "Which server is responsible for the *phone book* for this domain name?"  
    * A phone book (DNS) with a DNS provider must exist.
    * Your domain registrar needs to know which DNS provider to use for your domain.
3. You must populate that phone book (DNS) with entries like "www" (what is the IP address that a browser should query when someone types www.domainname.com?)
4. Finally, you must have the website hosted somewhere (html files and images stored on a computer that is internet accessible and running 24/7)

Many companies offer all of these parts - or some combination of parts (squarespace, wix, etc).  However, you rarely have full control over each, and they tend to be expensive!  This project is meant to be a starting point for people who:
* Want to write their own HTML/CSS/JS (or use templates)
* Want to learn more about DNS and infrastructure as code
* Want to learn more about Amazon Web Services
* Want to host a website for as little money as possible
  


### Definitions
* AWS: Amazon Web Services
* S3: Simple Storage Service, an AWS service for storing files.  This is where your website will be stored.
* CloudFront: AWS's content delivery network (CDN).   This will cache your website's content at edge locations around the world, making your website faster for users.  It will also make your website secure (https) by providing an SSL certificate.
* DNS: Domain Name Server.  This is the phone book for the internet.  It translates domain names (like www.domainname.com) into IP addresses (like 1.2.3.4).
* Route53: AWS's DNS service.  This will allow you to point your domain name to your website.
* Terraform: A tool for managing infrastructure as code.  Terraform is used to configure the AWS resources.
* GitHub Actions: A tool for automating tasks in GitHub.  We will use this to automatically deploy your website to S3 when you commit changes to your GitHub repo.  Github offers up to 2000 minutes of free GitHub actions per month.  This should be plenty for a personal website.





### What does this repo include?

1. `./create-hosted-zone.sh`: A shell script that:
   * Adds a hosted zone in Route53 for your domain
   * Prints the NS records for your domain so you can update your registrar
2. Terraform module that does the following:
   * Creates an S3 bucket (domainname)
   * Creates a second S3 bucket for logs (domainname-logs) with a lifecycle policy to delete logs after 15 days
   * Creates a CloudFront distribution
   * Creates an SSL certificate for the domain name (adding www. as a subject alternative name)
   * Creates a Route53 record for the domain name (adding www. as a CNAME)
   * Creates an IAM user & policy for a GitHub action.  Warning: Check the permissions, they are too liberal right now :).
   * (optional) Creates Route53 MX records and TXT validation record for Google Workspace
3. `./set-up-repo.sh`: A shell script that:
   * Creates a new private GitHub repo (called domainname.com) in your GitHub account
   * Commits all files in the current directory to the repo
   * Adds AWS credentials to your GitHub repo secrets so you can use the GitHub action to deploy your website to the S3 bucket
   * Sets up a GitHub action to auto-deploy
   * Creates a shell script called "manually-deploy.sh" that you can use to manually deploy your website to the S3 bucket



### Prerequisites

* A GitHub account
* A domain registered with your favorite registrar.  I use namecheap.com.
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) must be installed.
* An account with AWS.  You can sign up for an account [here](https://portal.aws.amazon.com/billing/signup).
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) must be installed and configured with **FullAccess** (configure it by typing `aws configure sso`, more information can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html#getting-started-quickstart-new-command)).
* [jq](https://jqlang.github.io/jq/) must be installed. This is a command-line JSON processor used by the shell scripts.
* [gh](https://cli.github.com) Github CLI must be installed (and logged in) to create a new private repo and set up GitHub actions.


### Usage

1. Clone this repo! I recommend cloning it into a directory named after your domain name.  e.g. 
```bash
mkdir <domainname.com>
cd <domainname.com>
git clone https://github.com/klinquist/tf-aws-s3-cf-template.git .
```
2. Change the variables in the **terraform.tfvars** file.
3. Run `./create-hosted-zone.sh` to automatically create the hosted zone in AWS Route53.
4. Login to your domain registrar and update the NS records for your domain to the ones printed by the script above.  **Wait up to 10 minutes for the changes to propagate.**
  
**If your domain's NS records are not pointed to AWS before running terraform, this script will timeout validating the certificate.**

5. Run the following to deploy the infrastructure:
```
terraform init
terraform apply --auto-approve
```

6. Run `./set-up-repo.sh` to create a new private repository on GitHub, set up GitHub actions, and add AWS credentials to your GitHub repo secrets.   This will make a sample site available on https://www.domainname.com!  


Note: This creates resources in `us-east-1`.  If you want to change the default region, you can do so by editing `main.tf`.


### Editing your web page

Commit changes to the "_site" folder and push to GitHub.  The GitHub action will automatically deploy your changes to the S3 bucket and invalidate the CloudFront cache.  Your changes should be live in a few minutes.

I personally use [Jekyll](https://jekyllrb.com/) to generate my website. It is a static site generator that uses markdown and templates to generate HTML.  The github action (in `.github/workflows/deploy.yml`) has lines commented out ready to build a Jekyll site if you go that route.

### Undoing everything!

This repo contains a shell script called `./destroy-all.sh` which will:
* Remove everything from the S3 buckets
* Run 'terraform destroy' to remove all terraform-managed resources
* Delete the hosted zone from Route53
* Delete the GitHub repo


### To-do

* Use the GitHub terraform provider instead of `gh` cli?  Still requires `gh` to be installed and authorized *or* a personal access token to be provided.   A shell script would still be required to commit files to the repository.
* Set up the [Github-AWS OIDC connection](https://docs.GitHub.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) rather than generating an AWS user w/ access key & secret.  This would make things more secure.

### Pull requests welcome!