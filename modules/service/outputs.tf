output "connection" {
  value = {
    ip           = local.test_service_ip
    port         = local.test_service_port
    endpoint     = "${local.test_service_ip}:${local.test_service_port}"
    dns_endpoint = "${kubernetes_service.test-service.metadata.0.name}.${var.namespace}.svc.cluster.local:${local.test_service_port}"
  }
}
output "service" {
  value = kubernetes_service.test-service
}
