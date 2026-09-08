output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.moodle.name
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = google_container_cluster.moodle.location
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.moodle.repository_id
}

output "static_ip_address" {
  description = "Global static IP address for the Moodle ingress"
  value       = google_compute_global_address.moodle.address
}
