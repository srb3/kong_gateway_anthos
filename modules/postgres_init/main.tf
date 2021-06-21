resource "kubernetes_job" "kong-migrations" {
  metadata {
    name      = "kong-migrations"
    namespace = var.namespace
    labels    = var.labels
  }
  spec {
    template {
      metadata {
        name   = "kong-migrations"
        labels = var.labels
      }
      spec {
        image_pull_secrets {
          name = "kong-enterprise-edition-docker"
        }
        security_context {
          fs_group            = var.pod_security_context.fs_group
          run_as_group        = var.pod_security_context.run_as_group
          run_as_non_root     = var.pod_security_context.run_as_non_root
          run_as_user         = var.pod_security_context.run_as_user
          supplemental_groups = var.pod_security_context.supplemental_groups
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
          security_context {
            allow_privilege_escalation = var.container_security_context.allow_privilege_escalation
            capabilities {
              add  = var.container_security_context.capabilities.add
              drop = var.container_security_context.capabilities.drop
            }
            privileged                = var.container_security_context.privileged
            read_only_root_filesystem = var.container_security_context.read_only_root_filesystem
            run_as_group              = var.container_security_context.run_as_group
            run_as_non_root           = var.container_security_context.run_as_non_root
            run_as_user               = var.container_security_context.run_as_user
          }
          image = var.kong_image
          name  = "kong-migrations"
          command = [
            "/bin/sh",
            "-c",
            "kong migrations bootstrap"
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
