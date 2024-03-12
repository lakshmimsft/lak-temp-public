terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.16.0"
    }
  }
}

variable "host" {
  default = "localhost"
}

variable "password" {
  default = "adm"
}

variable "port" {
  default = 55432
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