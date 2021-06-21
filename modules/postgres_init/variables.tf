variable "namespace" {}
variable "kong_superuser_secret_name" {}
variable "kong_database_secret_name" {}
variable "kong_license_secret_name" {}
variable "kong_image" {}
variable "kong_database_host" {}
variable "kong_database_port" {}
variable "kong_database_user" {}
variable "kong_database_name" {}

########### Labels ###############################

variable "labels" {
  description = "Labels to apply to all resources if use_global_labels is set to true"
  type        = map(string)
  default     = {}
}

########### Security Context #####################

variable "pod_security_context" {
  description = "The security contexts to set for this deployments pods"
  type = object({
    fs_group            = string
    run_as_group        = string
    run_as_non_root     = bool
    run_as_user         = string
    supplemental_groups = list(string)
  })
  default = {
    fs_group            = null
    run_as_group        = 65533
    run_as_non_root     = true
    run_as_user         = 100
    supplemental_groups = null
  }
}

variable "container_security_context" {
  description = "The security contexts to set for this deployments containers"
  type = object({
    allow_privilege_escalation = bool
    capabilities = object({
      add  = list(string)
      drop = list(string)
    })
    privileged                = bool
    read_only_root_filesystem = bool
    run_as_group              = string
    run_as_non_root           = bool
    run_as_user               = string
  })
  default = {
    allow_privilege_escalation = null
    capabilities = {
      add  = []
      drop = ["all"]
    }
    privileged                = false
    read_only_root_filesystem = true
    run_as_group              = 65533
    run_as_non_root           = true
    run_as_user               = 100
  }
}


