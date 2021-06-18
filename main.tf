########### Provider Setup #######################

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

########### Namespace Logic ######################

# For namespaces we need to cater for a few scenarios
# Creating namespaces
#  * one namespace for control plane, one for data plane
#  * one namespace for control plane, one for data plane, one for extra data plane
#  * one namespace shared by control plane and data plane and extra data plane
#  * one namespace shared by control plane and data plane, one namespace for extra data plane
#  * one namespace shared by control plane and extra data plane, one namespace for data plane
#  * one namespace shared by data plane and extra data plane, one namespace for control plane
# Using existing namespaces
# Use a data source to gather the namespace being used for
#  * control plane
#  * data plane
#  * extra data plane

# Create three data sources if existing_namespaces is set to true
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

# The third data source is optional and only used if we are enabling the
# the extra data plane
data "kubernetes_namespace" "data_plane_ext" {
  count = var.existing_namespaces ? local.extra_ns ? 1 : 0 : 0
  metadata {
    name = var.namespaces["data_plane_ext"]
  }
}

locals {
  # check if we are creating only one namespace, we use this variable as a short
  # cut later
  one_ns = length(distinct(compact(values(var.namespaces)))) == 1

  # work out if we are creating the extra data plane. If there is a value for
  # data_plane_ext in the namespaces map then we will create it,
  # or look it up if we existing_namespaces is set to true
  extra_dp = lookup(var.namespaces, "data_plane_ext", null) != null

  # does the extra data plane have it's own namespace, work out if we need to
  # create a namespace for the extra data plane
  extra_ns = (
    local.extra_dp ?
    var.namespaces["data_plane_ext"] != var.namespaces["data_plane"] ?
    var.namespaces["data_plane_ext"] != var.namespaces["control_plane"] ?
    true :
    false :
    false :
    false
  )

  # create a list of unique namespaces, we use unique list of namespaces to make
  # sure we only create the namespaces we need, and don't try to create the same 
  # one twice if the instance types share a namespace
  unique_ns = distinct(compact(values(var.namespaces)))

  # either use existing namespaces or make a map to create new ones, if this
  # map is empty (which is the case if we want to use existing namespaces)
  # then we don't create any namespaces, otherwise we use the unique_ns local
  # var to work out what namespaces to create. The unique_ns list contains
  # a unique list of namesapces.
  namespaces_to_create = (
    var.existing_namespaces ?
    {} :
    local.one_ns ?
    {
      "control_plane" = local.unique_ns[0]
    } :
    length(local.unique_ns) == 2 ?
    {
      "control_plane" = local.unique_ns[0],
      "data_plane"    = local.unique_ns[1]
    } :
    {
      "control_plane"  = local.unique_ns[0],
      "data_plane"     = local.unique_ns[1],
      "data_plane_ext" = local.unique_ns[2]
    }
  )

  # Place the namespaces into their local variables, namespaces can be derived
  # from existing or created namespaces, and in the case of the extra data plane
  # namespaces may not exist at all
  cp_ns = (
    var.existing_namespaces ?
    data.kubernetes_namespace.control_plane.0.metadata.0.name :
    kubernetes_namespace.kong["control_plane"].metadata[0].name
  )
  dp_ns = (
    var.existing_namespaces ?
    data.kubernetes_namespace.data_plane.0.metadata.0.name :
    local.one_ns ?
    kubernetes_namespace.kong["control_plane"].metadata[0].name :
    kubernetes_namespace.kong["data_plane"].metadata[0].name
  )
  dp_ext_ns = (
    local.extra_ns ?
    var.existing_namespaces ?
    data.kubernetes_namespace.data_plane_ext.0.metadata.0.name :
    local.one_ns ?
    kubernetes_namespace.kong["control_plane"].metadata[0].name :
    kubernetes_namespace.kong["data_plane_ext"].metadata[0].name :
    local.extra_dp ?
    var.namespaces["data_plane_ext"] :
    null
  )

  # this map is needed for secrets creation, so we don't try to store the secrets in the same namespace twice
  tmp_namespace_map = (
    local.one_ns ?
    { "control_plane" = local.cp_ns } :
    local.extra_ns ?
    {
      "control_plane"  = local.cp_ns,
      "data_plane"     = local.dp_ns,
      "data_plane_ext" = local.dp_ext_ns
    } :
    {
      "control_plane" = local.cp_ns,
      "data_plane"    = local.dp_ns
    }
  )

  # this map is needed for tls certificates creation
  certificate_namespace_map = {
    "control_plane"  = local.cp_ns,
    "data_plane"     = local.dp_ns,
    "data_plane_ext" = local.dp_ext_ns
  }
}

# Create the namespaces we need to
resource "kubernetes_namespace" "kong" {
  for_each = local.namespaces_to_create
  metadata {
    name = terraform.workspace == "default" ? each.value : "${each.value}-${terraform.workspace}"
  }
}

########### Supporting Deployments ###############

module "datadog" {
  count                 = var.deploy_datadog_agents ? 1 : 0
  source                = "./modules/datadog"
  namespace             = local.cp_ns
  api_key_secret        = var.datadog_api_key_secret_name
  deploy_metrics_server = var.deploy_metrics_server
}

module "redis" {
  count     = var.deploy_redis ? 1 : 0
  source    = "./modules/redis"
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

############ Kong Migrations #####################

module "kong_migrations_pre" {
  count                      = var.kong_migrations_pre ? 1 : 0
  source                     = "./modules/migrations_pre"
  namespace                  = local.cp_ns
  kong_superuser_secret_name = var.kong_superuser_secret_name
  kong_database_secret_name  = var.kong_database_secret_name
  kong_license_secret_name   = var.kong_license_secret_name
  kong_image                 = var.kong_image
  kong_database_host         = lookup(var.kong_control_plane_config, "KONG_PG_HOST", null) != null ? var.kong_control_plane_config["KONG_PG_HOST"] : module.postgres.0.connection.ip
  kong_database_port         = lookup(var.kong_control_plane_config, "KONG_PG_PORT", null) != null ? var.kong_control_plane_config["KONG_PG_PORT"] : module.postgres.0.connection.port
  kong_database_user         = lookup(var.kong_control_plane_config, "KONG_PG_USER", "kong")
  kong_database_name         = lookup(var.kong_control_plane_config, "KONG_PG_DATABASE", "kong")
}

module "kong_migrations_post" {
  count                      = var.kong_migrations_post ? 1 : 0
  source                     = "./modules/migrations_post"
  namespace                  = local.cp_ns
  kong_superuser_secret_name = var.kong_superuser_secret_name
  kong_database_secret_name  = var.kong_database_secret_name
  kong_license_secret_name   = var.kong_license_secret_name
  kong_image                 = var.kong_image
  kong_database_host         = lookup(var.kong_control_plane_config, "KONG_PG_HOST", null) != null ? var.kong_control_plane_config["KONG_PG_HOST"] : module.postgres.0.connection.ip
  kong_database_port         = lookup(var.kong_control_plane_config, "KONG_PG_PORT", null) != null ? var.kong_control_plane_config["KONG_PG_PORT"] : module.postgres.0.connection.port
  kong_database_user         = lookup(var.kong_control_plane_config, "KONG_PG_USER", "kong")
  kong_database_name         = lookup(var.kong_control_plane_config, "KONG_PG_DATABASE", "kong")
  depends_on                 = [module.kong_migrations_pre, module.kong-cp]
}

########### Certificate Creation #################

module "tls_cluster" {
  source                = "./modules/tls"
  private_key_algorithm = var.tls_cluster.private_key_algorithm
  validity_period_hours = var.validity_period_hours
  ca_common_name        = var.tls_cluster.ca_common_name
  override_common_name  = var.tls_cluster.override_common_name
  namespaces            = var.tls_cluster.namespaces
  namespace_map         = local.certificate_namespace_map
  certificates          = var.tls_cluster.certificates
}

########### DNS Creation #########################
locals {

  # This regex is used to extract the fqdn from the kong service endpoint urls
  port_replace_regex = "/:[0-9]*/"
  # These local vars are used to create the DNS targets
  proxy        = replace(module.kong-dp.proxy_ssl_endpoint, local.port_replace_regex, "")
  proxy_ext    = replace(local.extra_dp ? module.kong-dp-ext.0.proxy_ssl_endpoint : "", local.port_replace_regex, "")
  admin        = replace(module.kong-cp.admin_ssl_endpoint, local.port_replace_regex, "")
  manager      = replace(module.kong-cp.manager_ssl_endpoint, local.port_replace_regex, "")
  portal_admin = replace(module.kong-cp.portal_admin_ssl_endpoint, local.port_replace_regex, "")
  portal_gui   = replace(module.kong-cp.portal_gui_ssl_endpoint, local.port_replace_regex, "")
}

module "dns_name_proxy" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.proxy_cname
  cname_targets = [local.proxy]
}

module "dns_name_proxy_ext" {
  count         = local.extra_dp ? var.route53_zone_id != "" ? 1 : 0 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.proxy_ext_cname
  cname_targets = [local.proxy_ext]
}

module "dns_name_devportal" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.portal_gui_cname
  cname_targets = [local.portal_gui]
}

module "dns_name_manager" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.manager_cname
  cname_targets = [local.manager]
}

module "dns_name_admin" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.admin_cname
  cname_targets = [local.admin]
}

module "dns_name_portal_admin" {
  count         = var.route53_zone_id != "" ? 1 : 0
  source        = "./modules/route53"
  zone_id       = var.route53_zone_id
  cname_name    = var.portal_admin_cname
  cname_targets = [local.portal_admin]
}

# The following local variables are used to create
# any runtime configuration for out Kong deployments
locals {

  ########## Security group injection ############
  # Create a local variable of the hash item we want to inject into
  # the annotation hash of each load balancer service
  sg_item = {
    "service.beta.kubernetes.io/aws-load-balancer-extra-security-groups" = var.sg_passthrough
  }

  # loop through each of the control plane services
  # keep everything the same but merge sg_item with the other annotations
  cp_svcs_merged_annotations = {
    for k, v in var.cp_svcs :
    k => {
      annotations = v.type == "LoadBalancer" ? merge(v.annotations, local.sg_item) : v.annotations
      labels      = v.labels
      type        = v.type
      ports       = v.ports
    }
  }

  # loop through each of the data plane load balancer services
  # keep everything the same but merge sg_item with the other annotations
  dp_svcs_merged_annotations = {
    for k, v in var.dp_svcs :
    k => {
      annotations = merge(v.annotations, local.sg_item)
      annotations = v.type == "LoadBalancer" ? merge(v.annotations, local.sg_item) : v.annotations
      labels      = v.labels
      type        = v.type
      ports       = v.ports
    }
  }

  # loop through each of the extra data plane load balancer services
  # keep everything the same but merge sg_item with the other annotations
  dp_ext_svcs_merged_annotations = {
    for k, v in var.dp_ext_svcs :
    k => {
      annotations = v.type == "LoadBalancer" ? merge(v.annotations, local.sg_item) : v.annotations
      labels      = v.labels
      type        = v.type
      ports       = v.ports
    }
  }

  # Image pull secret, will be added into each Kong deployment
  kong_image_pull_secrets = [
    {
      name = var.image_pull_secret_name
    }
  ]

  # The tls modules provide output of the secretes we have created for the mutual tls and the service
  # endpoints. They are all tls certificate types and are used to secure the Kong service endpoints.
  # Here we concat them together to make a list of secret volumes we can mount in the Kong
  # containers
  #cp_mounts     = concat(module.tls_cluster.namespace_name_map["control_plane"], module.tls_services.namespace_name_map["control_plane"])
  #dp_mounts     = concat(module.tls_cluster.namespace_name_map["data_plane"], module.tls_services.namespace_name_map["data_plane"])
  #dp_ext_mounts = local.extra_dp ? concat(module.tls_cluster.namespace_name_map["data_plane_ext"], module.tls_services.namespace_name_map["data_plane_ext"]) : []
  cp_mounts     = concat(module.tls_cluster.namespace_name_map["control_plane"])
  dp_mounts     = concat(module.tls_cluster.namespace_name_map["data_plane"])
  dp_ext_mounts = local.extra_dp ? concat(module.tls_cluster.namespace_name_map["data_plane_ext"]) : []

  # Loop through the secrets to specify the mount points
  # and the name of the volume secret to attach to it
  kong_dp_volume_mounts = [for p in local.dp_mounts :
    {
      mount_path = "/etc/secrets/${p}"
      name       = p
      read_only  = true
    }
  ]

  # Loop through the secrets to specify the volume secrets.
  # The volume secrets map a name to a secret name.
  # The volume mounts above ling the volume secret name to a
  # mount point on the pod file system
  kong_dp_volume_secrets = [for p in local.dp_mounts :
    {
      name        = p
      secret_name = p
    }
  ]

  # Loop through the secrets to specify the mount points
  # and the name of the volume secret to attach to it
  kong_dp_ext_volume_mounts = [for p in local.dp_ext_mounts :
    {
      mount_path = "/etc/secrets/${p}"
      name       = p
      read_only  = true
    }
  ]

  # Loop through the secrets to specify the volume secrets.
  # The volume secrets map a name to a secret name.
  # The volume mounts above ling the volume secret name to a
  # mount point on the pod file system
  kong_dp_ext_volume_secrets = [for p in local.dp_ext_mounts :
    {
      name        = p
      secret_name = p
    }
  ]

  # Loop through the secrets to specify the mount points
  # and the name of the volume secret to attach to it
  kong_cp_volume_mounts = [for p in local.cp_mounts :
    {
      mount_path = "/etc/secrets/${p}"
      name       = p
      read_only  = true
    }
  ]

  # Loop through the secrets to specify the volume secrets.
  # The volume secrets map a name to a secret name.
  # The volume mounts above ling the volume secret name to a
  # mount point on the pod file system
  kong_cp_volume_secrets = [for p in local.cp_mounts :
    {
      name        = p
      secret_name = p
    }
  ]

  # Control plane secret configuration. This is configuration
  # we inject into the control plane at runtime due to its sensitive nature.
  # This allows us to consume sensitive configuration from the kubernetes secret
  # store.
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

  # Data plane secret configuration. This is configuration
  # we inject into the control plane at runtime due to its sensitive nature.
  # This allows us to consume sensitive configuration from the kubernetes secret
  # store.
  kong_dp_secret_config = [
    {
      name        = "KONG_LICENSE_DATA"
      secret_name = var.kong_license_secret_name
      key         = var.kong_license_secret_name
    }
  ]

  # Extra data plane secret configuration. This is configuration
  # we inject into the control plane at runtime due to its sensitive nature.
  # This allows us to consume sensitive configuration from the kubernetes secret
  # store.   
  kong_dp_ext_secret_config = [
    {
      name        = "KONG_LICENSE_DATA"
      secret_name = var.kong_license_secret_name
      key         = var.kong_license_secret_name
    }
  ]

  # In some scenarios we want to connect to an external postgres and in other we connect to a postgresql
  # instance created by this module. The following loginc looks for the KONG_PG_HOST and KONG_PG_PORT
  # config settings in kong_control_plane_config if it does not find them we assume this module
  # created a postgresql instance and inject those details into the control plane config : module.
  pg_host = lookup(var.kong_control_plane_config, "KONG_PG_HOST", "") == "" ? { "KONG_PG_HOST" = module.postgres.0.connection.ip } : {}
  pg_port = lookup(var.kong_control_plane_config, "KONG_PG_PORT", "") == "" ? { "KONG_PG_PORT" = module.postgres.0.connection.port } : {}

  # Merge the pg_host and pg_port detilas into the main kong control plain config
  kong_cp_config = merge(var.kong_control_plane_config, local.pg_host, local.pg_port)

  # We will only know the cluster and telemetry addresses at run time
  # the followig hash gets merged into the main data plane configuration
  kong_dp_merge_config = {
    "KONG_CLUSTER_CONTROL_PLANE"      = "kong-cluster.${local.cp_ns}.svc.cluster.local:8005",
    "KONG_CLUSTER_TELEMETRY_ENDPOINT" = "kong-telemetry.${local.cp_ns}.svc.cluster.local:8006"
  }

  # We will only know the cluster and telemetry addresses at run time
  # the followig hash gets merged into the main extra data plane configuration
  kong_dp_ext_merge_config = {
    "KONG_CLUSTER_CONTROL_PLANE"      = "kong-cluster.${local.cp_ns}.svc.cluster.local:8005",
    "KONG_CLUSTER_TELEMETRY_ENDPOINT" = "kong-telemetry.${local.cp_ns}.svc.cluster.local:8006"
  }

  # Merge the static config supplied by the kong_data_plane_config variable
  # with any dynamic config we have created
  kong_dp_config     = merge(var.kong_data_plane_config, local.kong_dp_merge_config)
  kong_dp_ext_config = merge(var.kong_data_plane_ext_config, local.kong_dp_ext_merge_config)

}

# At this point we call the kong module, with all of the configuation
# needed to deploy a control plane
module "kong-cp" {
  source              = "Kong/kong-gateway/kubernetes"
  version             = "0.0.18"
  deployment_name     = var.control_plane_deployment_name
  namespace           = local.cp_ns
  deployment_replicas = var.control_plane_replicas
  config              = local.kong_cp_config
  secret_config       = local.kong_cp_secret_config
  kong_image          = var.kong_image
  image_pull_secrets  = local.kong_image_pull_secrets
  volume_mounts       = local.kong_cp_volume_mounts
  volume_secrets      = local.kong_cp_volume_secrets
  services            = local.cp_svcs_merged_annotations
  enable_autoscaler   = var.enable_autoscaler
  deployment_annotations = {
    "ad.datadoghq.com/${var.control_plane_deployment_name}.check_names"  = "[\"kong\"]"
    "ad.datadoghq.com/${var.control_plane_deployment_name}.init_configs" = "[{}]"
    "ad.datadoghq.com/${var.control_plane_deployment_name}.instances"    = "[{\"kong_status_url\": \"http://%%host%%:8100/status/\"}]"
    "ad.datadoghq.com/${var.control_plane_deployment_name}.logs"         = "[{\"source\":\"kong\",\"service\":\"${var.control_plane_deployment_name}\"}]"
  }
  ingress    = var.cp_ingress
  depends_on = [kubernetes_namespace.kong, module.kong_migrations_pre]
}

# At this point we call the kong module, with all of the configuation
# needed to deploy a data plane
module "kong-dp" {
  source              = "Kong/kong-gateway/kubernetes"
  version             = "0.0.18"
  deployment_name     = var.data_plane_deployment_name
  namespace           = local.dp_ns
  deployment_replicas = var.data_plane_replicas
  config              = local.kong_dp_config
  secret_config       = local.kong_dp_secret_config
  kong_image          = var.kong_image
  image_pull_secrets  = local.kong_image_pull_secrets
  volume_mounts       = local.kong_dp_volume_mounts
  volume_secrets      = local.kong_dp_volume_secrets
  services            = local.dp_svcs_merged_annotations
  enable_autoscaler   = var.enable_autoscaler
  deployment_annotations = {
    "ad.datadoghq.com/${var.data_plane_deployment_name}.check_names"  = "[\"kong\"]"
    "ad.datadoghq.com/${var.data_plane_deployment_name}.init_configs" = "[{}]"
    "ad.datadoghq.com/${var.data_plane_deployment_name}.instances"    = "[{\"kong_status_url\": \"http://%%host%%:8100/status/\"}]"
    "ad.datadoghq.com/${var.data_plane_deployment_name}.logs"         = "[{\"source\":\"kong\",\"service\":\"${var.data_plane_deployment_name}\"}]"
  }
  ingress    = var.dp_ingress
  depends_on = [kubernetes_namespace.kong, module.kong_migrations_pre, module.kong_migrations_post]
}

# If needed we can deploy an extra set of data planes.
module "kong-dp-ext" {
  count               = local.extra_dp ? 1 : 0
  source              = "Kong/kong-gateway/kubernetes"
  version             = "0.0.18"
  deployment_name     = var.data_plane_ext_deployment_name
  namespace           = local.dp_ext_ns
  deployment_replicas = var.data_plane_ext_replicas
  config              = local.kong_dp_ext_config
  secret_config       = local.kong_dp_ext_secret_config
  kong_image          = var.kong_image
  image_pull_secrets  = local.kong_image_pull_secrets
  volume_mounts       = local.kong_dp_ext_volume_mounts
  volume_secrets      = local.kong_dp_ext_volume_secrets
  services            = local.dp_ext_svcs_merged_annotations
  enable_autoscaler   = var.enable_autoscaler
  deployment_annotations = {
    "ad.datadoghq.com/${var.data_plane_ext_deployment_name}.check_names"  = "[\"kong\"]"
    "ad.datadoghq.com/${var.data_plane_ext_deployment_name}.init_configs" = "[{}]"
    "ad.datadoghq.com/${var.data_plane_ext_deployment_name}.instances"    = "[{\"kong_status_url\": \"http://%%host%%:8100/status/\"}]"
    "ad.datadoghq.com/${var.data_plane_ext_deployment_name}.logs"         = "[{\"source\":\"kong\",\"service\":\"${var.data_plane_ext_deployment_name}\"}]"
  }
  ingress    = var.dp_ext_ingress
  depends_on = [kubernetes_namespace.kong, module.kong_migrations_pre, module.kong_migrations_post]
}
