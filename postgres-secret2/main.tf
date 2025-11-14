terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.12.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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
  # Get the vault path from the connection's readonly property
  vault_path = var.context.resource.connections.secretstore.status.computedValues.path

  # Extract the secret name from the vault path (format: secret/data/secret-name -> secret-name)
  vault_secret_name = replace(local.vault_path, "secret/data/", "")

  # Use resource name for deployment/service to make them unique
  postgres_name = var.context.resource.name
}

# Read password from Vault using the connection's path
# Note: Using data source (not ephemeral) because the password is used in deployment spec
# which is stored in state. The password itself won't be in state, but referenced.
data "vault_kv_secret_v2" "postgres_secret" {
  mount = "secret"
  name  = local.vault_secret_name
}

locals {
  # Get password from Vault and decode from base64
  vault_password_raw = jsondecode(data.vault_kv_secret_v2.postgres_secret.data_json)["password"]
  postgres_password = base64decode(local.vault_password_raw)
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = local.postgres_name
    namespace = var.context.runtime.kubernetes.namespace
  }

  spec {
    selector {
      match_labels = {
        app = local.postgres_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.postgres_name
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
    name      = local.postgres_name
    namespace = var.context.runtime.kubernetes.namespace
  }

  spec {
    selector = {
      app = local.postgres_name
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

# Create database using kubectl exec instead of postgresql provider to avoid circular dependency
resource "null_resource" "create_database" {
  depends_on = [time_sleep.wait_120_seconds]

  provisioner "local-exec" {
    command = <<-EOT
      for i in {1..30}; do
        kubectl exec -n ${var.context.runtime.kubernetes.namespace} deployment/${local.postgres_name} -- \
          psql -U postgres -c "SELECT 1" > /dev/null 2>&1 && break
        echo "Waiting for postgres to be ready... ($i/30)"
        sleep 10
      done

      kubectl exec -n ${var.context.runtime.kubernetes.namespace} deployment/${local.postgres_name} -- \
        psql -U postgres -c "CREATE DATABASE pg_db_test" || \
        echo "Database may already exist"
    EOT
  }

  triggers = {
    deployment_id = kubernetes_deployment.postgres.id
  }
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
      host = "${local.postgres_name}.${var.context.runtime.kubernetes.namespace}.svc.cluster.local"
      port = 5432
    }
  }
}
