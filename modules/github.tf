resource "github_repository" "my_website_repo" {
  name        = var.domainName
  description = "Repository for ${var.domainName}"

  visibility = "private"

  template {
    owner                = "github"
    repository           = "terraform-template-module"
    include_all_branches = true
  }
}