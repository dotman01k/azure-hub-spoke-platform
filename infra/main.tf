data "azurerm_client_config" "current" {}
data "azurerm_resource_group" "platform" { name = var.resource_group_name }
locals {
  topology = jsondecode(file("${path.module}/../config/topology.json"))
  prefix   = "${var.name}-${var.environment}"
  unique   = substr(sha256("${var.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)
  tags     = merge(var.tags, { environment = var.environment })
}
resource "azurerm_virtual_network" "hub" {
  name                = "${local.prefix}-hub"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.platform.name
  address_space       = [local.topology.hub.address_space]
  tags                = local.tags
}
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = data.azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.topology.hub.firewall_subnet]
}
resource "azurerm_subnet" "bastion" {
  count                = var.bastion_enabled ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = data.azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.topology.hub.bastion_subnet]
}
resource "azurerm_subnet" "hub_private" {
  name                 = "private-endpoints"
  resource_group_name  = data.azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.topology.hub.private_subnet]
}
module "spoke" {
  for_each                = local.topology.spokes
  source                  = "./modules/spoke"
  name                    = "${local.prefix}-${each.key}"
  location                = var.location
  resource_group_name     = data.azurerm_resource_group.platform.name
  address_space           = each.value.address_space
  workload_subnet         = each.value.workload_subnet
  private_subnet          = each.value.private_subnet
  hub_vnet_id             = azurerm_virtual_network.hub.id
  hub_vnet_name           = azurerm_virtual_network.hub.name
  firewall_ip             = azurerm_firewall.main.ip_configuration[0].private_ip_address
  bastion_cidr            = local.topology.hub.bastion_subnet
  peer_cidrs              = [for k, v in local.topology.spokes : v.address_space if k != each.key]
  allowed_service_sources = each.key == local.topology.interspoke_rule.destination ? [local.topology.spokes[local.topology.interspoke_rule.source].workload_subnet] : []
  service_port            = local.topology.interspoke_rule.tcp_port
  tags                    = local.tags
}
