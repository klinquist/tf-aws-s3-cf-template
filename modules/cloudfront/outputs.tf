output "distribution_id" {
  value = aws_cloudfront_distribution.my_cloudfront.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.my_cloudfront.arn
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.my_cloudfront.domain_name
}

output "hosted_zone_id" {
  value = aws_cloudfront_distribution.my_cloudfront.hosted_zone_id
}
