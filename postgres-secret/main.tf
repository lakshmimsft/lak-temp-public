terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37.1"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.22.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.12.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0.0"
    }
  }
}

provider "vault" {
  address = "http://vault.${var.context.runtime.kubernetes.namespace}.svc.cluster.local:8200"

  # For dev mode, use root token
  token = "root"

  # Skip TLS verification for local dev
  skip_tls_verify = true
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type = any
}

variable "password" {
  description = "The password for the PostgreSQL database (optional if using vault connection)"
  type        = string
  default     = ""
}

locals {
  # Get vault path from connection if it exists
  vault_path = try(var.context.resource.connections.secretstore.path, "")

  # Extract secret name from path (format: secret/data/secret-name -> secret-name)
  vault_secret_name = local.vault_path != "" ? replace(local.vault_path, "secret/data/", "") : ""
}

# Read password from Vault if connection exists
data "vault_kv_secret_v2" "postgres_secret" {
  count = local.vault_secret_name != "" ? 1 : 0
  mount = "secret"
  name  = local.vault_secret_name
}

locals {
  # Use password from Vault if available, otherwise use the password variable
  postgres_password = local.vault_secret_name != "" ? jsondecode(data.vault_kv_secret_v2.postgres_secret[0].data_json)["password"] : var.password
}

provider "postgresql" {
  host     = "postgres.${var.context.runtime.kubernetes.namespace}.svc.cluster.local"
  port     = 5432
  username = "postgres"
  password = local.postgres_password
  sslmode  = "disable"
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.context.runtime.kubernetes.namespace
  }

  spec {
    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          image = "ghcr.io/radius-project/mirror/postgres:latest"
          name  = "postgres"

          env {
            name  = "POSTGRES_PASSWORD"
            value = local.postgres_password
          }

          port {
            container_port = 5432
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.context.runtime.kubernetes.namespace
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }
  }
}

resource "time_sleep" "wait_120_seconds" {
  depends_on = [kubernetes_service.postgres, kubernetes_deployment.postgres]
  create_duration = "120s"
}

resource "postgresql_database" "pg_db_test" {
  depends_on = [time_sleep.wait_120_seconds]
  name = "pg_db_test"
}
