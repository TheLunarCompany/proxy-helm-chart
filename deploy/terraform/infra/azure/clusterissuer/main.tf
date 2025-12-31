resource "kubernetes_manifest" "letsencrypt_agic" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-agic"
    }
    spec = {
      acme = {
        email = "devnull@lunar.dev"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-agic"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                ingressTemplate = {
                  metadata = {
                    annotations = {
                      "kubernetes.io/ingress.class" = "azure/application-gateway"
                    }
                  }
                }
              }
            }
          }
        ]
      }
    }
  }
}
