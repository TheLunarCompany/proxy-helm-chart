resource "random_id" "suffix" {
  byte_length = 8
}

resource "azurerm_resource_group" "main" {
  count = var.create_resource_group ? 1 : 0

  location = var.location
  name     = coalesce(var.resource_group_name, "${var.resource_prefix}-${random_id.suffix.hex}")
}

locals {
  resource_group = {
    name     = var.create_resource_group ? azurerm_resource_group.main[0].name : var.resource_group_name
    location = var.location
  }
}

resource "azurerm_virtual_network" "main" {
  address_space       = ["10.52.0.0/16"]
  location            = local.resource_group.location
  name                = "${var.resource_prefix}-${random_id.suffix.hex}"
  resource_group_name = local.resource_group.name
}

resource "azurerm_subnet" "main" {
  address_prefixes     = ["10.52.0.0/24"]
  name                 = "${var.resource_prefix}-${random_id.suffix.hex}"
  resource_group_name  = local.resource_group.name
  virtual_network_name = azurerm_virtual_network.main.name
}

module "aks_cluster_name" {
  source  = "Azure/aks/azurerm"
  version = "11.0.0"

  prefix                               = var.resource_prefix
  resource_group_name                  = local.resource_group.name
  admin_username                       = null
  azure_policy_enabled                 = true
  cluster_name                         = "${var.resource_prefix}-${random_id.suffix.hex}"
  log_analytics_workspace_enabled = false
  location = local.resource_group.location
  maintenance_window = {
    allowed = [
      {
        day   = "Sunday",
        hours = [22, 23]
      },
    ]
    not_allowed = []
  }
  private_cluster_enabled           = false
  role_based_access_control_enabled = false

  # Workers
  agents_count            = 2
  agents_size             = "Standard_D4s_v4"
  storage_profile_enabled = true

  # # Application Gateway
  brown_field_application_gateway_for_ingress = {
    id        = azurerm_application_gateway.this.id
    subnet_id = azurerm_subnet.agw.id
  }
  create_role_assignments_for_application_gateway = true

  net_profile_dns_service_ip = "10.0.0.10"
  net_profile_service_cidr   = "10.0.0.0/16"
  network_plugin             = "azure"
  network_policy             = "azure"

  vnet_subnet = {
    id = azurerm_subnet.main.id
  }
}

resource "local_file" "kube_config" {
  count    = var.create_kube_config ? 1 : 0
  filename = var.kube_config_path
  content  = module.aks_cluster_name.kube_config_raw
}
