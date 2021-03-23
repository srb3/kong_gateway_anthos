resource "helm_release" "datadog" {
  name       = var.chart.name
  repository = var.chart.repository
  chart      = var.chart.chart
  version    = var.chart.version

  namespace = var.namespace
  values    = [file("${path.module}/../../helm_values/datadog.yml")]

  set {
    name  = "datadog.apiKeyExistingSecret"
    value = var.api_key_secret
    type  = "auto"
  }

  dynamic "set" {
    for_each = var.chart.values
    content {
      name  = set.key
      value = set.value.value
      type  = set.value.type != null ? set.value.type : "auto"
    }
  }
  provisioner "local-exec" {
    command = "sleep 30"
  }
}

resource "kubernetes_service" "datadog-statsd" {
  metadata {
    name = "datadog-statsd"
    annotations = {
      name = "datadog-statsd"
    }
  }
  spec {
    selector = {
      app = "datadog"
    }
    port {
      name        = "statsd"
      port        = 8125
      protocol    = "UDP"
      target_port = 8125
    }
    session_affinity = "None"
    type             = "ClusterIP"
  }
}

resource "helm_release" "helm" {
  name       = "metrics-server"
  repository = "https://charts.helm.sh/stable"
  chart      = "metrics-server"
  namespace  = "kube-system"
}
