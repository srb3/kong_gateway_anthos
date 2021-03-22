output "connection" {
  value = {
    ip           = local.redis_ip
    port         = local.redis_port
    endpoint     = "${local.redis_ip}:${local.redis_port}"
    dns_endpoint = "${kubernetes_service.redis.metadata.0.name}.${var.namespace}.svc.cluster.local:${local.redis_port}"
  }
}
output "service" {
  value = kubernetes_service.redis
}
