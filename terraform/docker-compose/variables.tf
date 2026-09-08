
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "northamerica-northeast2"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "northamerica-northeast2-a"
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "cloud-vm"
}

variable "disk_size_gb" {
  default = 30
}
variable "machine_type" {
  description = "Machine type"
  type        = string
  default     = "e2-medium"
}

