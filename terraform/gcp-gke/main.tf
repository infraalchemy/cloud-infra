resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false # destroying this Terraform stack will not disable the APIs for the whole GCP project
}

resource "google_project_service" "artifact_registry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false # destroying this Terraform stack will not disable the APIs for the whole GCP project
}

resource "google_container_cluster" "moodle" {
  name                = "moodle-gke-cluster"
  location            = var.zone
  deletion_protection = false # intentionally build and tear down, explicitly set false

  initial_node_count = 2

  node_config {
    machine_type = "e2-medium"
  }

  addons_config {
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }
}

resource "google_artifact_registry_repository" "moodle" {
  location      = var.region
  repository_id = "moodle-repo"
  description   = "Docker repository for Moodle application images"
  format        = "DOCKER"
}

resource "google_compute_global_address" "moodle" {
  name = "moodle-static-ip"
}
