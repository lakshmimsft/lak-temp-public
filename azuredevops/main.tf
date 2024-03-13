terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">=0.1.0"
    }
  }
}

provider "azuredevops" {
  org_service_url = "https://dev.azure.com/my-org"
  client_id     = "00000000-0000-0000-0000-000000000001"
  tenant_id     = "00000000-0000-0000-0000-000000000001"
  client_secret = "top-secret-password-string"
}

resource "azuredevops_project" "project" {
  name        = "Test Project"
  description = "Test Project Description"
}
