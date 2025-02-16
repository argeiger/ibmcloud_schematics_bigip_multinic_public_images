# lookup SSH public keys by name
data "ibm_is_ssh_key" "ssh_pub_key" {
  name = var.ssh_key_name
}

# lookup compute profile by name
data "ibm_is_instance_profile" "instance_profile" {
  name = var.instance_profile
}

# create a random password if we need it
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

locals {
  # use the public image if the name is found
  public_image_map = {
    f5-bigip-15-1-2-1-0-0-10-all-1slot-1 = {
      "us-south" = "r006-96eff507-273e-48af-8790-74c74cf4cebd"
      "us-east"  = "r014-fb2140e2-97dd-4cfa-a480-49c36023169a"
      "eu-gb"    = "r018-797c97bd-a1b9-4e83-ba22-e557a8938cab"
      "eu-de"    = "r010-759f402f-da71-4719-bf9c-dec955610032"
      "jp-tok"   = "r022-16b8c452-3fa2-40b0-8ae9-8f1a3b1b9459"
      "au-syd"   = "r026-99c64581-ce8c-48a3-ae3a-7aba1e651344"
      "jp-osa"   = "r034-d8385b38-870f-453a-b33e-8b40ceec0450"
      "ca-tor"   = "r038-ef27dfd1-1564-48ff-af2a-d9092dd4ffb9"
    }
    f5-bigip-15-1-2-1-0-0-10-ltm-1slot-1 = {
      "us-south" = "r006-17a5e435-cfd6-44b5-9c52-1eabe26445af"
      "us-east"  = "r014-29af1cf4-9436-4934-a2c4-c7330d1f88cf"
      "eu-gb"    = "r018-d1add662-3591-40da-b80c-f62a191cb60a"
      "eu-de"    = "r010-5dc287cb-b9d5-4889-9a43-ca3a38c5b457"
      "jp-tok"   = "r022-76a7fcf7-df8d-452a-9e96-4c17ded591ae"
      "au-syd"   = "r026-6ae75968-955f-4b9b-9f2a-d5dcbccadd63"
      "jp-osa"   = "r034-7721a3b3-a5ec-4c7e-9420-c945ba56cbfe"
      "ca-tor"   = "r038-9da83b4a-eaeb-47d1-90c4-81b02c856bed"
    }
    f5-bigip-16-0-1-1-0-0-6-ltm-1slot-1 = {
      "us-south" = "r006-bc5a723a-752c-4fdb-b6c9-a8fd3c587bd3"
      "us-east"  = "r014-74c06b64-0b4a-4ad1-840b-16f67f566ad5"
      "eu-gb"    = "r018-446eb09c-a047-4644-8731-bc032bfb6f37"
      "eu-de"    = "r010-718b1266-a407-4d5b-8b08-93fd05fc1db6"
      "jp-tok"   = "r022-ff687ace-0325-4dd7-81d7-eaf0e5a378a5"
      "au-syd"   = "r026-4102137d-6abf-40e9-9d77-69c6f4cc5cc2"
      "jp-osa"   = "r034-ab405ea1-68a4-437c-b180-f2834ab14b16"
      "ca-tor"   = "r038-2d523ada-b257-4add-97fd-d084bc92ea42"
    }
    f5-bigip-16-0-1-1-0-0-6-all-1slot-1 = {
      "us-south" = "r006-fe9e266b-5f74-4809-a348-f779e70353cb"
      "us-east"  = "r014-84ed1e28-5bc0-4d3f-8de6-68d8a28327bb"
      "eu-gb"    = "r018-387d2b15-6958-424a-ab74-d6561dccef9f"
      "eu-de"    = "r010-50c6a70c-3222-4cd9-8cb9-5dc3bdef019c"
      "jp-tok"   = "r022-16f09456-9409-487e-b7ec-34f72a7db826"
      "au-syd"   = "r026-4c50432b-28c5-41ef-8031-b3104c46de77"
      "jp-osa"   = "r034-a3450582-5dd2-475c-a423-c18e1141df36"
      "ca-tor"   = "r038-c6ab2957-3937-4c63-a842-9c8aac9d502b"
    }   
  }
}

locals {
  do_byol_license = <<EOD

    schemaVersion: 1.0.0
    class: Device
    async: true
    label: Cloudinit Onboarding
    Common:
      class: Tenant
      byoLicense:
        class: License
        licenseType: regKey
        regKey: ${var.byol_license_basekey}
EOD
  do_regekypool = <<EOD

    schemaVersion: 1.0.0
    class: Device
    async: true
    label: Cloudinit Onboarding
    Common:
      class: Tenant
      poolLicense:
        class: License
        licenseType: licensePool
        bigIqHost: ${var.license_host}
        bigIqUsername: ${var.license_username}
        bigIqPassword: ${var.license_password}
        licensePool: ${var.license_pool}
        reachable: false
        hypervisor: kvm
EOD
  do_utilitypool = <<EOD

    schemaVersion: 1.0.0
    class: Device
    async: true
    label: Cloudinit Onboarding
    Common:
      class: Tenant
      utilityLicense:
        class: License
        licenseType: licensePool
        bigIqHost: ${var.license_host}
        bigIqUsername: ${var.license_username}
        bigIqPassword: ${var.license_password}
        licensePool: ${var.license_pool}
        skuKeyword1: ${var.license_sku_keyword_1}
        skuKeyword2: ${var.license_sku_keyword_2}
        unitOfMeasure: ${var.license_unit_of_measure}
        reachable: false
        hypervisor: kvm
EOD
}

locals {
  # custom image takes priority over public image
  image_id = lookup(local.public_image_map[var.tmos_image_name], var.region)
  # public image takes priority over custom image
  # image_id = lookup(lookup(local.public_image_map, var.tmos_image_name, {}), var.region, data.ibm_is_image.tmos_custom_image.id)
  template_file = file("${path.module}/user_data.yaml")
  # user admin_password if supplied, else set a random password
  admin_password = var.tmos_admin_password == "" ? random_password.password.result : var.tmos_admin_password
  # set user_data YAML values or else set them to null for templating
  do_declaration_url   = var.do_declaration_url == "" ? "null" : var.do_declaration_url
  as3_declaration_url  = var.as3_declaration_url == "" ? "null" : var.as3_declaration_url
  ts_declaration_url   = var.ts_declaration_url == "" ? "null" : var.ts_declaration_url
  phone_home_url       = var.phone_home_url == "" ? "null" : var.phone_home_url
  tgactive_url         = var.tgactive_url == "" ? "null" : var.tgactive_url
  tgstandby_url        = var.tgstandby_url == "" ? "null" : var.tgstandby_url
  tgrefresh_url        = var.tgrefresh_url == "" ? "null" : var.tgrefresh_url
  do_dec1              = var.license_type == "byol" ? chomp(local.do_byol_license): "null"
  do_dec2              = var.license_type == "regkeypool" ? chomp(local.do_regekypool): local.do_dec1
  do_local_declaration = var.license_type == "utilitypool" ? chomp(local.do_utilitypool): local.do_dec2 
  # default_route_interface
  default_route_interface = var.default_route_interface == "" ? "1.${length(local.secondary_subnets)}" : var.default_route_interface
}

# discovery the 1st address on the default route subnet because IBM does not
# supply the DHCPv4 routers option correctly on non-primary interfaces. This
# is a bug in IBM they need to fix.
data "ibm_is_subnet" "default_route_subnet" {
  identifier = element(local.secondary_subnets, length(local.secondary_subnets) - 1)
}
# IBM does not tell you what the default gateway address for each subnet should
# be, but by undocumented convention we will use the 1st host address in the subnet
locals {
  default_gateway_ipv4_address = cidrhost(data.ibm_is_subnet.default_route_subnet.ipv4_cidr_block, 1)
}

data "template_file" "user_data" {
  template = local.template_file
  vars = {
    tmos_admin_password     = local.admin_password
    configsync_interface    = "1.1"
    hostname                = var.hostname
    domain                  = var.domain
    default_route_interface = local.default_route_interface
    default_route_gateway   = local.default_gateway_ipv4_address
    do_local_declaration    = local.do_local_declaration
    do_declaration_url      = local.do_declaration_url
    as3_declaration_url     = local.as3_declaration_url
    ts_declaration_url      = local.ts_declaration_url
    phone_home_url          = local.phone_home_url
    tgactive_url            = local.tgactive_url
    tgstandby_url           = local.tgstandby_url
    tgrefresh_url           = local.tgrefresh_url
    template_source         = var.template_source
    template_version        = var.template_version
    zone                    = data.ibm_is_subnet.f5_management_subnet.zone
    vpc                     = data.ibm_is_subnet.f5_management_subnet.vpc
    app_id                  = var.app_id
  }
}

# create compute instance
resource "ibm_is_instance" "f5_ve_instance" {
  name           = var.instance_name
  resource_group = data.ibm_resource_group.group.id
  image          = local.image_id
  profile        = data.ibm_is_instance_profile.instance_profile.id
  primary_network_interface {
    name            = "management"
    subnet          = data.ibm_is_subnet.f5_management_subnet.id
    security_groups = [ibm_is_security_group.f5_open_sg.id]
  }
  dynamic "network_interfaces" {
    for_each = local.secondary_subnets
    content {
      name              = format("data-1-%d", (network_interfaces.key + 1))
      subnet            = network_interfaces.value
      security_groups   = [ibm_is_security_group.f5_open_sg.id]
      allow_ip_spoofing = true
    }
  }
  boot_volume {
    encryption = var.encryption_key_crn == "" ? null : var.encryption_key_crn 
  }
  vpc        = data.ibm_is_subnet.f5_management_subnet.vpc
  zone       = data.ibm_is_subnet.f5_management_subnet.zone
  keys       = [data.ibm_is_ssh_key.ssh_pub_key.id]
  user_data  = data.template_file.user_data.rendered
  depends_on = [ibm_is_security_group_rule.f5_allow_outbound]
  timeouts {
    create = "60m"
    delete = "120m"
  }
}

locals {
  vs_interface_index   = length(ibm_is_instance.f5_ve_instance.network_interfaces) - 1
  snat_interface_index = length(ibm_is_instance.f5_ve_instance.network_interfaces) < 3 ? 0 : 1
}

resource "ibm_is_floating_ip" "f5_management_floating_ip" {
  name           = "fmgmt-${random_uuid.namer.result}"
  resource_group = data.ibm_resource_group.group.id
  count          = var.bigip_management_floating_ip ? 1 : 0
  target         = ibm_is_instance.f5_ve_instance.primary_network_interface.0.id
}

resource "ibm_is_floating_ip" "f5_external_floating_ip" {
  name           = "fext-${random_uuid.namer.result}"
  resource_group = data.ibm_resource_group.group.id
  count          = local.external_floating_ip ? 1 : 0
  target         = element(ibm_is_instance.f5_ve_instance.network_interfaces.*.id, local.vs_interface_index)
}

output "resource_name" {
  value = ibm_is_instance.f5_ve_instance.name
}

output "resource_status" {
  value = ibm_is_instance.f5_ve_instance.status
}

output "VPC" {
  value = ibm_is_instance.f5_ve_instance.vpc
}

output "image_id" {
  value = local.image_id
}

output "instance_id" {
  value = ibm_is_instance.f5_ve_instance.id
}

output "profile_id" {
  value = data.ibm_is_instance_profile.instance_profile.id
}

output "f5_management_ip" {
  value = ibm_is_instance.f5_ve_instance.primary_network_interface.0.primary_ipv4_address
}

output "f5_cluster_ip" {
  value = var.cluster_subnet_id == "" ? "" : ibm_is_instance.f5_ve_instance.network_interfaces.0.primary_ipv4_address
}

output "f5_internal_ip" {
  value = var.internal_subnet_id == "" ? "" : element(ibm_is_instance.f5_ve_instance.network_interfaces, local.snat_interface_index).primary_ipv4_address
}

output "f5_external_ip" {
  value = var.external_subnet_id == "" ? "" : element(ibm_is_instance.f5_ve_instance.network_interfaces, local.vs_interface_index).primary_ipv4_address
}

output "default_gateway" {
  value = local.default_gateway_ipv4_address
}

output "virtual_service_next_hop_address" {
  value = element(ibm_is_instance.f5_ve_instance.network_interfaces, local.vs_interface_index).primary_ipv4_address
}

output "snat_next_hop_address" {
  value = element(ibm_is_instance.f5_ve_instance.network_interfaces, local.snat_interface_index).primary_ipv4_address
}

output "f5_management_floating_ip" {
  value = var.bigip_management_floating_ip ? ibm_is_floating_ip.f5_management_floating_ip[0].address : ""
}

output "f5_external_floating_ip" {
  value = local.external_floating_ip ? ibm_is_floating_ip.f5_external_floating_ip[0].address : ""
}
