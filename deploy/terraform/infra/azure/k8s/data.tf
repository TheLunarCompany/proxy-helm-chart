data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "current" {
  count = !var.create_resource_group ? 1 : 0
  name  = var.resource_group_name
}
