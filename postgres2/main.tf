terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.16.0"
    }
  }
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type = any
}

variable "password" {
  description = "The password for the PostgreSQL database"
  type        = string
}

resource postgresql_database "pg_db_test" {
  name = "pg_db_test"
}
