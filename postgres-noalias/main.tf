terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.16.0"
    }
  }
}

provider "postgresql" {
  depends_on = [null_resource.wait_for_postgres]
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type        = any
}

variable "password" {
  description = "The password for the PostgreSQL database"
  type        = string
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
          image = "postgres:latest"
          name  = "postgres"

          env {
            name  = "POSTGRES_PASSWORD"
            value = var.password
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

resource "null_resource" "wait_for_postgres" {
  depends_on = [
    kubernetes_deployment.postgres,
    kubernetes_service.postgres
  ]

  provisioner "local-exec" {
    command = "kubectl wait --for=condition=ready pod -l app=postgres -n ${var.context.runtime.kubernetes.namespace} --timeout=300s"
  }
}

resource "postgresql_database" "pg_db_test" {
  name = "pg_db_test"

  depends_on = [null_resource.wait_for_postgres]
}