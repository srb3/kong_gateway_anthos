resource "kubernetes_service" "test-service" {
  metadata {
    name      = "test-service"
    namespace = var.namespace
  }
  spec {
    port {
      name        = "test-service"
      port        = 80
      protocol    = "TCP"
      target_port = 80
    }
    selector = {
      app = kubernetes_deployment.test-service.metadata.0.labels.app
    }
  }
}

resource "kubernetes_deployment" "test-service" {
  metadata {
    name      = "test-service"
    namespace = var.namespace
    labels = {
      app = "test-service"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "test-service"
      }
    }
    template {
      metadata {
        labels = {
          app = "test-service"
        }
      }
      spec {
        container {
          image = "docker.io/kennethreitz/httpbin"
          name  = "test-service"
        }
      }
    }
  }
}

locals {
  test_service_ip   = kubernetes_service.test-service.spec.0.cluster_ip
  test_service_port = kubernetes_service.test-service.spec.0.port.0.port
}

