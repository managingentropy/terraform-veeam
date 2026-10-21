packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = ">= 0.14.0"
    }
  }
}

source "azure-arm" "win2022" {
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id
  location           = var.location
  vm_size            = "Standard_D2ads_v7"

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-g2"

  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "15m"
  winrm_username = "packer"

  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = "rg-images"
    gallery_name         = "gal_msp"
    image_name           = "win2022-base"
    image_version        = var.image_version
    storage_account_type = "Standard_LRS"
  }

  azure_tags = {
    built_by = "packer"
  }
}

build {
  sources = ["source.azure-arm.win2022"]

  provisioner "powershell" {
    script = "scripts/setup.ps1"
  }

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
  }

  provisioner "windows-restart" {}

  provisioner "powershell" {
    inline = [
      "while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm",
      "while ($true) { $s = (Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State).ImageState; if ($s -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $s; Start-Sleep -s 10 } else { break } }"
    ]
  }
}
