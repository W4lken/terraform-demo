data "nsxt_policy_tier0_gateway" "lab_t0" {
  display_name = "LAB-T0"
}
data "nsxt_policy_transport_zone" "overlay_tz" {
  display_name = "nsx-overlay-transportzone"
}
resource "nsxt_policy_segment" "segment" {
  display_name        = "${var.customer}-Segment_${var.gateway_ip}-${var.subnet_length}"
  description         = "Terraform provisioned Segment"
  connectivity_path   = data.nsxt_policy_tier0_gateway.lab_t0.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
  subnet {
    cidr        = "${var.gateway_ip}/${var.subnet_length}"
  }
}
data "nsxt_policy_segment_realization" "segment" {
  path = nsxt_policy_segment.segment.path
}
data "vsphere_datacenter" "dc" {
  name = "LAB"
}
data "vsphere_datastore" "datastore" {
  name          = "Datastore-iSCSI-1"
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_compute_cluster" "cluster" {
  name          = "LAB-Cluster"
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "network" {
  name          = data.nsxt_policy_segment_realization.segment.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_content_library" "library" {
  name = "Images-Library"
}
data "vsphere_content_library_item" "wp_app_template" {
  name       = "wp-app-template"
  library_id = data.vsphere_content_library.library.id
  type = "VM-TEMPLATE"
}
data "vsphere_content_library_item" "wp_db_template" {
  name       = "wp-db-template"
  library_id = data.vsphere_content_library.library.id
  type = "VM-TEMPLATE"
}
resource "vsphere_folder" "folder" {
  path          = var.customer
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "wordpress_app" {
  name             = "${var.customer}-app-0${count.index}"
  count= length(var.application_vm_ip)
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder = vsphere_folder.folder.path
  num_cpus = 1
  memory   = 2048
  guest_id = "centos8_64Guest"
  firmware = "efi"
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }
  disk {
    label = "Hard disk 1"
    size = 16
  }
  clone {
    template_uuid = data.vsphere_content_library_item.wp_app_template.id
    customize {
      linux_options {
        host_name = "wordpress-app"
        domain    = "lab.mimran.pro"
      }
      network_interface {
        ipv4_address = var.application_vm_ip[count.index]
        ipv4_netmask = var.subnet_length
      }
      ipv4_gateway = var.gateway_ip
      dns_server_list = [var.dns_server]
    }
  }
  vapp {
    properties = {
      database_ip = var.database_vm_ip
    }
  }
}

resource "vsphere_virtual_machine" "wordpress_db" {
  name             = "${var.customer}-db"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder = vsphere_folder.folder.path
  num_cpus = 1
  memory   = 2048
  guest_id = "centos8_64Guest"
  firmware = "efi"
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }
  disk {
    label = "Hard disk 1"
    size = 16
  }
  clone {
    template_uuid = data.vsphere_content_library_item.wp_db_template.id
    customize {
      linux_options {
        host_name = "wordpress-db"
        domain    = "lab.mimran.pro"
      }
      network_interface {
        ipv4_address = var.database_vm_ip
        ipv4_netmask = var.subnet_length
      }
      ipv4_gateway = var.gateway_ip
      dns_server_list = [var.dns_server]
    }
  }
}

resource "nsxt_vm_tags" "app_tags" {
  count = length(vsphere_virtual_machine.wordpress_app)
  instance_id = vsphere_virtual_machine.wordpress_app[count.index].id
  tag {
    scope = "customer"
    tag   = var.customer
  }
  tag {
    scope = "application"
    tag   = "wordpress"
  }
  tag {
    scope = "tier"
    tag   = "app"
  }
}

resource "nsxt_vm_tags" "db_tags" {
  instance_id = vsphere_virtual_machine.wordpress_db.id
  tag {
    scope = "customer"
    tag   = var.customer
  }
  tag {
    scope = "application"
    tag   = "wordpress"
  }
  tag {
    scope = "tier"
    tag   = "db"
  }
}

resource "nsxt_policy_group" "wordpress" {
  display_name = "${var.customer}_wordpress"
  description  = "Terraform provisioned Group"
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "application|wordpress"
    }
  }
}

resource "nsxt_policy_group" "wordpress_app_tier" {
  display_name = "${var.customer}_wordpress_app_tier"
  description  = "Terraform provisioned Group"
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "application|wordpress"
    }
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "tier|app"
    }
  }
}

resource "nsxt_policy_group" "wordpress_db_tier" {
  display_name = "${var.customer}_wordpress_db_tier"
  description  = "Terraform provisioned Group"
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "application|wordpress"
    }
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "tier|db"
    }
  }
}

data "nsxt_policy_service" "http_service" {
  display_name = "HTTP"
}
data "nsxt_policy_service" "mysql_service" {
  display_name = "MySQL"
}

resource "nsxt_policy_security_policy" "wordpress_policy" {
  display_name = "${var.customer}_wordpress_policy"
  description  = "Terraform provisioned Security Policy"
  category     = "Application"
  locked       = false
  stateful     = true
  tcp_strict   = false
  scope        = [nsxt_policy_group.wordpress.path]
  rule {
    display_name     = "Allow HTTP to App"
    destination_groups = [nsxt_policy_group.wordpress_app_tier.path]
    services         = [data.nsxt_policy_service.http_service.path]
    action           = "ALLOW"
    logged           = false
    disabled         = false
  }
  rule {
    display_name     = "Allow App to DB"
    source_groups = [nsxt_policy_group.wordpress_app_tier.path]
    destination_groups = [nsxt_policy_group.wordpress_db_tier.path]
    services         = [data.nsxt_policy_service.mysql_service.path]
    action           = "ALLOW"
    logged           = false
    disabled         = false
  }
  rule {
    display_name       = "Default Deny"
    action             = "DROP"
    logged             = true
  }
}

/*
AVI Networks : Virtual Service Creation
*/
data "avi_applicationprofile" "system_https_profile" {
  name= "System-Secure-HTTP"
}
data "avi_tenant" "default_tenant" {
  name= "admin"
}
data "avi_cloud" "default_cloud" {
  name= "NSX-T Cloud"
}
data "avi_serviceenginegroup" "se_group" {
  name = "Default-Group"
}
data "avi_networkprofile" "system_tcp_profile" {
  name= "System-TCP-Proxy"
}
data "avi_analyticsprofile" "system_analytics_profile" {
  name= "System-Analytics-Profile"
}
data "avi_sslkeyandcertificate" "system_default_cert" {
  name= "System-Default-Cert"
}
data "avi_sslprofile" "system_standard_sslprofile" {
  name= "System-Standard"
}
data "avi_vrfcontext" "global_vrf" {
  name= "global"
}
data "avi_applicationpersistenceprofile" "persistence_sourceip" {
  name = "System-Persistence-Client-IP"
}
data "avi_healthmonitor" "http_monitor" {
  name = "System-HTTP"
}
# resource "avi_server" "pool_members" {
#   count = 2
#   ip = vsphere_virtual_machine.wordpress_app[count.index].default_ip_address
#   port = "80"
#   pool_ref = avi_pool.wordpress_pool.id
#   hostname = vsphere_virtual_machine.wordpress_app[count.index].name
# }
resource "avi_pool" "wordpress_pool" {
  name= "${var.customer}_wordpress_pool"
  health_monitor_refs= [data.avi_healthmonitor.http_monitor.id]
  tenant_ref= data.avi_tenant.default_tenant.id
  cloud_ref= data.avi_cloud.default_cloud.id
  application_persistence_profile_ref= data.avi_applicationpersistenceprofile.persistence_sourceip.id
  servers {
    ip {
      type= "V4"
      addr= vsphere_virtual_machine.wordpress_app[0].default_ip_address
    }
    hostname= vsphere_virtual_machine.wordpress_app[0].name
    port = 80
  }
  servers {
    ip {
      type= "V4"
      addr= vsphere_virtual_machine.wordpress_app[1].default_ip_address
    }
    hostname= vsphere_virtual_machine.wordpress_app[1].name
    port = 80
  }
  tier1_lr="/infra/tier-1s/AVI-T1"
}

resource "avi_vsvip" "wordpress_vip" {
  name= "${var.customer}_wordpress_vip"
  vip {
    vip_id= "1"
    auto_allocate_ip = true
    auto_allocate_floating_ip = true
  }
  dns_info {
    fqdn= "${var.customer}-wordpress.avi.lab.mimran.pro"
    num_records_in_response = 0
  }
  tier1_lr="/infra/tier-1s/AVI-T1"
  cloud_ref= data.avi_cloud.default_cloud.id
}

data "avi_wafpolicy" "waf_policy" {
    name = "Test-WAF-Policy"
}

data "avi_errorpageprofile" "error_page" {
    name = "Error-Page"
}

resource "avi_virtualservice" "wordpress_vs" {

  name= "${var.customer}_wordpress_vs"
  pool_ref= avi_pool.wordpress_pool.id
  tenant_ref= data.avi_tenant.default_tenant.id
  cloud_ref= data.avi_cloud.default_cloud.id
  waf_policy_ref = data.avi_wafpolicy.waf_policy.id
  vsvip_ref = avi_vsvip.wordpress_vip.id
  scaleout_ecmp = true
  application_profile_ref= data.avi_applicationprofile.system_https_profile.id
  services {
    port= 443
    enable_ssl= true
    port_range_end= 443
  }
  cloud_type = "CLOUD_NSXT"
  se_group_ref= data.avi_serviceenginegroup.se_group.id
  analytics_profile_ref= data.avi_analyticsprofile.system_analytics_profile.id
  ssl_key_and_certificate_refs= [data.avi_sslkeyandcertificate.system_default_cert.id]
  ssl_profile_ref= data.avi_sslprofile.system_standard_sslprofile.id
  vrf_context_ref= data.avi_vrfcontext.global_vrf.id
  error_page_profile_ref= data.avi_errorpageprofile.error_page.id
  analytics_policy {
    all_headers= true
    udf_log_throttle= 0
    full_client_logs {
      duration= 0
      enabled= true
      throttle= 50
    }
    metrics_realtime_update {
      enabled= true
      duration= 0
    }
  }
}

output "wordpress_fqdn" {
  description = "FQDN of the newly created application"
  value = "https://${avi_vsvip.wordpress_vip.dns_info[0].fqdn}"
}
