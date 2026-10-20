resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefix}-logs"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = var.environment == "prod" ? 5 : 1
  tags                = local.tags
}
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "firewall-logs"
  target_resource_id             = azurerm_firewall.main.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"
  enabled_log { category_group = "allLogs" }
  enabled_metric { category = "AllMetrics" }
}
resource "azurerm_monitor_action_group" "ops" {
  name                = "${local.prefix}-ops"
  resource_group_name = data.azurerm_resource_group.platform.name
  short_name          = "netops"
  email_receiver {
    name                    = "operator"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}
resource "azurerm_monitor_metric_alert" "firewall_health" {
  name                = "${local.prefix}-firewall-health"
  resource_group_name = data.azurerm_resource_group.platform.name
  scopes              = [azurerm_firewall.main.id]
  frequency           = "PT5M"
  window_size         = "PT15M"
  severity            = 1
  description         = "Azure Firewall health was below 100 percent."
  criteria {
    metric_namespace = "Microsoft.Network/azureFirewalls"
    metric_name      = "FirewallHealth"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }
  action { action_group_id = azurerm_monitor_action_group.ops.id }
}
