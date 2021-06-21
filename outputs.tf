locals {

  # These local variables are used as outputs
  proxy_url        = module.kong-dp.proxy_endpoint
  proxy_ext_url    = local.extra_dp ? module.kong-dp-ext.0.proxy_endpoint : ""
  admin_url        = module.kong-cp.admin_endpoint
  manager_url      = module.kong-cp.manager_endpoint
  portal_admin_url = module.kong-cp.portal_admin_endpoint
  portal_gui_url   = module.kong-cp.portal_gui_endpoint
  cluster          = module.kong-cp.cluster_endpoint
  telemetry        = module.kong-cp.telemetry_endpoint
}

# the following outputs are used in the test suite
output "kong-admin-endpoint" {
  value = local.admin_url
}

output "kong-manager-endpoint" {
  value = local.manager_url
}

output "kong-portal-admin-endpoint" {
  value = local.portal_admin_url
}

output "kong-portal-gui-endpoint" {
  value = local.portal_gui_url
}

output "kong-proxy-endpoint" {
  value = local.proxy_url
}

output "kong-proxy-ext-endpoint" {
  value = local.proxy_ext_url
}

output "kong-super-admin-token" {
  value = var.super_admin_password
}

output "dp-ingress" {
  value = module.kong-dp.ingress
}
