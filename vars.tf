# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "project_name" {
  description = "The name of the project for tagging"
}

variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
}

variable "environ" {
  description = "The environment to use, for example Dev, Test, Prod"
}

variable "admin_username" {
  description = "The admin username for the VM being created."
}

variable "admin_password" {
  description = "The password for the VM being created."
}

variable "vm_counter" {
  description = "The nmber of VMs to create"
  type    = number
  default = 2
}