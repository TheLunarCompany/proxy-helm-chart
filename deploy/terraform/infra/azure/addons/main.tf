resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  version          = "v1.19.2"
  chart            = "cert-manager"
  repository       = "oci://quay.io/jetstack/charts"
  namespace        = "cert-manager"
  create_namespace = true

  set = [
    {
      name  = "crds.enabled"
      value = true
    }
  ]
}
