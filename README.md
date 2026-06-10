Regularly register a domain and want to put some web content there?  This is a collection of tools you can use to quickly set up a website hosted by Amazon Web Services.    This is a very inexpensive hosting option, costing as little as 50 cents per month.

### What does hosting a website entail?

1. Registering the domain name with a domain registrar.
2. Configuring *authoritative name servers* for your website. This involves establishing an account with a DNS provider and typing the address of the DNS servers into the registrar. This tells the internet "Which server is responsible for the *phone book* (DNS) for this domain name?"  
3. Populating that phone book (DNS) with entries like "www" (what is the IP address that a browser should query when someone types www.domainname.com?)
4. Hosting the website somewhere (html files and images stored on a computer that is internet accessible and running 24/7)

Many companies offer all of these parts - or some combination of parts (squarespace, wix, etc).  However, you rarely have full control over each, and they tend to be expensive!  

**This project is meant to be a starting point for people who:**

* Want to start from the included React/Vite site or bring their own static build output
* Want to write their own HTML/CSS/JS or use:
  * React/Vue/Svelte or similar JavaScript frameworks
  * Jekyll/Hugo/Astro or similar static site generators
* Want to learn more about DNS and infrastructure as code
* Want to learn more about Amazon Web Services
* Want to learn more about CI/CD and GitHub Actions
* Want to host a website for as little money as possible
* Want to extend this project to include other AWS resources for dynamic sites (e.g. serverless functions, databases, etc)

**This project is NOT ideal for people who:**

* Want to run Wordpress, Drupal, or another SQL and PHP based CMS.
  


### Definitions
* AWS: Amazon Web Services
* S3: Simple Storage Service, an AWS service for storing files.  This is where your website will be stored.
* CloudFront: AWS's content delivery network (CDN).   This will cache your website's content at edge locations around the world, making your website faster for users.  It will also make your website secure (https) by providing an SSL certificate.
* DNS: Domain Name Server.  This is the phone book for the internet.  It translates domain names (like www.domainname.com) into IP addresses (like 1.2.3.4).
* NS: Name Server.  This is a DNS server that is authoritative for a domain name.  It is responsible for answering queries about that domain name.
* Route53: AWS's DNS service.  This will allow you to point your domain name to your website.
* Terraform: A tool for managing infrastructure as code.  Terraform is used to configure the AWS resources.
* GitHub Actions: A tool for automating tasks in GitHub.  We will use this to automatically deploy your website to S3 when you commit changes to your GitHub repo.  Github offers up to 2000 minutes of free GitHub actions per month, which is plenty for a personal website.





### What does this repo include?

1. `./create-hosted-zone.sh`: A shell script that:
   * Adds a hosted zone in Route53 for your domain
   * Prints the NS records for your domain so you can update your registrar
   * Detects the current registrar through RDAP/whois when possible
   * Prints registrar-specific nameserver instructions and useful links for common registrars
   * Can wait and poll public DNS until the registrar delegates the domain to Route53
2. Terraform module that does the following:
   * Creates an S3 bucket (domainname) and static site hosting with `index.html` as the index document.
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
   * Sets up a GitHub action to build the React/Vite site and auto-deploy the `dist` folder
   * Creates a shell script called "manually-deploy.sh" that you can use to manually deploy your website to the S3 bucket
4. React/Vite starter site:
   * `npm run dev` starts the local development server
   * `npm run build` writes production assets to `dist`
   * GitHub Actions runs the build, syncs `dist` to S3, and invalidates CloudFront
5. DNS delegation helper scripts:
   * `./scripts/check-dns-delegation.sh` prints current registrar, current public nameservers, and expected Route53 nameservers
   * `./scripts/check-dns-delegation.sh --wait` polls until public DNS points at Route53
   * `./apply.sh` refuses to run `terraform apply` until nameserver delegation is correct



### Prerequisites

* A GitHub account
* A domain registered with your favorite registrar.  I use namecheap.com.
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) must be installed.
* An account with AWS.  You can sign up for an account [here](https://portal.aws.amazon.com/billing/signup).
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) must be installed and configured with **FullAccess** (configure it by typing `aws configure sso`, more information can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html#getting-started-quickstart-new-command)).
* [jq](https://jqlang.github.io/jq/) must be installed. This is a command-line JSON processor used by the shell scripts.
* [gh](https://cli.github.com) Github CLI must be installed (and logged in) to create a new private repo and set up GitHub actions.
* [Node.js](https://nodejs.org/) 20+ must be installed if you want to run or build the included React/Vite starter locally.


### Usage

1. Clone this repo! I recommend cloning it into a directory named after your domain name.  e.g. 
```bash
mkdir <domainname.com>
cd <domainname.com>
git clone https://github.com/klinquist/tf-aws-s3-cf-template.git .
```
2. Change the variables in the **terraform.tfvars** file.
3. Run `./create-hosted-zone.sh` to automatically create the hosted zone in AWS Route53.
4. Login to your domain registrar and update the NS records for your domain to the ones printed by the script above. The script will try to detect your registrar and print a direct link/instructions for common providers.
  
**If your domain's NS records are not pointed to AWS before running terraform, certificate validation will timeout.**

You can check the current status at any time:

```bash
./scripts/check-dns-delegation.sh
```

Or wait until public DNS points to the Route53 nameservers:

```bash
./scripts/check-dns-delegation.sh --wait
```

The checker shows output like:

```text
Status: registrar still points to:
  - dns1.registrar-example.com
Waiting for Route53 nameservers:
  - ns-123.awsdns-45.com
```

5. Run the following to deploy the infrastructure:
```
./apply.sh --auto-approve
```

`./apply.sh` runs the DNS delegation check first and refuses to continue until the domain is delegated to Route53. It also runs `terraform init` for you if needed.

6. Run `./set-up-repo.sh` to create a new private repository on GitHub, set up GitHub actions, and add AWS credentials to your GitHub repo secrets.   This will make a sample site available on https://www.domainname.com!  


Note: This creates resources in `us-east-1`.  If you want to change the default region, you can do so by editing `main.tf`.


### Editing your web page

This repo now includes a React/Vite starter. Run it locally with:

```bash
npm install
npm run dev
```

Build the production site with:

```bash
npm run build
```

Commit your React app changes and push to GitHub. The GitHub action will run `npm ci`, build the site into `dist`, deploy `dist` to the S3 bucket, and invalidate the CloudFront cache. Your changes should be live in a few minutes.

If you prefer another generator such as Jekyll, Hugo, or Astro, update `.github/workflows/deploy.yml` and `manually-deploy.sh` so they build your site and sync the generated output folder to S3.

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
