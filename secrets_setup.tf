resource "kubernetes_secret" "kong_enterprise_docker_cfg-cp" {
  for_each = var.namespaces
  metadata {
    name      = var.image_pull_secret_name
    namespace = kubernetes_namespace.kong[each.key].metadata[0].name
  }

  data = {
    ".dockerconfigjson" = file(var.docker_config_file)
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_secret" "license-cp" {
  for_each = var.namespaces
  metadata {
    name      = var.kong_license_secret_name
    namespace = kubernetes_namespace.kong[each.key].metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.kong_license_secret_name) = file(var.kong_license_file)
  }
}

resource "kubernetes_secret" "kong-enterprise-superuser-password" {
  metadata {
    name      = var.kong_superuser_secret_name
    namespace = kubernetes_namespace.kong["control_plane"].metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.kong_superuser_secret_name) = var.super_admin_password
  }
}

resource "kubernetes_secret" "kong-admin-gui-session-conf" {
  metadata {
    name      = var.kong_admin_gui_session_conf_secret_name
    namespace = kubernetes_namespace.kong["control_plane"].metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.kong_admin_gui_session_conf_secret_name) = try(file(var.kong_admin_gui_session_conf_file), "{}")
  }
}

resource "kubernetes_secret" "kong-portal-session-conf" {
  metadata {
    name      = var.kong_portal_session_conf_secret_name
    namespace = kubernetes_namespace.kong["control_plane"].metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.kong_portal_session_conf_secret_name) = try(file(var.kong_portal_session_conf_file), "{}")
  }
}

resource "kubernetes_secret" "kong-admin-gui-auth-conf" {
  metadata {
    name      = var.kong_admin_gui_auth_conf_secret_name
    namespace = kubernetes_namespace.kong["control_plane"].metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.kong_admin_gui_auth_conf_secret_name) = try(file(var.kong_admin_gui_auth_conf_file), "{}")
  }
}

resource "kubernetes_secret" "kong-portal-auth-conf" {
  metadata {
    name      = var.kong_portal_auth_conf_secret_name
    namespace = kubernetes_namespace.kong["control_plane"].metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.kong_portal_auth_conf_secret_name) = try(file(var.kong_portal_auth_conf_file), "{}")
  }
}

resource "kubernetes_secret" "kong-database-password" {
  metadata {
    name      = var.kong_database_secret_name
    namespace = kubernetes_namespace.kong["control_plane"].metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.kong_database_secret_name) = var.kong_database_password
  }
}

resource "kubernetes_secret" "datadog-api-key" {
  metadata {
    name      = var.datadog_api_key_secret_name
    namespace = kubernetes_namespace.kong["control_plane"].metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.datadog_api_key_secret_name) = try(file(var.datadog_api_key_path), "")
  }
}
