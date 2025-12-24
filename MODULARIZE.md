# Terraform Modularization Plan

## Goals
- Split the single "modules" folder into focused modules with clear inputs/outputs.
- Keep the root configuration easy to read and customize.

## Proposed module layout
- modules/s3-site
  - Owns the website bucket, website config, public access, bucket policy.
  - Outputs: site_bucket_name, site_bucket_arn, website_endpoint.
- modules/s3-logs
  - Owns the logs bucket, lifecycle policy, ACL/ownership controls.
  - Outputs: log_bucket_name, log_bucket_domain_name.
- modules/cloudfront
  - Owns the CloudFront distribution (and optional origin access identity if needed).
  - Inputs: domain_name, aliases, origin_website_endpoint, log_bucket_domain_name, acm_cert_arn.
  - Outputs: distribution_id, distribution_arn, distribution_domain_name, hosted_zone_id.
- modules/acm
  - Owns the ACM certificate and DNS validation records.
  - Inputs: domain_name, hosted_zone_id, subject_alt_names.
  - Outputs: cert_arn.
- modules/route53
  - Owns A/AAAA (alias) records for root and www, plus optional Gmail MX/TXT.
  - Inputs: hosted_zone_id, distribution_domain_name, distribution_hosted_zone_id, domain_name, gmail_txt_record.
- modules/iam-github
  - Owns the GitHub Actions IAM user/access key/policy.
  - Inputs: domain_name, bucket_arn, distribution_arn.
  - Outputs: access_key_id, secret_access_key (mark sensitive).

## Root module changes
- Replace the current single module call with multiple module blocks in `main.tf`.
- Keep variables in `vars.tf`, but group them by module usage in comments.
- Add outputs for key values (e.g., CloudFront domain) in a new `outputs.tf`.

## Dependency flow
- s3-site -> cloudfront (website endpoint)
- s3-logs -> cloudfront (log bucket domain)
- acm -> cloudfront (cert arn)
- cloudfront -> route53 (alias target)
- s3-site + cloudfront -> iam-github (resource ARNs)

## Step-by-step plan
1. Create module folders and move resource definitions without changing their arguments.
2. Add outputs for each new module.
3. Update root `main.tf` to wire modules together with inputs/outputs.
4. Run `terraform plan` to review resource changes; iterate if needed.
5. Run `terraform apply` once the plan is acceptable.

## Validation checklist
- `terraform fmt` and `terraform validate` pass.
- `terraform plan` shows no destroys for existing resources.
- Website still resolves and CloudFront serves content.
- GitHub Action still deploys to the correct bucket.

## Optional follow-ups
- Replace the current IAM policy with least-privilege actions.
- Add a module for GitHub OIDC instead of IAM access keys.
- Parameterize TTLs and cache settings in the CloudFront module.
