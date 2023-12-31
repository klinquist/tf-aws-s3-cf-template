data "aws_route53_zone" "public" {
  name         = "${var.domainName}"
  private_zone = false
}


locals {
    validations = {
        for option in aws_acm_certificate.certificate.domain_validation_options :
        option.domain_name => option
    }
}


resource "aws_acm_certificate" "certificate" {
  domain_name       = var.domainName
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Environment = var.SiteTags
  }
  subject_alternative_names = ["www.${var.domainName}"]
}


resource "aws_route53_record" "validation" {

    for_each = toset([var.domainName, "www.${var.domainName}"])
    allow_overwrite = true
    zone_id = data.aws_route53_zone.public.zone_id
    ttl = 60
    name    = local.validations[each.key].resource_record_name
    type    = local.validations[each.key].resource_record_type
    records = [ local.validations[each.key].resource_record_value ]

}

resource "aws_acm_certificate_validation" "check_validation" {
    certificate_arn = aws_acm_certificate.certificate.arn
    validation_record_fqdns = aws_acm_certificate.certificate.domain_validation_options[*].resource_record_name
}


resource "aws_route53_record" "web" {
  zone_id = data.aws_route53_zone.public.id
  name    = var.domainName
  type = "A"
  alias {
    name                   = aws_cloudfront_distribution.my_cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.my_cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}


resource "aws_route53_record" "web-www" {
  zone_id = data.aws_route53_zone.public.id
  name    = "www.${var.domainName}"
  type = "A"
  alias {
    name                   = aws_cloudfront_distribution.my_cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.my_cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}


resource "aws_route53_record" "gmail" {
  count = var.gmailTxtRecord != "" ? 1 : 0
  zone_id = data.aws_route53_zone.public.id
  name    = var.domainName
  type    = "MX"
  ttl     = 300
  records = [
    "1 ASPMX.L.GOOGLE.COM",
    "5 ALT1.ASPMX.L.GOOGLE.COM",
    "5 ALT2.ASPMX.L.GOOGLE.COM",
    "10 ASPMX2.GOOGLEMAIL.COM",
    "10 ASPMX3.GOOGLEMAIL.COM",  
  ]
}

resource "aws_route53_record" "gmail-txt-verification" {
  count = var.gmailTxtRecord != "" ? 1 : 0
  zone_id = data.aws_route53_zone.public.id
  name    = var.domainName
  type    = "TXT"
  ttl     = 300
  records = [var.gmailTxtRecord]
}