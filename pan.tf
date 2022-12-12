#Deploy the Pan VM



# Storage Acct for FW disk
resource "azurerm_storage_account" "pan_fw_stg_ac" {
    name = "panstg"
    resource_group_name = azurerm_resource_group.hub-network.name
    location = azurerm_resource_group.hub-network.location
    account_replication_type = "LRS"
    account_tier = "Standard"

  
}

# Public IP for PAN MGMT Interface
resource "azurerm_public_ip" "pan_mgmt" {
    name = "pan_mgmt_pip"
    location = azurerm_resource_group.hub-network.location
    resource_group_name = azurerm_resource_group.hub-network.name
    allocation_method = "Static"
    sku = "Standard"
  
}

# Public IP for the PAN untrust interface
resource "azurerm_public_ip" "pan_untrust" {
    name = "pan_untrust_pip"
    location = azurerm_resource_group.hub-network.location
    resource_group_name = azurerm_resource_group.hub-network.name
    allocation_method = "Static"
    sku = "Standard"
  
}

# NSG for PAN MGMT Interface
resource "azurerm_network_security_group" "pan_mgmt" {
    name = "pan-NSG"
    location = azurerm_resource_group.hub-network.location
    resource_group_name = azurerm_resource_group.hub-network.name

# Permit inbound access to the MGMT VNIC from permitted IPs
    security_rule =[{
      access = "Allow"
      description = "Allowing intra-net traffic."
      destination_address_prefix = "*"
      destination_address_prefixes = [  ]
      destination_application_security_group_ids = [  ]
      destination_port_range = "*"
      destination_port_ranges = [  ]
      direction = "Inbound"
      name = "Allow-Intra"
      priority = 100
      protocol = "*"
      source_address_prefix = ""
      source_address_prefixes = [ ]
      source_application_security_group_ids = [  ]
      source_port_range = "*"
      source_port_ranges = [ ]
    } ]

   
}

# Associate the NSG with PAN's MGMT subnet

resource "azurerm_subnet_network_security_group_association" "pan_mgmt" {
    subnet_id =azurerm_subnet.MGMT.id
    network_security_group_id = azurerm_network_security_group.pan_mgmt.id
  
}

#PAN mgmt VNIC

resource "azurerm_network_interface" "FW_eth0" {
    name = "eth0_MGMT_interface"
    location = azurerm_resource_group.hub-network.location
    resource_group_name = azurerm_resource_group.hub-network.name

    enable_accelerated_networking = true

    ip_configuration {
      name = "ipconfig0"
      subnet_id = azurerm_subnet.MGMT.id
      private_ip_address_allocation = "Dynamic"

      #MGMT VNIC has a static public IP address
      public_ip_address_id = azurerm_public_ip.pan_mgmt.id
    }

    tags = {
        panInterface = "mgmt0"
    }
}

# PAN untrust VNIC

resource "azurerm_network_interface" "FW_eth1" {
    name = "eth1_untrust_interface"
    location = azurerm_resource_group.hub-network.location
    resource_group_name = azurerm_resource_group.hub-network.name

#Accelerated networking supported by PAN OS image

    enable_accelerated_networking = true
    enable_ip_forwarding = true

    ip_configuration{
        name = "ipconfig1"
        subnet_id = azurerm_subnet.Untrust.id
        private_ip_address_allocation = "Static"
        private_ip_address = "10.0.1.38"

        public_ip_address_id = azurerm_public_ip.pan_untrust.id
    }
      
}

# PAN trust VNIC

resource "azurerm_network_interface" "FW_eth2" {
    name = "eth2_trust_interface"
    location = azurerm_resource_group.hub-network.location
    resource_group_name = azurerm_resource_group.hub-network.name

    enable_accelerated_networking = true
    enable_ip_forwarding = true

    ip_configuration {
      name = "ipconfig2"
      subnet_id = azurerm_subnet.Trust.id
      private_ip_address_allocation = "Static"
      private_ip_address = "10.0.1.54"
    }
  
}

# Create the firewall VM

resource "azurerm_virtual_machine" "PAN_FW_FW" {
    name = "skillpalo1"
    location = azurerm_resource_group.hub-network.location
    resource_group_name = azurerm_resource_group.hub-network.name
    vm_size = "Standard_D3_v2"

    plan {
      # Use PAYG bundle 2

      name = "bundle2"
      publisher = "paloaltonetworks"
      product = "vmseries-flex"
    }

    storage_image_reference {
      publisher = "paloaltonetworks"
      offer = "vmseries-flex"
      sku = "bundle2"
      version = "Latest"
    }

    storage_os_disk {
      name = "pan_fw_disk"
      #vhd_uri = "azurerm_storage_account.Pan_fw_stg_ac.primary_blob_endpoint -osDisk.vhd"
      caching = "ReadWrite"
      create_option = "FromImage"
    }

    os_profile {
      computer_name = "Change_me!"
      admin_username = "Change_me!"
      admin_password = "Change_me!"
    }

    primary_network_interface_id = azurerm_network_interface.FW_eth0.id
    network_interface_ids = [azurerm_network_interface.FW_eth0.id,
                            azurerm_network_interface.FW_eth1.id,
                            azurerm_network_interface.FW_eth2.id ]

    os_profile_linux_config {
      disable_password_authentication = false
    }


}

resource "azurerm_marketplace_agreement" "paloalto" {
    publisher = "paloaltonetworks"
    offer = "vmseries1"
    plan = "bundle2"
  
}
