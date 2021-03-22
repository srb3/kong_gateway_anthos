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

resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = var.namespace
    labels = {
      app = "redis"
    }
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
        labels = {
          app = "redis"
        }
      }
      spec {
        container {
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

