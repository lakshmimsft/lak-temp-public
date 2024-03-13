
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

provider "google" {
  credentials = data.kubernetes_secret.gcloud_creds.data["creds"]
  
  project = "focal-woods-358701"
  region  = "us-central1"
  zone    = "us-central1-c"
}


resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}