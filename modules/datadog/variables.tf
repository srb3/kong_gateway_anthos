variable "chart" {
  description = "An object describing the helm release"
  type = object({
    name       = string
    repository = string
    chart      = string
    version    = string
    values = map(object({
      value = string
      type  = string
    }))
  })
  default = {
    name       = "datadog"
    repository = "https://helm.datadoghq.com"
    chart      = "datadog"
    version    = null
    values     = {}
  }
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "api_key" {
  type = string
}
