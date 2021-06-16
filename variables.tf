variable "kube_config_file" {
  description = "Path to the kubernetes configuration file. Used by the terraform provider"
  type        = string
  default     = "~/.kube/config"
}

########### Secrets to be uploaded to K8 #########

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

variable "super_admin_password" {
  description = "The super user password to set"
  type        = string
}

variable "kong_database_password_file" {
  description = "The path to a file containing the kong database password. used in the postgres module to set the password, and accessed via a kubernetes secret for the kong congfig"
  type        = string
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

########### Kong Configuration ###################

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

variable "kong_data_plane_ext_config" {
  description = "A map of strings used to define the extra data plane configuration"
  type        = map(string)
  default     = {}
}

########### Kong Clustering Settings #############

variable "tls_cluster" {
  default = {
    private_key_algorithm = "ECDSA"
    ca_common_name        = "kong-cluster-ca"
    override_common_name  = "kong_clustering"
    namespaces            = ["data_plane", "data_plane_ext"]
    certificates = {
      "kong-cluster" = {
        common_name  = null
        namespaces   = ["control_plane", "data_plane", "data_plane_ext"]
        allowed_uses = null
      }
    }
  }
}

variable "validity_period_hours" {
  default = "8760"
}

########### Kong Service and Ingress Defaults ####

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
  default = {
    "kong-proxy" = {
      annotations = {}
      ports = {
        "kong-proxy" = {
          port        = 8000
          protocol    = "TCP"
          target_port = 8000
        },
        "kong-proxy-ssl" = {
          port        = 8443
          protocol    = "TCP"
          target_port = 8443
        }
      }
    }
  }
}

variable "dp_ext_svcs" {
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
    "kong-proxy-ext" = {
      annotations = {}
      ports = {
        "kong-proxy" = {
          port        = 8000
          protocol    = "TCP"
          target_port = 8000
        },
        "kong-proxy-ssl" = {
          port        = 8443
          protocol    = "TCP"
          target_port = 8443
        }
      }
    }
  }
}

variable "dp_lb_svcs" {
  description = "A map of objects that are used to create LoadBalancer services to expose Kong endpoints to outside of the cluster"
  type = map(object({
    annotations                 = map(string)
    load_balancer_source_ranges = list(string)
    external_traffic_policy     = string
    health_check_node_port      = number
    ports = map(object({
      port        = number
      protocol    = string
      target_port = number
    }))
  }))
  default = {}
}

variable "dp_ext_lb_svcs" {
  description = "A map of objects that are used to create LoadBalancer services to expose Kong endpoints to outside of the cluster"
  type = map(object({
    annotations                 = map(string)
    load_balancer_source_ranges = list(string)
    external_traffic_policy     = string
    health_check_node_port      = number
    ports = map(object({
      port        = number
      protocol    = string
      target_port = number
    }))
  }))
  default = {}
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
  default = {}
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

variable "dp_ext_ingress" {
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
    "kong-api-man" = {
      annotations = {}
      ports = {
        "kong-admin" = {
          port        = 8001
          protocol    = "TCP"
          target_port = 8001
        },
        "kong-manager" = {
          port        = 8002
          protocol    = "TCP"
          target_port = 8002
        },
        "kong-admin-ssl" = {
          port        = 8444
          protocol    = "TCP"
          target_port = 8444
        },
        "kong-manager-ssl" = {
          port        = 8445
          protocol    = "TCP"
          target_port = 8445
        }
      }
    }
    "kong-portal" = {
      annotations = {}
      ports = {
        "kong-portal-admin" = {
          port        = 8004
          protocol    = "TCP"
          target_port = 8004
        },
        "kong-portal-gui" = {
          port        = 8003
          protocol    = "TCP"
          target_port = 8003
        },
        "kong-portal-admin-ssl" = {
          port        = 8447
          protocol    = "TCP"
          target_port = 8447
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




########### Datadog Settings #####################

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

########### AWS Settings #########################

variable "aws_region" {
  description = "The name of the aws region to use"
  type        = string
  default     = "eu-west-1"
}

variable "aws_creds_file" {
  description = "The path to an aws credentials file to use"
  type        = string
  default     = ""
}

########### DNS Settings #########################

variable "route53_zone_id" {
  description = "The name of the dns zone to use"
  type        = string
  default     = ""
}

variable "proxy_cname" {
  description = "The name to give the kong proxy cname record"
  type        = string
  default     = ""
}

variable "proxy_ext_cname" {
  description = "The name to give the extra data plane proxy cname record"
  type        = string
  default     = ""
}

variable "portal_gui_cname" {
  description = "The name to give the kong portal cname record"
  type        = string
  default     = ""
}

variable "manager_cname" {
  description = "The name to give the kong manager cname record"
  type        = string
  default     = ""
}

variable "admin_cname" {
  description = "The name to give the kong admin cname record"
  type        = string
  default     = ""
}

variable "portal_admin_cname" {
  description = "The name to give the kong portal admin cname record"
  type        = string
  default     = ""
}

########### Deployment Options ###################

variable "deploy_redis" {
  description = "Should we deploy redis to kubernetes, used for testing"
  type        = bool
  default     = false
}

variable "enable_autoscaler" {
  description = "If set to true then horizontal pod auto scalling is enabled"
  type        = bool
  default     = false
}

variable "namespaces" {
  description = "If existing_namespaces is set to true we will look for the defined namesapce in kuberntes. If existing_namespaces is false we will create the namespaces defined here"
  type        = map(string)
  default = {
    "control_plane" = "kong-hybrid-cp",
    "data_plane"    = "kong-hybrid-dp"
  }
}

variable "existing_namespaces" {
  description = "If you plan to use a existing namespaces then set this value to true"
  type        = bool
  default     = false
}

variable "sg_passthrough" {
  description = "If you have extra security groups you would like to pass through to the load balancer services, you can add them as a comma seperated list"
  type        = string
  default     = null
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

variable "data_plane_ext_replicas" {
  description = "The number of extra data plane replicas to create"
  type        = number
  default     = 1
}

variable "kong_image" {
  description = "The kong container image file to use"
  type        = string
  default     = "kong/kong-gateway:2.4.1.1-alpine"
}

############ Kong Deployment Names ###############

variable "control_plane_deployment_name" {
  description = "The name to give our control plane deployment"
  type        = string
  default     = "control-plane"
}

variable "data_plane_deployment_name" {
  description = "The name to give our data plane deployment"
  type        = string
  default     = "data-plane"
}

variable "data_plane_ext_deployment_name" {
  description = "The name to give our data plane deployment (extra)"
  type        = string
  default     = "data-plane-ext"
}

############ Kong Migrations #####################

variable "kong_migrations_pre" {
  description = "Set to true to start the kong migration process"
  type        = bool
  default     = false
}

variable "kong_migrations_post" {
  description = "Set to true to finsish the kong migration process"
  type        = bool
  default     = false
}
