variable "customer" {
  default = "test"
  type = string
}
variable "gateway_ip" {
  description = "Gateway IP address"
  type = string
  default = "192.168.67.1"
}
variable "subnet_length" {
  description = "Subnet length"
  type = string
  default = "24"
}
variable "dns_server" {
  description = "DNS Server IP address"
  type = string
  default = "192.168.255.1"
}
variable "application_vm_ip" {
  description = "Application VM IP Address"
  default = "192.168.67.10"
}
variable "database_vm_ip" {
  description = "Database VM IP Address"
  type        = string
  default = "192.168.67.11"
}
variable "nsx_manager" {
  description = "NSX Manager IP / FQDN"
  type        = string
}
variable "avi_controller" {
  description = "AVI Controller IP / FQDN"
  type        = string
}
variable "avi_tenant" {
  description = "AVI Tenant Name"
  type        = string
}
variable "nsx_username" {
  description = "NSX administrator username"
  type        = string
  sensitive   = true
}
variable "nsx_password" {
  description = "NSX administrator password"
  type        = string
  sensitive   = true
}
variable "avi_username" {
  description = "AVI administrator password"
  type        = string
  sensitive   = true
}
variable "avi_password" {
  description = "AVI administrator password"
  type        = string
  sensitive   = true
}
variable "vcenter_server" {
  description = "vCenter IP / FQDN"
  type        = string
}
variable "vcenter_username" {
  description = "vCenter administrator username"
  type        = string
  sensitive   = true
}
variable "vcenter_password" {
  description = "vCenter administrator password"
  type        = string
  sensitive   = true
}
