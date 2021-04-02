variable "kong_image" {
  description = "The kong container image file to use"
  type        = string
  default     = "kong-docker-kong-enterprise-edition-docker.bintray.io/kong-enterprise-edition:2.3.2.0-alpine"
}

variable "kube_config_file" {
  description = "Path to the kubernetes configuration file. Used by the terraform provider"
  type        = string
  default     = "~/.kube/config"
}

variable "docker_config_file" {
  description = "Path to the docker configuration file. Used as a kubernetes secret for accessing restricted repos"
  type        = string
  default     = "~/.docker/config.json"
}

variable "kong_license_file" {
  description = "Path to the kong license file. Used as a kubernetes secret and pass to the kong instance at run time"
  type        = string
  default     = "~/.kong_license"
}

variable "kong_control_plane_config" {
  description = "A map of strings used to define the kong control plane configuration"
  type        = map(string)
  default     = {}
}

variable "kong_data_plane_config" {
  description = "A map of strings used to define the kong data plane configuration"
  type        = map(string)
  default     = {}
}

variable "super_admin_password" {
  description = "The super user password to set"
  type        = string
}

variable "kong_database_password" {
  description = "The kong database password. used in the postgres module to set the password, and accessed via a kubernetes secret for the kong congfig"
  type        = string
}

variable "namespaces" {
  type = map(string)
  default = {
    "control_plane" = "kong-hybrid-cp",
    "data_plane"    = "kong-hybrid-dp"
  }
}

variable "tls_cluster" {
  default = {
    private_key_algorithm = "ECDSA"
    ca_common_name        = "kong-cluster-ca"
    override_common_name  = "kong_clustering"
    namespaces            = ["data_plane"]
    certificates = {
      "kong-cluster" = {
        common_name  = null
        namespaces   = ["control_plane", "data_plane"]
        allowed_uses = null
      }
    }
  }
}

variable "tls_services" {
  default = {
    ca_common_name = "kong-services-ca"
    namespaces     = ["control_plane", "data_plane"]
    certificates = {
      "kong-admin-api" = {
        common_name = null
        namespaces  = ["control_plane"]
        allowed_uses = [
          "key_encipherment",
          "digital_signature",
        ]
      },
      "kong-admin-gui" = {
        common_name = null
        namespaces  = ["control_plane"]
        allowed_uses = [
          "Key_encipherment",
          "digital_signature",
        ]
      },
      "kong-portal-gui" = {
        common_name = null
        namespaces  = ["control_plane"]
        allowed_uses = [
          "key_encipherment",
          "digital_signature",
        ]
      }
      "kong-portal-api" = {
        common_name = null
        namespaces  = ["control_plane"]
        allowed_uses = [
          "key_encipherment",
          "digital_signature",
        ]
      },
      "kong-proxy" = {
        common_name = null
        namespaces  = ["data_plane"]
        allowed_uses = [
          "key_encipherment",
          "digital_signature",
        ]
      }
    }
  }
}

variable "dp_svcs" {
  description = "A map of objects that are used to create clusterIP services to expose Kong endpoints"
  type = map(object({
    annotations = map(string)
    ports = map(object({
      port        = number
      protocol    = string
      target_port = number
    }))
  }))
  default = {}
}

variable "dp_lb_svcs" {
  description = "A map of objects that are used to create LoadBalancer services to expose Kong endpoints to outside of the cluster"
  type = map(object({
    load_balancer_source_ranges = list(string)
    annotations                 = map(string)
    external_traffic_policy     = string
    health_check_node_port      = number
    ports = map(object({
      port        = number
      protocol    = string
      target_port = number
    }))
  }))
  default = {
    "kong-proxy" = {
      load_balancer_source_ranges = ["0.0.0.0/0"]
      annotations                 = {}
      external_traffic_policy     = "Cluster"
      health_check_node_port      = null
      ports = {
        "kong-proxy-ssl" = {
          port        = 8443
          protocol    = "TCP"
          target_port = 8443
        }
      }
    }
  }
}

variable "cp_lb_svcs" {
  description = "A map of objects that are used to create LoadBalancer services to expose Kong endpoints to outside of the cluster"
  type = map(object({
    load_balancer_source_ranges = list(string)
    annotations                 = map(string)
    external_traffic_policy     = string
    health_check_node_port      = number
    ports = map(object({
      port        = number
      protocol    = string
      target_port = number
    }))
  }))
  default = {
    "kong-admin-api" = {
      load_balancer_source_ranges = ["0.0.0.0/0"]
      annotations                 = {}
      external_traffic_policy     = "Cluster"
      health_check_node_port      = null
      ports = {
        "kong-admin-ssl" = {
          port        = 8444
          protocol    = "TCP"
          target_port = 8444
        },
        "kong-portal-admin-ssl" = {
          port        = 8447
          protocol    = "TCP"
          target_port = 8447
        }
      }
    }
    "kong-gui" = {
      load_balancer_source_ranges = ["0.0.0.0/0"]
      annotations                 = {}
      external_traffic_policy     = "Cluster"
      health_check_node_port      = null
      ports = {
        "kong-manager-ssl" = {
          port        = 8445
          protocol    = "TCP"
          target_port = 8445
        },
        "kong-portal-gui-ssl" = {
          port        = 8446
          protocol    = "TCP"
          target_port = 8446
        }
      }
    }
  }
}

variable "cp_svcs" {
  description = "A map of objects that are used to create clusterIP services to expose Kong endpoints"
  type = map(object({
    annotations = map(string)
    ports = map(object({
      port        = number
      protocol    = string
      target_port = number
    }))
  }))
  default = {
    "kong-cluster" = {
      annotations = {}
      ports = {
        "kong-cluster" = {
          port        = 8005
          protocol    = "TCP"
          target_port = 8005
        },
        "kong-telemetry" = {
          port        = 8006
          protocol    = "TCP"
          target_port = 8006
        }
      }
    }
  }
}

variable "cp_ingress" {
  description = "A map that represents kubernetes ingress resources"
  type = map(object({
    annotations = map(string)
    tls = object({
      hosts       = list(string)
      secret_name = string
    })
    rules = map(object({
      host = string
      paths = map(object({
        service_name = string
        service_port = number
      }))
    }))
  }))
  default = {}
}

variable "dp_ingress" {
  description = "A map that represents kubernetes ingress resources"
  type = map(object({
    annotations = map(string)
    tls = object({
      hosts       = list(string)
      secret_name = string
    })
    rules = map(object({
      host = string
      paths = map(object({
        service_name = string
        service_port = number
      }))
    }))
  }))
  default = {}
}

variable "tls_ingress" {
  default = {
    ca_common_name = null
    namespaces     = []
    certificates   = {}
  }
}

variable "control_plane_replicas" {
  description = "The number of control plane replicas to create"
  type        = number
  default     = 1
}

variable "data_plane_replicas" {
  description = "The number of data plane replicas to create"
  type        = number
  default     = 1
}

variable "kong_database_secret_name" {
  description = "A string used as the name of the database password kubernetes secret"
  type        = string
  default     = "kong-database-password"
}

variable "image_pull_secret_name" {
  description = "A string used as the name of the image pull kubernetes secret"
  type        = string
  default     = "kong-enterprise-edition-docker"
}

variable "kong_license_secret_name" {
  description = "A string used as the name of the kong license kubernetes secret"
  type        = string
  default     = "kong-enterprise-license"
}

variable "kong_superuser_secret_name" {
  description = "A string used as the name for the kong superuser password"
  type        = string
  default     = "kong-enterprise-superuser-password"
}

variable "kong_admin_gui_session_conf_secret_name" {
  description = "A string used as the name of the admin gui session conf kubernetes secret"
  type        = string
  default     = "kong-admin-gui-session-conf"
}

variable "kong_portal_session_conf_secret_name" {
  description = "A string used as the name of the portal gui conf kubernetes secret"
  type        = string
  default     = "kong-portal-session-conf"
}

variable "kong_admin_gui_auth_conf_secret_name" {
  description = "A string used as the name of the admin gui conf kubernetes secret"
  type        = string
  default     = "kong-admin-gui-auth-conf"
}

variable "kong_portal_auth_conf_secret_name" {
  description = "A string used as the name of the portal gui kubernetes secret"
  type        = string
  default     = "kong-portal-auth-conf"
}

variable "kong_admin_gui_session_conf_file" {
  description = "A string that represents the path to the kong admin gui session config file"
  type        = string
  default     = "~/.kong_configs/admin_gui_session_conf"
}

variable "kong_portal_session_conf_file" {
  description = "A string that represents the path to the kong portal gui session config file"
  type        = string
  default     = "~/.kong_configs/portal_session_conf"
}

variable "kong_admin_gui_auth_conf_file" {
  description = "A string that represents the path to the kong admin gui auth config file"
  type        = string
  default     = "~/.kong_configs/admin_gui_auth_conf"
}

variable "kong_portal_auth_conf_file" {
  description = "A string that represents the path to the kong portal gui auth config file"
  type        = string
  default     = "~/.kong_configs/portal_auth_conf"
}

variable "datadog_api_key_secret_name" {
  description = "A string that represents you datadog api access key secret name"
  type        = string
  default     = "api-key"
}

variable "datadog_api_key_path" {
  description = "A string that represents the path to the file containing the datadog api key"
  type        = string
  default     = "~/.datadog/api.key"
}

variable "validity_period_hours" {
  default = "8760"
}

variable "deploy_datadog_agents" {
  description = "A boolean to control the deployment of datadog agents into kubernetes"
  type        = bool
  default     = true
}

variable "deploy_metrics_server" {
  description = "A boolean to control the deployment of the kubernetes metrics server"
  type        = bool
  default     = false
}
