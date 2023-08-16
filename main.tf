provider "aws" {
  region  = "us-east-1"
}


module "cloudfront" {
  source = "./modules/"

  SiteTags          = var.SiteTags
  domainName        = var.domainName
  dnsTtl            = var.dnsTtl
  gmailTxtRecord    = var.gmailTxtRecord
}
