locals {
  validations = {
    for option in aws_acm_certificate.certificate.domain_validation_options :
    option.domain_name => option
  }
}

resource "aws_acm_certificate" "certificate" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.site_tags
  }

  subject_alternative_names = var.subject_alt_names
}

resource "aws_route53_record" "validation" {
  for_each        = local.validations
  allow_overwrite = true
  zone_id         = var.hosted_zone_id
  ttl             = 60
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
}

resource "aws_acm_certificate_validation" "check_validation" {
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
