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

variable "password" {
  description = "The password for the PostgreSQL database"
  type        = string
}

variable "host" {
  description = "The host for the PostgreSQL database"
  type        = string
  default     = "postgres.pgs-resources-pgsql-default-recipe-app.svc.cluster.local"
}

variable "port" {
  default = 5432
}

variable "context" {
  description = "This variable contains Radius recipe context."

  type = any
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

provider "postgresql" {
  host     = "postgres.pgs-resources-pgsql-default-recipe-app.svc.cluster.local"
  port     = var.port
  password = var.password
  sslmode  = "disable"
}

resource "null_resource" "delay" {
  provisioner "local-exec" {
    command = "sleep 60"
  }
  triggers = {
    service_name = kubernetes_service.postgres.metadata[0].name
  }
}

resource "postgresql_database" "pg_db_test" {
  depends_on = [null_resource.delay]
  name = "pg_db_test"
}
