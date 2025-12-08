#  server.pkr.hcl
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 1.0"
    }
  }
}

variable "client_id" {
  type = string
  default = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type = string
  default = env("ARM_CLIENT_SECRET")
}

variable "subscription_id" {
  type = string
  default = env("ARM_SUBSCRIPTION_ID")
}

variable "tenant_id" {
  type = string
  default = env("ARM_TENANT_ID")
}

# Azure ARM Builder
source "azure-arm" "ubuntu" {
  client_id                  = var.client_id
  client_secret              = var.client_secret
  subscription_id             = var.subscription_id
  tenant_id                   = var.tenant_id
  os_type                     = "Linux"
  image_publisher             = "Canonical"
  image_offer                 = "UbuntuServer"
  image_sku                   = "18.04-LTS"
  managed_image_resource_group_name = "Azuredevops"
  managed_image_name          = "udacity-packager-image-v1"
  location                    = "northeurope"
  vm_size                     = "Standard_B1s"
}

# Build block
build {
  sources = ["source.azure-arm.ubuntu"]

  provisioner "shell" {
    inline = [
	  "sudo mkdir -p /var/www/html",
	  "sudo echo 'Hello, World!' > /var/www/html/index.html",
      "echo '[Unit]' > http.service",
      "echo 'Description=HTTP Hello World' >> http.service",
      "echo 'After=network.target' >> http.service",
      "echo 'StartLimitIntervalSec=0' >> http.service",
      "echo '[Service]' >> http.service",
      "echo 'Type=simple' >> http.service",
      "echo 'Restart=always' >> http.service",
      "echo 'RestartSec=1' >> http.service",
      "echo 'ExecStart=/bin/busybox httpd -f -p 80 -h /var/www/html' >> http.service",
      "echo '[Install]' >> http.service",
      "echo 'WantedBy=multi-user.target' >> http.service",
      "sudo mv http.service /etc/systemd/system",
      "sudo chown root:root /etc/systemd/system/http.service",
      "sudo chmod 755 /etc/systemd/system/http.service",
	  "sudo systemctl daemon-reload",
      "sudo systemctl enable http",
	  "sudo systemctl start http"
    ]
    inline_shebang = "/bin/sh -x"
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
  }
}