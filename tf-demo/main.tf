terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ---------- Variables ----------
variable "subscription_id" { type = string }
variable "my_ip"           { type = string } # your public IP, for RDP access
variable "location"        { default = "eastus" }
variable "vm_name"         { default = "vm-test01" } # max 15 chars
# Avoid v6/v7 (NVMe-only vs SCSI gallery image). Swap if eastus is out of capacity.
variable "vm_size"         { default = "Standard_D2s_v4" }

# ---------- Resource group & network ----------
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.vm_name}"
  location = var.location
  tags     = { managed_by = "terraform" }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.vm_name}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vms" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# ---------- Public IP + firewall (RDP from your IP only) ----------
resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP-MyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-WinRM-MyIP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vms.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ---------- Gallery image (Packer publishes versions; always take latest) ----------
data "azurerm_shared_image_version" "win2022" {
  name                = "latest"
  gallery_name        = "gal_msp"
  image_name          = "win2022-base"
  resource_group_name = "rg-images"
}

# ---------- VM ----------
resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!@#-_" # Azure-safe; avoid & $ etc that break shells/az
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = var.vm_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  # v6/v7 often require NVMe; Packer gallery image is SCSI-only unless baked on NVMe
  size = var.vm_size
  admin_username        = "mspadmin"
  admin_password        = random_password.admin.result
  network_interface_ids = [azurerm_network_interface.nic.id]
  source_image_id       = data.azurerm_shared_image_version.win2022.id


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
}

# ---------- Auto-shutdown at 7 PM so a forgotten test VM doesn't burn money ----------
resource "azurerm_dev_test_global_vm_shutdown_schedule" "shutdown" {
  virtual_machine_id    = azurerm_windows_virtual_machine.vm.id
  location              = azurerm_resource_group.rg.location
  enabled               = true
  daily_recurrence_time = "1900"
  timezone              = "Eastern Standard Time"

  notification_settings {
    enabled = false
  }
}

# ---------- Outputs ----------
output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "admin_username" {
  value = azurerm_windows_virtual_machine.vm.admin_username
}

output "admin_password" {
  value     = random_password.admin.result
  sensitive = true
}

output "image_id" {
  value = data.azurerm_shared_image_version.win2022.id
}