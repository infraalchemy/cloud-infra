
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "docker-vm"
}

variable "machine_type" {
  description = "Machine type"
  type        = string
  default     = "e2-medium"
}

