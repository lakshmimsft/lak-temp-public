terraform {
  required_version = ">= 1.5"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37.1"
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
  type        = any
}

# Local values for processing secret data
locals {
  secret_data = var.context.resource.properties.data
  secret_kind = try(var.context.resource.properties.kind, "generic")
  secret_name = var.context.resource.name

  # Process secret data for Vault (no need to base64 encode for Vault)
  vault_data = {
    for k, v in local.secret_data : k => (
      try(v.encoding, "") == "base64" ? v.value : v.value
    )
  }

  # Vault path - using kv-v2 secrets engine
  vault_path = "secret/data/${local.secret_name}"

}

resource "vault_kv_secret_v2" "secret" {
  # Validation preconditions - these will stop deployment if they fail
  lifecycle {
    precondition {
      condition = (
        local.secret_kind != "certificate-pem" ||
        (contains(keys(local.secret_data), "tls.crt") &&
         contains(keys(local.secret_data), "tls.key"))
      )
      error_message = "certificate-pem secrets must contain keys tls.crt and tls.key"
    }

    precondition {
      condition = (
        local.secret_kind != "basicAuthentication" ||
        (contains(keys(local.secret_data), "username") &&
         contains(keys(local.secret_data), "password"))
      )
      error_message = "basicAuthentication secrets must contain keys username and password"
    }

    precondition {
      condition = (
        local.secret_kind != "azureWorkloadIdentity" ||
        (contains(keys(local.secret_data), "clientId") &&
         contains(keys(local.secret_data), "tenantId"))
      )
      error_message = "azureWorkloadIdentity secrets must contain keys clientId and tenantId"
    }

    precondition {
      condition = (
        local.secret_kind != "awsIRSA" ||
        contains(keys(local.secret_data), "roleARN")
      )
      error_message = "awsIRSA secrets must contain key roleARN"
    }
  }

  mount = "secret"
  name  = local.secret_name

  data_json = jsonencode(merge(
    local.vault_data,
    {
      resource = var.context.resource.name
      app      = var.context.application != null ? var.context.application.name : ""
      kind     = local.secret_kind
    }
  ))
}

# Create a ConfigMap to track the Vault secret in Kubernetes
resource "kubernetes_config_map" "vault_secret_metadata" {
  metadata {
    name      = local.secret_name
    namespace = var.context.runtime.kubernetes.namespace

    labels = {
      resource      = var.context.resource.name
      app           = var.context.application != null ? var.context.application.name : ""
      "vault-secret" = "true"
    }

    annotations = {
      "vault.hashicorp.com/path" = vault_kv_secret_v2.secret.path
    }
  }

  data = {
    vault_path = vault_kv_secret_v2.secret.path
    vault_mount = vault_kv_secret_v2.secret.mount
  }
}

output "result" {
  value = {
    resources = [
      "/planes/kubernetes/local/namespaces/${kubernetes_config_map.vault_secret_metadata.metadata[0].namespace}/providers/core/ConfigMap/${kubernetes_config_map.vault_secret_metadata.metadata[0].name}"
    ]
    values = {
      id   = vault_kv_secret_v2.secret.id
      path = vault_kv_secret_v2.secret.path
    }
  }
}