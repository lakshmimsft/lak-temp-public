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

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = "postgresns"
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
    namespace = "postgresns"
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

variable "host" {
  default = "postgres.pgs-resources-pgsql-default-recipe-app.svc.cluster.local"
}

variable "port" {
  default = 5432
}

provider "postgresql" {
  host     = var.host
  port     = var.port
  password = var.password
  sslmode  = "disable"
}

resource postgresql_database "pg_db_test" {
  name = "pg_db_test"
}
