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
  # Try multiple ways to get the vault secret name from the connection
  # Option 1: Direct path from connection output values
  vault_path_from_connection = try(var.context.resource.connections.secretstore.path, "")

  # Option 2: Get the secret resource name directly from the connection source
   secret_resource_name = try(split("/", var.context.resource.connections.secretstore.source)[length(split("/", var.context.resource.connections.secretstore.source)) - 1], "")

  # Use whichever is available, prefer the explicit path
  vault_secret_name = local.vault_path_from_connection != "" ? replace(local.vault_path_from_connection, "secret/data/", "") : local.secret_resource_name
}

# Read password from Vault if connection exists
data "vault_kv_secret_v2" "postgres_secret" {
  count = local.vault_secret_name != "" ? 1 : 0
  mount = "secret"
  name  = local.vault_secret_name
}

locals {
  # Use password from Vault if available, otherwise use the password variable
  vault_password_raw = local.vault_secret_name != "" ? jsondecode(data.vault_kv_secret_v2.postgres_secret[0].data_json)["password"] : ""

  # Decode base64 password if it's from Vault (since secrets may be base64 encoded)
  vault_password_decoded = local.vault_password_raw != "" ? base64decode(local.vault_password_raw) : ""

  # Final password: use vault password if available, otherwise use password variable, otherwise use default
  # postgres_password = local.vault_password_decoded != "" ? local.vault_password_decoded : (var.password != "" ? var.password : "defaultpassword")
}

provider "postgresql" {
  host     = "postgres.${var.context.runtime.kubernetes.namespace}.svc.cluster.local"
  port     = 5432
  username = "postgres"
  password = local.vault_password_decoded
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
            value = local.vault_password_decoded
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

output "debug_context" {
  value = {
    full_context = var.context
    connections = try(var.context.resource.connections, {})
    secretstore_connection = try(var.context.resource.connections.secretstore, {})
  }
}

output "result" {
  value = {
    values = {
      host = "postgres.${var.context.runtime.kubernetes.namespace}.svc.cluster.local"
      port = 5432
    }
  }
}
