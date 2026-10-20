output "resource_group_name" { value = data.azurerm_resource_group.platform.name }
output "hub_vnet_name" { value = azurerm_virtual_network.hub.name }
output "firewall_name" { value = azurerm_firewall.main.name }
output "firewall_private_ip" { value = azurerm_firewall.main.ip_configuration[0].private_ip_address }
output "firewall_public_ip" { value = azurerm_public_ip.firewall.ip_address }
output "spokes" { value = { for k, v in module.spoke : k => { vnet_name = v.vnet_name, route_table_name = v.route_table_name } } }
output "key_vault_name" { value = azurerm_key_vault.main.name }
output "storage_account_name" { value = azurerm_storage_account.data.name }
output "bastion_name" { value = var.bastion_enabled ? azurerm_bastion_host.main[0].name : null }
output "test_vm_names" { value = { for k, v in azurerm_linux_virtual_machine.test : k => v.name } }
