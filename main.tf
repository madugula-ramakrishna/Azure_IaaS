# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "azurerm" {
  features {}
  subscription_id = "630a1e98-7922-4c13-9488-39768dd9328d"
}

data "azurerm_image" "packer_image" {
  name                = "udacity-packager-image-v1"
  resource_group_name = "Azuredevops"
}

data "azurerm_resource_group" "main" {
  name     = "Azuredevops"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/22"]
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  # Deny Inbound Traffic from the Internet
  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
  }
  
  # Allow Inbound HTTP Traffic from the Internet on Port 80
  #security_rule {
  #  name                       = "AllowHTTPFromInternet"
  #  priority                   = 110
  #  direction                  = "Inbound"
  #  access                     = "Allow"
  #  protocol                   = "Tcp"
  #  source_address_prefix      = "Internet"
  #  destination_address_prefix = "*"
  #  source_port_range          = "*"
  #  destination_port_range     = "80"
  #}
  
  # Allow traffic within the Same Virtual Network - Inbound
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
    source_port_range          = "*"
    destination_port_range     = "*"
  }
  
  # Allow traffic within the Same Virtual Network - Outbound
  security_rule {
    name                       = "AllowVnetOutbound"
    priority                   = 300
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
    source_port_range          = "*"
    destination_port_range     = "*"
  }
  
  # Allow HTTP Traffic from the Load Balancer to the VMs
  security_rule {
    name                       = "AllowLBHTTPInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
  }
  
}

resource "azurerm_network_interface" "main" {
  count               = var.vm_counter
  name                = "${var.prefix}-nic-${count.index}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  count                     = var.vm_counter
  network_interface_id      = azurerm_network_interface.main[count.index].id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-pub-ip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicFrontEnd"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  name                = "BackendPool"
  loadbalancer_id     = azurerm_lb.main.id
}

resource "azurerm_lb_probe" "http_probe" {
  name                = "${var.prefix}-http-probe"
  loadbalancer_id     = azurerm_lb.main.id
  protocol            = "Tcp"
  port                = 80
}

resource "azurerm_lb_rule" "http_rule" {
  name                           = "${var.prefix}-http-rule"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.main.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = var.vm_counter
  network_interface_id    = azurerm_network_interface.main[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_subnet_network_security_group_association" "internal" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_availability_set" "main" {
  name                = "${var.prefix}-avset"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed = true
}

resource "azurerm_linux_virtual_machine" "main" {
  count = var.vm_counter
  name                            = "${var.prefix}-vm-${count.index}"
  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = var.location
  size                            = "Standard_D2s_v3"
  admin_username = var.admin_username
  admin_password = var.admin_password
  disable_password_authentication = false
  
  source_image_id = data.azurerm_image.packer_image.id
  availability_set_id = azurerm_availability_set.main.id
  
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]
  
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  
  tags = {
    Environment = var.environ
    Project     = var.project_name
  }

}