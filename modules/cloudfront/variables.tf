variable "domain_name" {
  type = string
}

variable "aliases" {
  type = list(string)
}

variable "origin_website_endpoint" {
  type = string
}

variable "log_bucket_domain_name" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}

variable "site_tags" {
  type = string
}
