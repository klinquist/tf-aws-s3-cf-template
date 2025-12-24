output "log_bucket_name" {
  value = aws_s3_bucket.log_bucket.bucket
}

output "log_bucket_domain_name" {
  value = aws_s3_bucket.log_bucket.bucket_domain_name
}

output "log_bucket_arn" {
  value = aws_s3_bucket.log_bucket.arn
}
