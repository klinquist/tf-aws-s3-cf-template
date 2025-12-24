output "site_bucket_name" {
  value = module.s3_site.site_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  value = module.cloudfront.distribution_domain_name
}
