resource "aws_route53_record" "web" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.distribution_domain_name
    zone_id                = var.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "web-www" {
  zone_id = var.hosted_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.distribution_domain_name
    zone_id                = var.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "gmail" {
  count   = var.gmail_txt_record != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300
  records = [
    "1 SMTP.GOOGLE.COM",
  ]
}

resource "aws_route53_record" "gmail-txt-verification" {
  count   = var.gmail_txt_record != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = [var.gmail_txt_record]
}
