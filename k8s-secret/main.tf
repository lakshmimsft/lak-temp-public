terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11"
    }
  }
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type        = any
}

# Local values for processing secret data
locals {
  secret_data = var.context.resource.properties.data
  secret_kind = coalesce(var.context.resource.properties.kind, "generic")
  secret_name = context.resource.name
  
  # Separate base64 and string data
  base64_data = {
    for k, v in local.secret_data : k => v.value
    if v.encoding == "base64"
  }
  
  string_data = {
    for k, v in local.secret_data : k => v.value
    if v.encoding != "base64"
  }
  
  # Determine Kubernetes secret type
  secret_type = (
    local.secret_kind == "certificate-pem" ? "kubernetes.io/tls" :
    local.secret_kind == "basicAuthentication" ? "kubernetes.io/basic-auth" :
    "Opaque"
  )
  
}

# Validation using check blocks (Terraform 1.5+)
check "certificate_pem_validation" {
  assert {
    condition = (
      local.secret_kind != "certificate-pem" || 
      (contains(keys(local.secret_data), "tls.crt") && 
       contains(keys(local.secret_data), "tls.key"))
    )
    error_message = "certificate-pem secrets must contain keys tls.crt and tls.key"
  }
}

check "basic_auth_validation" {
  assert {
    condition = (
      local.secret_kind != "basicAuthentication" ||
      (contains(keys(local.secret_data), "username") && 
       contains(keys(local.secret_data), "password"))
    )
    error_message = "basicAuthentication secrets must contain keys username and password"
  }
}

check "azure_workload_identity_validation" {
  assert {
    condition = (
      local.secret_kind != "azureWorkloadIdentity" ||
      (contains(keys(local.secret_data), "clientId") && 
       contains(keys(local.secret_data), "tenantId"))
    )
    error_message = "azureWorkloadIdentity secrets must contain keys clientId and tenantId"
  }
}

check "aws_irsa_validation" {
  assert {
    condition = (
      local.secret_kind != "awsIRSA" ||
      contains(keys(local.secret_data), "roleARN")
    )
    error_message = "awsIRSA secrets must contain key roleARN"
  }
}

# Create Kubernetes secret
resource "kubernetes_secret" "secret" {
  
  metadata {
    name      = local.secret_name
    namespace = var.context.runtime.kubernetes.namespace
    
    labels = {
      resource = var.context.resource.name
      app      = var.context.application != null ? var.context.application.name : ""
    }
  }
  
  type = local.secret_type
  
  # Use data for base64-encoded values
  data = local.base64_data
  
  # Use binary_data for plain text values (Kubernetes will base64 encode them)
  binary_data = local.string_data
}

output result object = {
  resources: [
    '/planes/kubernetes/local/namespaces/${context.runtime.kubernetes.namespace}/providers/core/Secret/${secretName}'
  ]
}