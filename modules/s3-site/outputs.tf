output "site_bucket_name" {
  value = aws_s3_bucket.my_site_bucket.bucket
}

output "site_bucket_arn" {
  value = aws_s3_bucket.my_site_bucket.arn
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.my_site_bucket.website_endpoint
}
