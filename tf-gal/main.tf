terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" { type = string }

resource "azurerm_resource_group" "images" {
  name     = "rg-images"
  location = "eastus"
}

resource "azurerm_shared_image_gallery" "gal" {
  name                = "gal_msp" # letters, digits, _ and . only (no dashes)
  resource_group_name = azurerm_resource_group.images.name
  location            = azurerm_resource_group.images.location
}

resource "azurerm_shared_image" "win2022" {
  name                = "win2022-base"
  gallery_name        = azurerm_shared_image_gallery.gal.name
  resource_group_name = azurerm_resource_group.images.name
  location            = azurerm_resource_group.images.location
  os_type             = "Windows"
  hyper_v_generation  = "V2" # must match the Gen2 source image

  identifier {
    publisher = "MSP"
    offer     = "WindowsServer"
    sku       = "2022-base"
  }
}
