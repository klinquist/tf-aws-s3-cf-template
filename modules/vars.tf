variable "SiteTags" {
  type = string
}

variable "domainName" {
  type = string
}

variable "gmailTxtRecord" {
  type = string
  default = ""
}

variable "dnsTtl" {
  type = number
}