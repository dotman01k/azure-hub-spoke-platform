resource "azurerm_public_ip" "firewall" {
  name                = "${local.prefix}-firewall-pip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.platform.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = local.tags
}
resource "azurerm_firewall_policy" "main" {
  name                     = "${local.prefix}-firewall-policy"
  location                 = var.location
  resource_group_name      = data.azurerm_resource_group.platform.name
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
  dns {
    proxy_enabled = true
    servers       = ["168.63.129.16"]
  }
  tags = local.tags
}
resource "azurerm_firewall" "main" {
  name                = "${local.prefix}-firewall"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.platform.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  zones               = var.zones
  firewall_policy_id  = azurerm_firewall_policy.main.id
  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
  tags = local.tags
}
resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "platform-connectivity"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 200
  network_rule_collection {
    name     = "application-to-data"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "application-service-https"
      protocols             = ["TCP"]
      source_addresses      = [local.topology.spokes[local.topology.interspoke_rule.source].workload_subnet]
      destination_addresses = [local.topology.spokes[local.topology.interspoke_rule.destination].workload_subnet]
      destination_ports     = [tostring(local.topology.interspoke_rule.tcp_port)]
    }
  }
  application_rule_collection {
    name     = "approved-package-repositories"
    priority = 300
    action   = "Allow"
    rule {
      name              = "packages"
      source_addresses  = [for v in local.topology.spokes : v.workload_subnet]
      destination_fqdns = local.topology.allowed_egress_fqdns
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }
  }
}
