variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "northamerica-northeast2"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "northamerica-northeast2-a"
}
