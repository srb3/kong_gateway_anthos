provider "kubernetes" {
  config_path = var.kube_config_file
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
}

# Create two namespaces one for cp and pg and
# one for dp
resource "kubernetes_namespace" "kong" {
  count = length(var.namespaces)
  metadata {
    name = var.namespaces[count.index]
  }
}

module "datadog" {
  count                 = var.deploy_datadog_agents ? 1 : 0
  source                = "./modules/datadog"
  namespace             = local.cp_ns
  api_key_secret        = var.datadog_api_key_secret_name
  deploy_metrics_server = var.deploy_metrics_server
}

module "redis" {
  source    = "./modules/redis"
  namespace = local.cp_ns
}

module "service" {
  source    = "./modules/service"
  namespace = local.cp_ns
}

module "postgres" {
  source                     = "./modules/postgres"
  namespace                  = local.cp_ns
  kong_superuser_secret_name = var.kong_superuser_secret_name
  kong_database_secret_name  = var.kong_database_secret_name
  kong_license_secret_name   = var.kong_license_secret_name
  kong_image                 = var.kong_image
}

module "tls_cluster" {
  source                = "./modules/tls"
  private_key_algorithm = var.tls_cluster.private_key_algorithm
  validity_period_hours = var.validity_period_hours
  ca_common_name        = var.tls_cluster.ca_common_name
  override_common_name  = var.tls_cluster.override_common_name
  namespaces            = var.tls_cluster.namespaces
  certificates          = var.tls_cluster.certificates
}

module "tls_services" {
  source         = "./modules/tls"
  ca_common_name = var.tls_services.ca_common_name
  namespaces     = var.tls_services.namespaces
  certificates   = var.tls_services.certificates
}

module "tls_ingress" {
  source         = "./modules/tls"
  ca_common_name = var.tls_ingress.ca_common_name
  namespaces     = var.tls_ingress.namespaces
  certificates   = var.tls_ingress.certificates
}

locals {

  dp_mounts = concat(module.tls_cluster.namespace_name_map[local.dp_ns],
  module.tls_services.namespace_name_map[local.dp_ns])
  cp_mounts = concat(module.tls_cluster.namespace_name_map[local.cp_ns],
  module.tls_services.namespace_name_map[local.cp_ns])

  services = concat(module.kong-cp.services, module.kong-dp.services)

  cp_ns = kubernetes_namespace.kong.0.metadata[0].name
  dp_ns = kubernetes_namespace.kong.1.metadata[0].name

  proxy        = module.kong-dp.proxy_endpoint
  admin        = module.kong-cp.admin_endpoint
  manager      = module.kong-cp.manager_endpoint
  portal_admin = module.kong-cp.portal_admin_endpoint
  portal_gui   = module.kong-cp.portal_gui_endpoint

  cluster   = module.kong-cp.cluster_endpoint
  telemetry = module.kong-cp.telemetry_endpoint

  kong_cp_deployment_name = "kong-enterprise-cp"
  kong_dp_deployment_name = "kong-enterprise-dp"
  kong_image              = var.kong_image

  kong_image_pull_secrets = [
    {
      name = var.image_pull_secret_name
    }
  ]

  kong_dp_volume_mounts = [for p in local.dp_mounts :
    {
      mount_path = "/etc/secrets/${p}"
      name       = p
      read_only  = true
    }
  ]

  kong_dp_volume_secrets = [for p in local.dp_mounts :
    {
      name        = p
      secret_name = p
    }
  ]

  kong_cp_volume_mounts = [for p in local.cp_mounts :
    {
      mount_path = "/etc/secrets/${p}"
      name       = p
      read_only  = true
    }
  ]

  kong_cp_volume_secrets = [for p in local.cp_mounts :
    {
      name        = p
      secret_name = p
    }
  ]

  #
  # Control plane configuration 
  #
  kong_cp_secret_config = [
    {
      name        = "KONG_LICENSE_DATA"
      secret_name = var.kong_license_secret_name
      key         = var.kong_license_secret_name
    },
    {
      name        = "KONG_ADMIN_GUI_AUTH_CONF"
      secret_name = var.kong_admin_gui_auth_conf_secret_name
      key         = var.kong_admin_gui_auth_conf_secret_name
    },
    {
      name        = "KONG_ADMIN_GUI_SESSION_CONF"
      secret_name = var.kong_admin_gui_session_conf_secret_name
      key         = var.kong_admin_gui_session_conf_secret_name
    },
    {
      name        = "KONG_PORTAL_SESSION_CONF"
      secret_name = var.kong_portal_session_conf_secret_name
      key         = var.kong_portal_session_conf_secret_name
    },
    {
      name        = "KONG_PORTAL_AUTH_CONF"
      secret_name = var.kong_portal_auth_conf_secret_name
      key         = var.kong_portal_auth_conf_secret_name
    },
    {
      name        = "KONG_PG_PASSWORD"
      secret_name = var.kong_database_secret_name
      key         = var.kong_database_secret_name
    }
  ]

  pg_host = lookup(var.kong_control_plane_config, "KONG_PG_HOST", "") == "" ? { "KONG_PG_HOST" = module.postgres.connection.ip } : {}
  pg_port = lookup(var.kong_control_plane_config, "KONG_PG_PORT", "") == "" ? { "KONG_PG_PORT" = module.postgres.connection.port } : {}

  kong_cp_config = merge(var.kong_control_plane_config, local.pg_host, local.pg_port)

  kong_dp_secret_config = [
    {
      name        = "KONG_LICENSE_DATA"
      secret_name = var.kong_license_secret_name
      key         = var.kong_license_secret_name
    }
  ]

}

# Use the Kong module to create a cp
module "kong-cp" {
  source                 = "Kong/kong-gateway/kubernetes"
  version                = "0.0.9"
  deployment_name        = local.kong_cp_deployment_name
  namespace              = local.cp_ns
  deployment_replicas    = var.control_plane_replicas
  config                 = local.kong_cp_config
  secret_config          = local.kong_cp_secret_config
  kong_image             = local.kong_image
  image_pull_secrets     = local.kong_image_pull_secrets
  volume_mounts          = local.kong_cp_volume_mounts
  volume_secrets         = local.kong_cp_volume_secrets
  services               = var.cp_svcs
  load_balancer_services = var.cp_lb_svcs
  deployment_annotations = {
    "ad.datadoghq.com/${local.kong_cp_deployment_name}.check_names"  = "[\"kong\"]"
    "ad.datadoghq.com/${local.kong_cp_deployment_name}.init_configs" = "[{}]"
    "ad.datadoghq.com/${local.kong_cp_deployment_name}.instances"    = "[{\"kong_status_url\": \"http://%%host%%:8001/status/\"}]"
    "ad.datadoghq.com/${local.kong_cp_deployment_name}.logs"         = "[{\"source\":\"kong\",\"service\":\"${local.kong_cp_deployment_name}\"}]"
  }
  ingress    = var.cp_ingress
  depends_on = [kubernetes_namespace.kong]
}

# Use the Kong module to create a dp
module "kong-dp" {
  source                 = "Kong/kong-gateway/kubernetes"
  version                = "0.0.9"
  deployment_name        = local.kong_dp_deployment_name
  namespace              = local.dp_ns
  deployment_replicas    = var.data_plane_replicas
  config                 = var.kong_data_plane_config
  secret_config          = local.kong_dp_secret_config
  kong_image             = local.kong_image
  image_pull_secrets     = local.kong_image_pull_secrets
  volume_mounts          = local.kong_dp_volume_mounts
  volume_secrets         = local.kong_dp_volume_secrets
  services               = var.dp_svcs
  load_balancer_services = var.dp_lb_svcs
  deployment_annotations = {
    "ad.datadoghq.com/${local.kong_dp_deployment_name}.check_names"  = "[\"kong\"]"
    "ad.datadoghq.com/${local.kong_dp_deployment_name}.init_configs" = "[{}]"
    "ad.datadoghq.com/${local.kong_dp_deployment_name}.instances"    = "[{\"kong_status_url\": \"http://%%host%%:8001/status/\"}]"
    "ad.datadoghq.com/${local.kong_dp_deployment_name}.logs"         = "[{\"source\":\"kong\",\"service\":\"${local.kong_dp_deployment_name}\"}]"
  }
  ingress    = var.dp_ingress
  depends_on = [kubernetes_namespace.kong]
}
