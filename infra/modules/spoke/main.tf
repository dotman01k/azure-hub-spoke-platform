variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "address_space" { type = string }
variable "workload_subnet" { type = string }
variable "private_subnet" { type = string }
variable "hub_vnet_id" { type = string }
variable "hub_vnet_name" { type = string }
variable "firewall_ip" { type = string }
variable "bastion_cidr" { type = string }
variable "peer_cidrs" { type = list(string) }
variable "allowed_service_sources" { type = list(string) }
variable "service_port" { type = number }
variable "tags" { type = map(string) }
resource "azurerm_virtual_network" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  dns_servers         = [var.firewall_ip]
  tags                = var.tags
}
resource "azurerm_subnet" "workload" {
  name                 = "workloads"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.workload_subnet]
}
resource "azurerm_subnet" "private" {
  name                 = "private-endpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_subnet]
}
resource "azurerm_virtual_network_peering" "to_hub" {
  name                         = "${var.name}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.main.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
resource "azurerm_virtual_network_peering" "from_hub" {
  name                         = "hub-to-${var.name}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.main.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
resource "azurerm_route_table" "main" {
  name                          = "${var.name}-routes"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags                          = var.tags
}
resource "azurerm_route" "internet" {
  name                   = "default-via-firewall"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.main.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_ip
}
resource "azurerm_route" "peers" {
  for_each               = toset(var.peer_cidrs)
  name                   = "peer-${replace(replace(each.value, ".", "-"), "/", "-")}"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.main.name
  address_prefix         = each.value
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_ip
}
resource "azurerm_subnet_route_table_association" "workload" {
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.main.id
}
resource "azurerm_network_security_group" "workload" {
  name                = "${var.name}-workload-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  security_rule {
    name                       = "ssh-from-bastion-subnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.bastion_cidr
    destination_address_prefix = var.workload_subnet
  }
  dynamic "security_rule" {
    for_each = length(var.allowed_service_sources) > 0 ? [1] : []
    content {
      name                       = "approved-application-service"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(var.service_port)
      source_address_prefixes    = var.allowed_service_sources
      destination_address_prefix = var.workload_subnet
    }
  }
  security_rule {
    name                       = "deny-other-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = var.tags
}
resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
output "id" { value = azurerm_virtual_network.main.id }
output "workload_subnet_id" { value = azurerm_subnet.workload.id }
output "private_subnet_id" { value = azurerm_subnet.private.id }
output "route_table_name" { value = azurerm_route_table.main.name }
output "vnet_name" { value = azurerm_virtual_network.main.name }
