# AWS Static Website Terraform Template

**[Jump straight to Usage](#usage)**

Regularly register a domain and want to put some web content there? This project quickly sets up a website hosted by Amazon Web Services. This is a very inexpensive hosting option, costing as little as 50 cents per month.

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

1. `./setup.sh`: one guided setup command that:
   * Asks which domain you want to use
   * Asks whether you use Namecheap and whether the domain is already registered
   * Opens Namecheap when registration or nameserver changes are needed
   * Creates or reuses the Route53 hosted zone and updates `terraform.tfvars`
   * Waits for public DNS delegation before continuing
   * Runs `terraform init` and `terraform apply -auto-approve`
   * Starts the GitHub repository and deployment setup
2. Terraform modules that do the following:
   * Creates an S3 bucket (domainname) and static site hosting with `index.html` as the index document.
   * Creates a second S3 bucket for logs (domainname-logs) with a lifecycle policy to delete logs after 15 days
   * Creates a CloudFront distribution
   * Creates an SSL certificate for the domain name (adding www. as a subject alternative name)
   * Creates a Route53 record for the domain name (adding www. as a CNAME)
   * Creates an IAM user & policy for a GitHub action.  Warning: Check the permissions, they are too liberal right now :).
   * (optional) Creates Route53 MX records and TXT validation record for Google Workspace
3. GitHub repository setup, run automatically by `./setup.sh`, that:
   * Creates a new private GitHub repo (called domainname.com) in your GitHub account
   * Commits all files in the current directory to the repo
   * Adds AWS credentials to your GitHub repo secrets so you can use the GitHub action to deploy your website to the S3 bucket
   * Sets up a GitHub action to build the React/Vite site and auto-deploy the `dist` folder
   * Creates a shell script called "manually-deploy.sh" that you can use to manually deploy your website to the S3 bucket
4. React/Vite starter site:
   * `npm run dev` starts the local development server
   * `npm run build` writes production assets to `dist`
   * GitHub Actions runs the build, syncs `dist` to S3, and invalidates CloudFront



### Prerequisites

* A GitHub account
* A domain name you want to use. It may already be registered, or the setup will guide you through registering it. Namecheap has the most guided flow, but other registrars work too.
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) must be installed.
* An account with AWS.  You can sign up for an account [here](https://portal.aws.amazon.com/billing/signup).
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) must be installed and configured with **FullAccess** (configure it by typing `aws configure sso`, more information can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html#getting-started-quickstart-new-command)).
* [jq](https://jqlang.github.io/jq/) must be installed. This is a command-line JSON processor used by the shell scripts.
* [gh](https://cli.github.com) Github CLI must be installed (and logged in) to create a new private repo and set up GitHub actions.
* [Node.js](https://nodejs.org/) 20+ must be installed if you want to run or build the included React/Vite starter locally.

## Usage

1. Clone this repo. I recommend cloning it into a directory named after your domain name:

```bash
mkdir <domainname.com>
cd <domainname.com>
git clone https://github.com/klinquist/tf-aws-s3-cf-template.git .
```

2. Run the guided setup:

```bash
./setup.sh
```

That is the only setup command. It will:

1. Ask for your domain.
2. Ask whether the registrar is Namecheap.
3. Ask whether the domain is already registered. If not, it pauses while you register it in your browser.
4. Create the Route53 hosted zone and show the four authoritative nameservers.
5. Open the Namecheap domain manager when applicable, or explain where to change nameservers at another registrar.
6. Wait until the public internet sees the Route53 nameservers.
7. Initialize and apply Terraform automatically.
8. Offer to create the private GitHub repository and configure deployment.

The script will not run Terraform until DNS delegation is correct, because ACM certificate validation would otherwise time out.


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
