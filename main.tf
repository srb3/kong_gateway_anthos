provider "kubernetes" {
  config_path = var.kube_config_file
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
}

provider "aws" {
  region                  = var.aws_region
  shared_credentials_file = var.aws_creds_file
}

data "kubernetes_namespace" "control_plane" {
  count = var.existing_namespaces ? 1 : 0
  metadata {
    name = var.namespaces["control_plane"]
  }
}

data "kubernetes_namespace" "data_plane" {
  count = var.existing_namespaces ? 1 : 0
  metadata {
    name = var.namespaces["data_plane"]
  }
}

# Create two namespaces one for cp and pg and
# one for dp
locals {
  ons            = var.namespaces["control_plane"] == var.namespaces["data_plane"]
  tmp_namespaces = tomap(var.existing_namespaces ? {} : local.ons ? { "control_plane" = var.namespaces["control_plane"] } : { for k, v in var.namespaces : k => v })
}

resource "kubernetes_namespace" "kong" {
  for_each = local.tmp_namespaces
  metadata {
    name = terraform.workspace == "default" ? each.value : "${each.value}-${terraform.workspace}"
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

# If no KONG_PG_HOST configuration option is supplied then
# we will deploy a postgres database into the control plane
# namespace
module "postgres" {
  count                      = lookup(var.kong_control_plane_config, "KONG_PG_HOST", "") == "" ? 1 : 0
  source                     = "./modules/postgres"
  namespace                  = local.cp_ns
  kong_superuser_secret_name = var.kong_superuser_secret_name
  kong_database_secret_name  = var.kong_database_secret_name
  kong_license_secret_name   = var.kong_license_secret_name
  kong_image                 = var.kong_image
  kong_database_port         = lookup(var.kong_control_plane_config, "KONG_PG_PORT", "5432")
  kong_database_user         = lookup(var.kong_control_plane_config, "KONG_PG_USER", "kong")
  kong_database_name         = lookup(var.kong_control_plane_config, "KONG_PG_DATABASE", "kong")
}

# I the KONG_PG_HOST configuration option is provided then
# we will run the database init scripts
module "postgres_init" {
  count                      = lookup(var.kong_control_plane_config, "KONG_PG_HOST", "") != "" ? 1 : 0
  source                     = "./modules/postgres_init"
  namespace                  = local.cp_ns
  kong_superuser_secret_name = var.kong_superuser_secret_name
  kong_database_secret_name  = var.kong_database_secret_name
  kong_license_secret_name   = var.kong_license_secret_name
  kong_image                 = var.kong_image
  kong_database_host         = lookup(var.kong_control_plane_config, "KONG_PG_HOST")
  kong_database_port         = lookup(var.kong_control_plane_config, "KONG_PG_PORT", "5432")
  kong_database_user         = lookup(var.kong_control_plane_config, "KONG_PG_USER", "kong")
  kong_database_name         = lookup(var.kong_control_plane_config, "KONG_PG_DATABASE", "kong")
}

module "tls_cluster" {
  source                = "./modules/tls"
  private_key_algorithm = var.tls_cluster.private_key_algorithm
  validity_period_hours = var.validity_period_hours
  ca_common_name        = var.tls_cluster.ca_common_name
  override_common_name  = var.tls_cluster.override_common_name
  namespaces            = var.tls_cluster.namespaces
  namespace_map         = local.namespace_map
  certificates          = var.tls_cluster.certificates
}

module "tls_services" {
  source                = "./modules/tls"
  ca_common_name        = var.tls_services.ca_common_name
  validity_period_hours = var.validity_period_hours
  namespaces            = var.tls_services.namespaces
  namespace_map         = local.namespace_map
  certificates          = var.tls_services.certificates
}

module "tls_ingress" {
  source         = "./modules/tls"
  ca_common_name = var.tls_ingress.ca_common_name
  namespaces     = var.tls_ingress.namespaces
  namespace_map  = local.namespace_map
  certificates   = var.tls_ingress.certificates
}

module "dns_name_proxy" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.proxy_cname
  cname_targets = [replace(module.kong-dp.proxy_ssl_endpoint, local.rp, "")]
}

module "dns_name_devportal" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.portal_gui_cname
  cname_targets = [replace(module.kong-cp.portal_gui_ssl_endpoint, local.rp, "")]
}

module "dns_name_manager" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.manager_cname
  cname_targets = [replace(module.kong-cp.manager_ssl_endpoint, local.rp, "")]
}

module "dns_name_admin" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.admin_cname
  cname_targets = [replace(module.kong-cp.admin_ssl_endpoint, local.rp, "")]
}

module "dns_name_portal_admin" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.portal_admin_cname
  cname_targets = [replace(module.kong-cp.portal_admin_ssl_endpoint, local.rp, "")]
}

locals {

  cp_ns = var.existing_namespaces ? data.kubernetes_namespace.control_plane.0.metadata.0.name : kubernetes_namespace.kong["control_plane"].metadata[0].name
  dp_ns = var.existing_namespaces ? data.kubernetes_namespace.data_plane.0.metadata.0.name : local.ons ? kubernetes_namespace.kong["control_plane"].metadata[0].name : kubernetes_namespace.kong["data_plane"].metadata[0].name

  namespaces = [local.cp_ns, local.dp_ns]

  # this map is needed for secrets creation, so we don't try to store the secrets in the same namesapce twice
  tmp_namespace_map = tomap(local.ons ? { "control_plane" = local.cp_ns } : { "control_plane" = local.cp_ns, "data_plane" = local.dp_ns })

  # this map is needed for tls certificates creation
  namespace_map = {
    "control_plane" = local.cp_ns
    "data_plane"    = local.dp_ns
  }

  ########## Security group injection ############
  # Create a local variable of the hash item we want to inject into
  # the annotation hash of each load balancer service
  sg_item = {
    "service.beta.kubernetes.io/aws-load-balancer-extra-security-groups" = var.sg_passthrough
  }

  # loop through each of the control plane load balancer services
  # keep everything the same but merge sg_item with the other annotations
  cp_lb_svcs_merged_annotations = {
    for k, v in var.cp_lb_svcs :
    k => {
      load_balancer_source_ranges = v.load_balancer_source_ranges
      annotations                 = merge(v.annotations, local.sg_item)
      external_traffic_policy     = v.external_traffic_policy
      health_check_node_port      = v.health_check_node_port
      ports                       = v.ports
    }
  }

  # loop through each of the data plane load balancer services
  # keep everything the same but merge sg_item with the other annotations
  dp_lb_svcs_merged_annotations = {
    for k, v in var.dp_lb_svcs :
    k => {
      load_balancer_source_ranges = v.load_balancer_source_ranges
      annotations                 = merge(v.annotations, local.sg_item)
      external_traffic_policy     = v.external_traffic_policy
      health_check_node_port      = v.health_check_node_port
      ports                       = v.ports
    }
  }

  rp = "/:[0-9]*/"
  dp_mounts = concat(module.tls_cluster.namespace_name_map["data_plane"],
  module.tls_services.namespace_name_map["data_plane"])
  cp_mounts = concat(module.tls_cluster.namespace_name_map["control_plane"],
  module.tls_services.namespace_name_map["control_plane"])

  proxy        = module.kong-dp.proxy_endpoint
  proxy_ssl    = module.kong-dp.proxy_ssl_endpoint
  admin        = module.kong-cp.admin_endpoint
  manager      = module.kong-cp.manager_endpoint
  portal_admin = module.kong-cp.portal_admin_endpoint
  portal_gui   = module.kong-cp.portal_gui_endpoint

  cluster   = module.kong-cp.cluster_endpoint
  telemetry = module.kong-cp.telemetry_endpoint

  kong_cp_deployment_name = var.control_plane_deployment_name
  kong_dp_deployment_name = var.data_plane_deployment_name
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

  # Control plane configuration 

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

  pg_host = lookup(var.kong_control_plane_config, "KONG_PG_HOST", "") == "" ? { "KONG_PG_HOST" = module.postgres.0.connection.ip } : {}
  pg_port = lookup(var.kong_control_plane_config, "KONG_PG_PORT", "") == "" ? { "KONG_PG_PORT" = module.postgres.0.connection.port } : {}

  kong_cp_config = merge(var.kong_control_plane_config, local.pg_host, local.pg_port)

  kong_dp_secret_config = [
    {
      name        = "KONG_LICENSE_DATA"
      secret_name = var.kong_license_secret_name
      key         = var.kong_license_secret_name
    }
  ]

  kong_dp_merge_config = {
    "KONG_CLUSTER_CONTROL_PLANE"      = "kong-cluster.${local.namespace_map["control_plane"]}.svc.cluster.local:8005",
    "KONG_CLUSTER_TELEMETRY_ENDPOINT" = "kong-telemetry.${local.namespace_map["control_plane"]}.svc.cluster.local:8006"
  }

  kong_dp_config = merge(var.kong_data_plane_config, local.kong_dp_merge_config)
}

# Use the Kong module to create a cp
module "kong-cp" {
  source                 = "Kong/kong-gateway/kubernetes"
  version                = "0.0.14"
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
  load_balancer_services = local.cp_lb_svcs_merged_annotations
  enable_autoscaler      = var.enable_autoscaler
  deployment_annotations = {
    "ad.datadoghq.com/${local.kong_cp_deployment_name}.check_names"  = "[\"kong\"]"
    "ad.datadoghq.com/${local.kong_cp_deployment_name}.init_configs" = "[{}]"
    "ad.datadoghq.com/${local.kong_cp_deployment_name}.instances"    = "[{\"kong_status_url\": \"http://%%host%%:8100/status/\"}]"
    "ad.datadoghq.com/${local.kong_cp_deployment_name}.logs"         = "[{\"source\":\"kong\",\"service\":\"${local.kong_cp_deployment_name}\"}]"
  }
  ingress    = var.cp_ingress
  depends_on = [kubernetes_namespace.kong]
}

## Use the Kong module to create a dp
module "kong-dp" {
  source                 = "Kong/kong-gateway/kubernetes"
  version                = "0.0.14"
  deployment_name        = local.kong_dp_deployment_name
  namespace              = local.dp_ns
  deployment_replicas    = var.data_plane_replicas
  config                 = local.kong_dp_config
  secret_config          = local.kong_dp_secret_config
  kong_image             = local.kong_image
  image_pull_secrets     = local.kong_image_pull_secrets
  volume_mounts          = local.kong_dp_volume_mounts
  volume_secrets         = local.kong_dp_volume_secrets
  services               = var.dp_svcs
  load_balancer_services = local.dp_lb_svcs_merged_annotations
  enable_autoscaler      = var.enable_autoscaler
  deployment_annotations = {
    "ad.datadoghq.com/${local.kong_dp_deployment_name}.check_names"  = "[\"kong\"]"
    "ad.datadoghq.com/${local.kong_dp_deployment_name}.init_configs" = "[{}]"
    "ad.datadoghq.com/${local.kong_dp_deployment_name}.instances"    = "[{\"kong_status_url\": \"http://%%host%%:8100/status/\"}]"
    "ad.datadoghq.com/${local.kong_dp_deployment_name}.logs"         = "[{\"source\":\"kong\",\"service\":\"${local.kong_dp_deployment_name}\"}]"
  }
  ingress    = var.dp_ingress
  depends_on = [kubernetes_namespace.kong]
}
