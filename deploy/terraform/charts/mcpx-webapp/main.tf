resource "kubernetes_namespace_v1" "mcpx_webapp" {
  metadata {
    name = var.name
  }
}

resource "kubernetes_secret_v1" "pull_secrets" {
  metadata {
    name      = "lunar-private-mcpx-registry"
    namespace = kubernetes_namespace_v1.mcpx_webapp.metadata[0].name
  }
  data = {
    ".dockerconfigjson" = base64decode(yamldecode(file(var.pull_secrets_path))["data"][".dockerconfigjson"])
  }
  type = "kubernetes.io/dockerconfigjson"
}

resource "random_bytes" "session_secret" {
  length = 32
}

resource "kubernetes_secret_v1" "mcpx_webapp_global" {
  metadata {
    name      = "mcpx-webapp-global"
    namespace = kubernetes_namespace_v1.mcpx_webapp.metadata[0].name
  }
  data = {
    "SESSION_SECRET" = random_bytes.session_secret.base64
  }
}

resource "kubernetes_secret_v1" "mcpx_webapp_oidc" {
  metadata {
    name      = "mcpx-webapp-oidc"
    namespace = kubernetes_namespace_v1.mcpx_webapp.metadata[0].name
  }
  data = yamldecode(file(var.oidc_secrets_path))
}

resource "helm_release" "lunar_mcpx_webapp" {
  name  = var.name
  chart = "../../../../charts/lunar-mcpx-webapp/"

  # Alternative helm versioning
  #version    = "0.7.15"
  #chart      = "lunar-mcpx-webapp"
  #repository = "https://thelunarcompany.github.io/proxy-helm-chart"

  namespace = kubernetes_namespace_v1.mcpx_webapp.metadata[0].name

  values = [
    file(var.override_values_path)
  ]

  depends_on = [
    kubernetes_secret_v1.pull_secrets,
    kubernetes_secret_v1.mcpx_webapp_global,
  ]
}
