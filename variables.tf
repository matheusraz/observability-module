variable "aws_region" {
  type = string
}

variable "grafana" {
  type = object({
    setup = optional(bool, false)
  })
}

variable "loki" {
  type = object({
    setup          = optional(bool, false)
    bucket_name    = optional(string)
    ingress_domain = optional(string)
  })
  default = {}
}

variable "tempo" {
  type = object({
    setup          = optional(bool, false)
    bucket_name    = optional(string)
    ingress_domain = optional(string)
  })
  default = {}
}

variable "mimir" {
  type = object({
    setup                    = optional(bool, false)
    blocks_bucket_name       = optional(string)
    alertmanager_bucket_name = optional(string)
    ruler_bucket_name        = optional(string)
    ingress_domain           = optional(string)
  })
  default = {}
}

variable "kuma" {
  type = object({
    setup = optional(bool, false)
  })
  
}


variable "account_id" {
  type = string
}

variable "cluster_oidc_issuer" {
  type = string
}