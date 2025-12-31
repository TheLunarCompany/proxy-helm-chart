terraform {
  required_version = ">=1.3"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = "../../../kube_config"
  }
}
