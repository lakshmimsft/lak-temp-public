
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

data "kubernetes_secret" "gcloud_creds" {
  metadata {
    name      = "gcloud-creds"
    namespace = "default"
  }
}

