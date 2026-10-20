resource "azurerm_public_ip" "bastion" {
  count               = var.bastion_enabled ? 1 : 0
  name                = "${local.prefix}-bastion-pip"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}
resource "azurerm_bastion_host" "main" {
  count               = var.bastion_enabled ? 1 : 0
  name                = "${local.prefix}-bastion"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = var.location
  sku                 = "Basic"
  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
  tags = local.tags
}
resource "azurerm_network_interface" "test" {
  for_each            = var.test_vms_enabled ? local.topology.spokes : {}
  name                = "${local.prefix}-${each.key}-test-nic"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = var.location
  ip_configuration {
    name                          = "primary"
    subnet_id                     = module.spoke[each.key].workload_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.tags
}
resource "azurerm_linux_virtual_machine" "test" {
  for_each                        = var.test_vms_enabled ? local.topology.spokes : {}
  name                            = "${local.prefix}-${each.key}-test"
  resource_group_name             = data.azurerm_resource_group.platform.name
  location                        = var.location
  size                            = var.test_vm_size
  admin_username                  = "azureadmin"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.test[each.key].id]
  admin_ssh_key {
    username   = "azureadmin"
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  identity { type = "SystemAssigned" }
  boot_diagnostics {}
  tags = local.tags
  lifecycle {
    precondition {
      condition     = var.ssh_public_key != null && startswith(coalesce(var.ssh_public_key, "missing"), "ssh-")
      error_message = "Test VMs require an OpenSSH public key."
    }
  }
}
resource "azurerm_role_assignment" "test_vault_reader" {
  for_each             = azurerm_linux_virtual_machine.test
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.identity[0].principal_id
}
resource "azurerm_role_assignment" "test_blob_reader" {
  for_each             = azurerm_linux_virtual_machine.test
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value.identity[0].principal_id
}
