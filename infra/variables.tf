variable "subscription_id" { type = string }
variable "resource_group_name" { type = string }
variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.name))
    error_message = "Use 3 to 10 lowercase letters and digits, starting with a letter."
  }
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Use dev or prod."
  }
}
variable "location" { type = string }
variable "zones" {
  type    = list(string)
  default = []
}
variable "bastion_enabled" {
  type    = bool
  default = false
}
variable "test_vms_enabled" {
  type    = bool
  default = false
}
variable "ssh_public_key" {
  type        = string
  default     = null
  description = "Public SSH key only; never a private key. Required when test VMs are enabled."
}
variable "test_vm_size" {
  type    = string
  default = "Standard_B2s"
}
variable "alert_email" { type = string }
variable "tags" {
  type    = map(string)
  default = { project = "azure-hub-spoke-platform", managed_by = "terraform" }
}
