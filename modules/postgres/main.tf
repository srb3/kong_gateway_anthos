resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels    = local.append_labels
  }
  spec {
    port {
      name        = "pgql"
      port        = var.kong_database_port
      protocol    = "TCP"
      target_port = 5432
    }
    selector = {
      app = kubernetes_stateful_set.postgres.metadata.0.labels.app
    }
  }
}

locals {
  std_labels    = { "app" = "postgres" }
  append_labels = merge(var.labels, local.std_labels)
  pg_ip         = kubernetes_service.postgres.spec.0.cluster_ip
  pg_port       = kubernetes_service.postgres.spec.0.port.0.port
}

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels    = local.append_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    service_name = "postgres"
    template {
      metadata {
        labels = local.append_labels
      }
      spec {
        security_context {
          fs_group            = var.pod_security_context.fs_group
          run_as_group        = var.pod_security_context.run_as_group
          run_as_non_root     = var.pod_security_context.run_as_non_root
          run_as_user         = var.pod_security_context.run_as_user
          supplemental_groups = var.pod_security_context.supplemental_groups
        }
        container {
          security_context {
            allow_privilege_escalation = var.container_security_context.allow_privilege_escalation
            capabilities {
              add  = var.container_security_context.capabilities.add
              drop = var.container_security_context.capabilities.drop
            }
            privileged                = var.container_security_context.read_only_root_filesystem
            read_only_root_filesystem = var.container_security_context.read_only_root_filesystem
            run_as_group              = var.container_security_context.run_as_group
            run_as_non_root           = var.container_security_context.run_as_non_root
            run_as_user               = var.container_security_context.run_as_user
          }
          env {
            name  = "POSTGRES_USER"
            value = var.kong_database_user
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key  = var.kong_database_secret_name
                name = var.kong_database_secret_name
              }
            }
          }
          env {
            name  = "POSTGRES_DB"
            value = var.kong_database_name
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }
          image = var.postgres_image
          name  = "postgres"
          port {
            container_port = 5432
          }
          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "datadir"
            sub_path   = "pgdata"
          }
        }
        termination_grace_period_seconds = 60
      }
    }
    volume_claim_template {
      metadata {
        name = "datadir"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "16Gi"
          }
        }
      }
    }
  }
}

resource "kubernetes_job" "kong-migrations" {
  metadata {
    name      = "kong-migrations"
    namespace = var.namespace
    labels    = local.append_labels
  }
  spec {
    template {
      metadata {
        name   = "kong-migrations"
        labels = local.append_labels
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
          image = var.busybox_image
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $KONG_PG_HOST $KONG_PG_PORT -w1; do echo 'waiting for db'; sleep 1; done"
          ]
          env {
            name  = "KONG_PG_HOST"
            value = local.pg_ip
          }
          env {
            name  = "KONG_PG_PORT"
            value = local.pg_port
          }
        }
        container {
          security_context {
            allow_privilege_escalation = var.container_security_context.allow_privilege_escalation
            capabilities {
              add  = var.container_security_context.capabilities.add
              drop = var.container_security_context.capabilities.drop
            }
            privileged                = var.container_security_context.read_only_root_filesystem
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
            value = local.pg_ip
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
            value = local.pg_port
          }
        }
      }
    }
  }
}
