terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.16.0"
      configuration_aliases = [postgresql.pgdb-test1]
    }
  }
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type = any
}

variable "password1" {
  description = "The password for the PostgreSQL1 database"
  type        = string
}

variable "password" {
  description = "The password for the PostgreSQL database"
  type        = string
  default     = "pg_default_pwd"
}

resource "kubernetes_deployment" "postgres1" {
  metadata {
    name      = "postgres1"
    namespace = var.context.runtime.kubernetes.namespace
  }

  spec {
    selector {
      match_labels = {
        app = "postgres1"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres1"
        }
      }

      spec {
        container {
          image = "postgres:latest"
          name  = "postgres1"

          env {
            name  = "POSTGRES_PASSWORD"
            value = var.password1
          }

          port {
            container_port = 5432
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres1" {
  metadata {
    name      = "postgres1"
    namespace = var.context.runtime.kubernetes.namespace
  }

  spec {
    selector = {
      app = "postgres1"
    }

    port {
      port        = 5432
      target_port = 5432
    }
  }
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

resource "time_sleep" "wait_20_seconds" {
  depends_on = [kubernetes_service.postgres1, kubernetes_service.postgres]
  create_duration = "20s"
}

resource "postgresql_database" "pg_db_test1" {
  provider = postgresql.pgdb-test1
  depends_on = [time_sleep.wait_20_seconds]
  name = "pg_db_test1"
}

resource "postgresql_database" "pg_db_test" {
  depends_on = [time_sleep.wait_20_seconds]
  name = "pg_db_test"
}
