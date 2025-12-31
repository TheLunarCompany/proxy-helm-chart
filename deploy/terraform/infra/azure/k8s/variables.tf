variable "resource_prefix" {
  type    = string
  default = "lunar"
}

variable "create_resource_group" {
  type     = bool
  default  = true
  nullable = false
}

variable "key_vault_firewall_bypass_ip_cidr" {
  type    = string
  default = null
}

variable "location" {
  default = "eastus"
}

variable "log_analytics_workspace_location" {
  default = null
}

variable "managed_identity_principal_id" {
  type    = string
  default = null
}

variable "resource_group_name" {
  type    = string
  default = "lunar"
}

variable "create_kube_config" {
  type    = bool
  default = true
}

variable "kube_config_path" {
  type    = string
  default = "../../../kube_config"
}
