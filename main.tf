


# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }


}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
# Resource Group for the Hub network i.e palo
resource "azurerm_resource_group" "hub-network" {
  name     = "palorg"
  location = "eastus"
}
# Resource Group for the Spoke network
resource "azurerm_resource_group" "spoke" {
    name = "spoke-network"
    location = "eastus"
  
}
# Resource Group for the hub network
resource "azurerm_resource_group" "palo-vnet" {
    name = "palo-vnet"
    location = "eastus"
  
}


# Create a virtual network

resource "azurerm_virtual_network" "vnet" {
    
    name = "palo-vnet"

    address_space = ["10.0.1.0/24"]

    location = "eastus"

    resource_group_name = azurerm_resource_group.palo-vnet.name
  
}
# Private server vnet
resource "azurerm_virtual_network" "vnet2" {

    name = "spoke-vnet"
    address_space = ["10.0.2.0/24"]
    location = "eastus"
    resource_group_name = azurerm_resource_group.spoke.name
  
}

# Private server subnet
resource "azurerm_subnet" "Prod" {
    name = "Prod"
    resource_group_name = azurerm_resource_group.spoke.name
    virtual_network_name = azurerm_virtual_network.vnet2.name
    address_prefixes = ["10.0.2.0/28"]
  
}


# Create Palo Subnets
resource "azurerm_subnet" "MGMT" {
    name = "MGMT"
    resource_group_name = azurerm_resource_group.palo-vnet.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["10.0.1.0/28"]
  
}

resource "azurerm_subnet" "Untrust" {
    name = "Untrust"
    resource_group_name = azurerm_resource_group.palo-vnet.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["10.0.1.32/28"]
  
}

resource "azurerm_subnet" "Trust" {
    name = "Trust"
    resource_group_name = azurerm_resource_group.palo-vnet.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["10.0.1.48/28"]
}

#Required by Azure Bastion service
resource "azurerm_subnet" "bastion" {
  name = "AzureBastionSubnet"
  resource_group_name = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes = ["10.0.2.32/28"]
  
}

# VNET Peering

resource "azurerm_virtual_network_peering" "spoke-to-hub" {
  name = "spoke-to-hub"
  resource_group_name = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id
  
}

resource "azurerm_virtual_network_peering" "hub-to-spoke" {
  name = "hub-to-spoke"
  resource_group_name = azurerm_resource_group.palo-vnet.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  
}


#Create Bastion Service
#######################

#Create a public IP address for the bastion service
resource "azurerm_public_ip" "bastion" {
  name = "file-server-bastion"
  resource_group_name = azurerm_resource_group.spoke.name
  location = azurerm_virtual_network.vnet2.location
  allocation_method = "Static"
  sku = "Standard"
  
}

#Create the bastion service

resource "azurerm_bastion_host" "bastion" {
  name = "file-server-bastion"
  resource_group_name = azurerm_resource_group.spoke.name
  location = azurerm_virtual_network.vnet2.location

  ip_configuration {
    name = "configuration"
    subnet_id = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
  
}
/*
##################
# Create route table and bind to required subnets
##################

# This table sends all non-vnet traffic to the PAN firewall

resource "azurerm_route_table" "pan_fw1" {
  name = "panfwRT"
  location = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  disable_bgp_route_propagation = false


    route = {
      name = "to-inet-pan"
      address_prefix = "0.0.0.0/0"
      next_hop_type = "VirtualAppliance"
      # Nexthop is the PAN virtual appliance VNIC2 aka the trust interface
      next_hop_in_ip_address = "10.0.1.54"
    }
  
}


# Bind route table to subnets

resource "azurerm_subnet_route_table_association" "server_to_firewall" {
  subnet_id = azurerm_subnet.Prod.id
  route_table_id = azurerm_route_table.pan_fw1.id
  
}

*/

# Private server configuration
resource "azurerm_network_interface" "internal-server-1" {
  name = "internal-server-nic"
  location = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.Prod.id
    private_ip_address_allocation = "Dynamic"
  }

  
}


resource "azurerm_windows_virtual_machine" "prod-server" {
  name = "file-server"
  resource_group_name = azurerm_resource_group.spoke.name
  location = azurerm_resource_group.spoke.location
  size = "Standard_D2s_v3"
  admin_username = "Change_me!"
  admin_password = "Change_me!"
  network_interface_ids = [ 
    azurerm_network_interface.internal-server-1.id,
   ]
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2019-Datacenter"
    version = "latest"
  }
}




