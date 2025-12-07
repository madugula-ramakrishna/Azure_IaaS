# server.pkr.hcl
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 1.0"
    }
  }
}

variable "client_id" {
  type    = string
  default = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type    = string
  default = env("ARM_CLIENT_SECRET")
}

variable "subscription_id" {
  type    = string
  default = env("ARM_SUBSCRIPTION_ID")
}

variable "tenant_id" {
  type    = string
  default = env("ARM_TENANT_ID")
}

# Azure ARM Builder
source "azure-arm" "ubuntu" {
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  subscription_id                    = var.subscription_id
  tenant_id                          = var.tenant_id
  os_type                            = "Linux"
  image_publisher                    = "Canonical"
  image_offer                        = "UbuntuServer"
  image_sku                          = "18.04-LTS"
  location                           = "westeurope"
  vm_size                             = "Standard_B1s"

  # Temporary RG where the build VM will be created
  temporary_resource_group_name      = "pkr-build-rg"

  # Existing RG where the final managed image will be stored
  managed_image_resource_group_name  = "AzureDevOps"
  managed_image_name                 = "udacity-packager-image-v1"
}

# Build block
build {
  sources = ["source.azure-arm.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /var/www/html",
      "echo 'Hello, World!' | sudo tee /var/www/html/index.html",
      "echo '[Unit]' > http.service",
      "echo 'Description=HTTP Hello World' >> http.service",
      "echo 'After=network.target' >> http.service",
      "echo 'StartLimitInter