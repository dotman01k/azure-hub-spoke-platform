resource "azurerm_key_vault" "main" {
  name                          = "${var.name}-${var.environment}-${local.unique}"
  resource_group_name           = data.azurerm_resource_group.platform.name
  location                      = var.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  tags                          = local.tags
}
resource "azurerm_storage_account" "data" {
  name                            = "${var.name}${var.environment}${local.unique}"
  resource_group_name             = data.azurerm_resource_group.platform.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.environment == "prod" ? "ZRS" : "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  tags                            = local.tags
}
locals {
  private_services = {
    vault = { id = azurerm_key_vault.main.id, group = "vault", zone = "privatelink.vaultcore.azure.net", subnet = azurerm_subnet.hub_private.id }
    blob  = { id = azurerm_storage_account.data.id, group = "blob", zone = "privatelink.blob.core.windows.net", subnet = module.spoke["data"].private_subnet_id }
  }
  dns_links  = merge({ hub = azurerm_virtual_network.hub.id }, { for k, v in module.spoke : k => v.id })
  link_pairs = { for pair in setproduct(keys(local.private_services), keys(local.dns_links)) : "${pair[0]}-${pair[1]}" => { service = pair[0], network = pair[1] } }
}
resource "azurerm_private_dns_zone" "main" {
  for_each            = local.private_services
  name                = each.value.zone
  resource_group_name = data.azurerm_resource_group.platform.name
  tags                = local.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  for_each              = local.link_pairs
  name                  = each.key
  resource_group_name   = data.azurerm_resource_group.platform.name
  private_dns_zone_name = azurerm_private_dns_zone.main[each.value.service].name
  virtual_network_id    = local.dns_links[each.value.network]
  registration_enabled  = false
}
resource "azurerm_private_endpoint" "main" {
  for_each            = local.private_services
  name                = "${local.prefix}-${each.key}-pe"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.platform.name
  subnet_id           = each.value.subnet
  private_service_connection {
    name                           = each.key
    is_manual_connection           = false
    private_connection_resource_id = each.value.id
    subresource_names              = [each.value.group]
  }
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.main[each.key].id]
  }
  tags = local.tags
}
