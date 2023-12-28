terraform {
  required_version = ">=1.1.4, <2.0.0"

  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.13"
    }
  }
}