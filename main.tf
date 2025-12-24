provider "aws" {
  region = "us-east-1"
}

data "aws_route53_zone" "public" {
  name         = var.domainName
  private_zone = false
}

module "s3_site" {
  source = "./modules/s3-site"

  domain_name = var.domainName
}

module "s3_logs" {
  source = "./modules/s3-logs"

  domain_name = var.domainName
}

module "acm" {
  source = "./modules/acm"

  domain_name       = var.domainName
  subject_alt_names = ["www.${var.domainName}"]
  hosted_zone_id    = data.aws_route53_zone.public.zone_id
  site_tags         = var.SiteTags
}

module "cloudfront" {
  source = "./modules/cloudfront"

  domain_name             = var.domainName
  aliases                 = [var.domainName, "www.${var.domainName}"]
  origin_website_endpoint = module.s3_site.website_endpoint
  log_bucket_domain_name  = module.s3_logs.log_bucket_domain_name
  acm_certificate_arn     = module.acm.cert_arn
  site_tags               = var.SiteTags
}

module "route53" {
  source = "./modules/route53"

  hosted_zone_id              = data.aws_route53_zone.public.zone_id
  distribution_domain_name    = module.cloudfront.distribution_domain_name
  distribution_hosted_zone_id = module.cloudfront.hosted_zone_id
  domain_name                 = var.domainName
  gmail_txt_record            = var.gmailTxtRecord
}

module "iam_github" {
  source = "./modules/iam-github"

  domain_name      = var.domainName
  bucket_arn       = module.s3_site.site_bucket_arn
  distribution_arn = module.cloudfront.distribution_arn
}
