terraform {
  required_version = ">=1.3"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
  }
}

provider "kubernetes" {
  config_path = "../../../kube_config"
}
