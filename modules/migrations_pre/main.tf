resource "kubernetes_job" "demo" {
  metadata {
    name      = "kong-migrations-pre"
    namespace = var.namespace
  }
  spec {
    template {
      metadata {
        name = "kong-migrations-pre"
      }
      spec {
        image_pull_secrets {
          name = "kong-enterprise-edition-docker"
        }
        restart_policy = "OnFailure"
        init_container {
          name  = "wait-for-postgres"
          image = "busybox"
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $KONG_PG_HOST $KONG_PG_PORT -w1; do echo 'waiting for db'; sleep 1; done"
          ]
          env {
            name  = "KONG_PG_HOST"
            value = var.kong_database_host
          }
          env {
            name  = "KONG_PG_PORT"
            value = var.kong_database_port
          }
        }
        container {
          image = var.kong_image
          name  = "kong-migrations-pre"
          command = [
            "/bin/sh",
            "-c",
            "kong migrations up"
          ]
          env {
            name = "KONG_LICENSE_DATA"
            value_from {
              secret_key_ref {
                key  = var.kong_license_secret_name
                name = var.kong_license_secret_name
              }
            }
          }
          env {
            name = "KONG_PASSWORD"
            value_from {
              secret_key_ref {
                key  = var.kong_superuser_secret_name
                name = var.kong_superuser_secret_name
              }
            }
          }
          env {
            name = "KONG_PG_PASSWORD"
            value_from {
              secret_key_ref {
                key  = var.kong_database_secret_name
                name = var.kong_database_secret_name
              }
            }
          }
          env {
            name  = "KONG_DATABASE"
            value = "postgres"
          }
          env {
            name  = "KONG_PG_HOST"
            value = var.kong_database_host
          }
          env {
            name  = "KONG_PG_USER"
            value = var.kong_database_user
          }
          env {
            name  = "KONG_PG_DATABASE"
            value = var.kong_database_name
          }
          env {
            name  = "KONG_PORT"
            value = var.kong_database_port
          }
        }
      }
    }
  }
}
