terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      #version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = ""
}

# ---------------------------
# Variables
# ---------------------------
variable "resource_group_name" {
  default = ""
}

variable "location" {
  default = "eastus"
}

variable "virtual_network_name" {
  default = ""
}

variable "subnet_name" {
  default = "postgresql"
}

variable "vm_name" {
  default = "myVM"
}

variable "admin_username" {
  description = "Admin username for VM"
  default     = "azureuser"
}

variable "admin_password" {
  description = "Password for VM admin user"
  default     = ""
  sensitive   = true
}

# ---------------------------
# Data Sources
# ---------------------------

# Existing RG
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Existing VNET
data "azurerm_virtual_network" "main" {
  name                = var.virtual_network_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# Existing subnet for VM
data "azurerm_subnet" "vm_subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_resource_group.main.name
}

# Existing subnet for Bastion
data "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = data.azurerm_resource_group.main.name
}

# ---------------------------
# Network Interface for VM
# ---------------------------
resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.1.13"
  }
}

# ---------------------------
# Windows VM
# ---------------------------
resource "azurerm_windows_virtual_machine" "main" {
  name                  = var.vm_name
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  size                  = "Standard_DS1_v2"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.main.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-smalldisk-g2"
    version   = "latest"
  }
}

# ---------------------------
# Azure Bastion Setup
# ---------------------------

# Public IP for Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "bastion-pip"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Bastion Host
resource "azurerm_bastion_host" "main" {
  name                = "myBastionHost"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = data.azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  sku = "Standard" # Change to "Basic" if needed
}
