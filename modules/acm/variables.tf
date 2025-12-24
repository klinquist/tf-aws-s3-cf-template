variable "domain_name" {
  type = string
}

variable "subject_alt_names" {
  type = list(string)
}

variable "hosted_zone_id" {
  type = string
}

variable "site_tags" {
  type = string
}
