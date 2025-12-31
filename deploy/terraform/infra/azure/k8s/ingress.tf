resource "azurerm_subnet" "agw" {
  address_prefixes     = ["10.52.1.0/24"]
  name                 = "${var.resource_prefix}-${random_id.suffix.hex}-agw"
  resource_group_name  = local.resource_group.name
  virtual_network_name = azurerm_virtual_network.main.name
}

# Locals block for hardcoded names
locals {
  backend_address_pool_name      = try("${azurerm_virtual_network.main.name}-beap", "")
  frontend_ip_configuration_name = try("${azurerm_virtual_network.main.name}-feip", "")
  frontend_port_name             = try("${azurerm_virtual_network.main.name}-feport", "")
  http_setting_name              = try("${azurerm_virtual_network.main.name}-be-htst", "")
  listener_name                  = try("${azurerm_virtual_network.main.name}-httplstn", "")
  request_routing_rule_name      = try("${azurerm_virtual_network.main.name}-rqrt", "")
}

resource "azurerm_public_ip" "pip" {
  allocation_method   = "Static"
  location            = local.resource_group.location
  name                = "appgw-pip"
  resource_group_name = local.resource_group.name
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "this" {
  location            = local.resource_group.location
  name                = "${var.resource_prefix}-${random_id.suffix.hex}"
  resource_group_name = local.resource_group.name

  backend_address_pool {
    name = local.backend_address_pool_name
  }
  backend_http_settings {
    cookie_based_affinity = "Disabled"
    name                  = local.http_setting_name
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.pip.id
  }
  frontend_port {
    name = local.frontend_port_name
    port = 80
  }
  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.agw.id
  }
  http_listener {
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    name                           = local.listener_name
    protocol                       = "Http"
  }
  request_routing_rule {
    http_listener_name         = local.listener_name
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 1
  }
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  lifecycle {
    ignore_changes = [
      tags,
      backend_address_pool,
      backend_http_settings,
      http_listener,
      probe,
      request_routing_rule,
      url_path_map,
      zones,
      ssl_certificate,
      redirect_configuration,
      frontend_port,
    ]
  }
}
