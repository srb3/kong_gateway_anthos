resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = var.namespace
  }
  spec {
    port {
      name        = "redis"
      port        = 6379
      protocol    = "TCP"
      target_port = 6379
    }
    selector = {
      app = kubernetes_deployment.redis.metadata.0.labels.app
    }
  }
}

locals {
  std_labels    = { "app" = "redis" }
  append_labels = merge(var.labels, local.std_labels)
}

resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = var.namespace
    labels    = local.append_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "redis"
      }
    }
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
          image = "gcr.io/google-containers/redis"
          name  = "redis"
        }
      }
    }
  }
}

locals {
  redis_ip   = kubernetes_service.redis.spec.0.cluster_ip
  redis_port = kubernetes_service.redis.spec.0.port.0.port
}

