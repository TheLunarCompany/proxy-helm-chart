variable "name" {
  type        = string
  default     = "mcpx-webapp"
  description = "Name that would be assigned for all resources and namespace"
}

variable "pull_secrets_path" {
  type        = string
  description = "Path to lunar-private-mcpx-registry.yaml. File provided by Lunar"
}

variable "oidc_secrets_path" {
  type        = string
  description = "Path to file containing OIDC secrets. See example in config-examples/oidc_data.yaml"
}

variable "override_values_path" {
  type        = string
  description = "Path to file containing override values for helm chart. See example for different platforms in config-examples/values-override"
}

variable "kube_config_path" {
  type        = string
  default     = "../../kube_config"
  description = "Path to Kube config file. Default value points to the file created by Terraform configuration in 'infra' directory"
}
